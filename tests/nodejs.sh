#!/usr/bin/env bash
# Usage: tests/nodejs.sh
# End-to-end test of the Node.js packages (nodejs, nodejs-26, nodejs-24,
# nodejs-22) through a local signed repository, like tests/repo.sh. Builds the
# newest LTS of every line plus the previous nodejs-24 release, publishes them
# in two rounds, and checks on every client image that:
#   - "nodejs" installs nodejs-26 as the default, "nodejs-lts" works too
#   - the aliases nodejs24/nodejs22 install nodejs-24/nodejs-22
#   - several lines coexist; update-alternatives switches node and npm's node;
#     node-24 etc. always work; removing the default falls back to the next
#   - removing everything leaves no /usr/bin/node, no alternatives, no files
#   - upgrading with only nodejs-24 installed upgrades it and never pulls in 26
#   - the distribution's nodejs (+npm) and RHEL's nodejs24 are replaced cleanly
#   - NodeSource's nodejs (setup_lts.x, Debian only) is replaced cleanly once
#     its apt pin is gone
# Clients are amd64; both architectures are built because publish.sh only
# publishes complete releases.

source "$(dirname "$0")/../scripts/lib.sh"

PUBLISH_IMAGE=${PUBLISH_IMAGE:-debian:13}
DEB_IMAGES=${DEB_IMAGES:-"debian:13 ubuntu:26.04"}
RPM_IMAGES=${RPM_IMAGES:-"rockylinux/rockylinux:10"}
NODESOURCE_IMAGES=${NODESOURCE_IMAGES:-"debian:13"}

tmp=$(mktemp -d)
# Every container of this run carries the label; start() runs in a subshell,
# so an array of ids would never reach cleanup.
label=xtom-nodejs-test=$$
cleanup() {
  docker ps -aq --filter "label=$label" | xargs -r docker rm -f >/dev/null
  docker run --rm -v "$tmp:/t" "$PUBLISH_IMAGE" sh -c 'rm -rf /t/*'
  rm -rf "$tmp"
}
trap cleanup EXIT

# --- build -----------------------------------------------------------------

# latest_lts MAJOR [N]: the Nth newest LTS release of MAJOR (default 1).
latest_lts() {
  curl -fsSL --retry 3 https://nodejs.org/dist/index.json |
    jq -r --arg m "$1." --argjson n "${2:-1}" '[.[] | select(.lts) | .version | ltrimstr("v") | select(startswith($m))][$n - 1] // empty'
}
V26=$(latest_lts 26) V24=$(latest_lts 24) V24_OLD=$(latest_lts 24 2) V22=$(latest_lts 22)
[[ -n $V26 && -n $V24 && -n $V24_OLD && -n $V22 ]] || die "cannot find the Node.js LTS releases"
log "Node.js $V26, $V24 (upgrade from $V24_OLD), $V22"

# Round 1 has the old nodejs-24, round 2 the new one.
build() { DIST=$tmp/dist-$1 WORK=$tmp/work "$ROOT/scripts/build.sh" "$2" "$3"; }
build 1 nodejs "$V26"
build 1 nodejs-26 "$V26"
build 1 nodejs-24 "$V24_OLD"
build 1 nodejs-22 "$V22"
build 2 nodejs-24 "$V24"
mkdir -p "$tmp/www"

# --- containers ------------------------------------------------------------

# start IMAGE: a long-running container with the repo mounted at /repo; prints its id.
start() {
  docker run -d --label "$label" -v "$ROOT:/src:ro" -v "$tmp:/t" -v "$tmp/www:/repo" \
    -e V26="$V26" -e V24="$V24" -e V24_OLD="$V24_OLD" -e V22="$V22" "$1" sleep infinity
}

# Helpers for the client scripts, the same for apt and dnf.
CLIENT_LIB='
export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null; then fmt=deb; else fmt=rpm; fi
inst() { if [ $fmt = deb ]; then apt-get install -y -qq "$@" >/dev/null; else dnf -y -q install "$@"; fi; }
purge() { if [ $fmt = deb ]; then apt-get purge -y -qq "$@" >/dev/null; else dnf -y -q remove "$@"; fi; }
installed() {
  if [ $fmt = deb ]; then dpkg-query -W -f="\${db:Status-Abbrev}" "$1" 2>/dev/null | grep -q "^ii"
  else rpm -q "$1" >/dev/null 2>&1; fi
}
# version PKG: installed version without epoch and release.
version() {
  if [ $fmt = deb ]; then dpkg-query -W -f="\${Version}" "$1" | sed "s/^[0-9]*://; s/-[^-]*$//"
  else rpm -q --qf "%{VERSION}" "$1"; fi
}
alt_set() { if [ $fmt = deb ]; then update-alternatives --set node "$1"; else alternatives --set node "$1"; fi; }
alt_display() { if [ $fmt = deb ]; then update-alternatives --display node; else alternatives --display node; fi; }
# no CMD...: fail if CMD succeeds ("! CMD" does not trip set -e).
no() { if "$@"; then echo "unexpected success: $*" >&2; return 1; fi; }
# default MAJOR VERSION: node, nodejs, npm and npx (and the tools they start)
# run Node.js VERSION from nodejs-MAJOR.
default() {
  test "$(node -v)" = "v$2"
  test "$(nodejs -v)" = "v$2"
  test "$(readlink -f /usr/bin/node)" = /usr/lib/nodejs-$1/bin/node
  test "$(npm -v)" = "$(npm-$1 -v)"
  test "$(cd /tmp && npm exec -c "node -v")" = "v$2"
  test "$(cd /tmp && npx -c "node -v")" = "v$2"
  test "$(readlink -f /usr/share/man/man1/node.1.gz)" = /usr/lib/nodejs-$1/share/man/man1/node.1.gz
  # Without corepack (Node.js 25+) /usr/bin/corepack is not ours; Debian'"'"'s
  # node-corepack may still provide it.
  if [ -e /usr/bin/corepack-$1 ]; then test "$(corepack -v)" = "$(corepack-$1 -v)"
  else test "$(readlink /usr/bin/corepack || true)" != /etc/alternatives/corepack; fi
}
# versioned MAJOR VERSION: node-MAJOR & co. run that line, whatever the default.
versioned() {
  test "$(node-$1 -v)" = "v$2"
  test "$(cd /tmp && npm-$1 exec -c "node -v")" = "v$2"
  test "$(cd /tmp && npx-$1 -c "node -v")" = "v$2"
}
# gone: no trace of any nodejs-NN package.
gone() {
  for f in node nodejs npm npx corepack; do no test -e /usr/bin/$f; no test -L /usr/bin/$f; done
  test ! -e /usr/share/man/man1/node.1.gz
  test ! -L /usr/share/man/man1/node.1.gz
  no alt_display >/dev/null 2>&1
  test ! -e /var/lib/dpkg/alternatives/node
  test ! -e /var/lib/alternatives/node
  test ! -e /etc/alternatives/node
  test ! -L /etc/alternatives/node
  dangling=$(find /etc/alternatives /usr/bin /usr/share/man -xtype l \( -lname "*node*" -o -lname "*np[mx]*" -o -lname "*corepack*" \) 2>/dev/null || true)
  [ -z "$dangling" ] || { echo "dangling links: $dangling"; exit 1; }
  no ls -d /usr/lib/nodejs-* 2>/dev/null
}
add_repo() {
  if [ $fmt = deb ]; then
    command -v curl >/dev/null || { apt-get update -qq && apt-get install -y -qq curl >/dev/null; }
  fi
  REPO_URL=file:///repo bash /src/scripts/repo.sh >/dev/null
}
'
# client ID SCRIPT: run SCRIPT in a client container with CLIENT_LIB loaded.
client() { docker exec "$1" bash -euxo pipefail -c "$CLIENT_LIB$2"; }

# --- publish ---------------------------------------------------------------

publisher=$(start "$PUBLISH_IMAGE")
docker exec "$publisher" bash -euc '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq apt-utils createrepo-c rpm gnupg rsync jq xz-utils >/dev/null
  export GNUPGHOME=/t/gnupg
  mkdir -m700 "$GNUPGHOME"
  gpg --batch --passphrase "" --quick-gen-key "Test <test@example.com>" ed25519 sign never 2>/dev/null
  gpg --armor --export > /t/www/xtom.key
  # publish.sh reads the state of the previous publish.
  echo "{}" > /t/versions.json
'
publish() {
  log "publish round $1"
  docker exec "$publisher" bash -euc "
    export GNUPGHOME=/t/gnupg REPO_DEST=/t/www PUBLIC_URL=file:///repo WORK=/t/work VERSIONS_FILE=/t/versions.json
    export GPG_KEY_ID=\$(gpg --list-keys --with-colons | awk -F: '/^fpr/ {print \$10; exit}')
    DIST=/t/dist-$1 /src/scripts/publish.sh
  "
}
publish 1

# --- round 1: upgrades that need the old nodejs-24 or the distro packages ----

upgrade24=() distro=()
for image in $DEB_IMAGES $RPM_IMAGES; do
  log "$image: install nodejs24 ($V24_OLD) alone"
  id=$(start "$image")
  upgrade24+=("$id")
  client "$id" '
    add_repo
    inst nodejs24
    installed nodejs-24
    no installed nodejs-26
    no installed nodejs
    test "$(version nodejs-24)" = "$V24_OLD"
    default 24 "$V24_OLD"
  '

  log "$image: replace the distribution's nodejs and npm"
  id=$(start "$image")
  distro+=("$id")
  client "$id" '
    # Before our repository exists, as on any system that used them.
    if [ $fmt = deb ]; then
      apt-get update -qq
      inst nodejs npm
    else
      inst nodejs npm
      # RHEL 10 also has a versioned nodejs24; on RHEL 9 it is a module stream.
      if dnf -q list --available nodejs24 >/dev/null 2>&1; then inst nodejs24 nodejs24-npm; fi
    fi
    node -v
    npm -v
    add_repo
    if [ $fmt = deb ]; then
      inst nodejs
      no installed npm
    else
      dnf -y -q upgrade
      no installed nodejs-npm
      no installed nodejs24
      no installed nodejs24-npm
      if [ -e /usr/bin/node-24 ]; then installed nodejs-24; fi
    fi
    installed nodejs
    installed nodejs-26
    test "$(version nodejs)" = "$V26"
    default 26 "$V26"
    if installed nodejs-24; then versioned 24 "$V24_OLD"; fi
    npm install -g --no-audit --no-fund semver@7.7.2 >/dev/null
    test "$(semver 1.2.3)" = 1.2.3
    if [ $fmt = deb ]; then test -z "$(dpkg --audit)"; fi
  '
done

for image in $RPM_IMAGES; do
  log "$image: install one line next to the distribution's nodejs"
  id=$(start "$image")
  client "$id" '
    inst nodejs
    add_repo
    # Our nodejs-24 conflicts with RHEL'"'"'s nodejs (it owns /usr/bin/node),
    # so dnf upgrades that to our metapackage, which brings nodejs-26.
    inst nodejs24
    installed nodejs-24
    test "$(version nodejs)" = "$V26"
    installed nodejs-26
    default 26 "$V26"
    versioned 24 "$V24_OLD"
  '
done

for image in $NODESOURCE_IMAGES; do
  log "$image: replace NodeSource's nodejs"
  id=$(start "$image")
  client "$id" '
    apt-get update -qq
    apt-get install -y -qq curl gnupg ca-certificates >/dev/null
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null
    inst nodejs
    dpkg-query -W -f="\${Version}\n" nodejs | grep nodesource
    node -v
    npm -v
    add_repo
    # setup_lts.x pins its origin to 600, above our 500: apt keeps NodeSource.
    apt-cache policy nodejs | grep -A1 "Candidate:" | grep -q nodesource
    rm /etc/apt/preferences.d/nodejs /etc/apt/preferences.d/nsolid
    apt-get update -qq
    inst nodejs
    dpkg-query -W -f="\${Version}\n" nodejs | grep -qx "1:$V26-1"
    installed nodejs-26
    test ! -e /usr/lib/node_modules/npm
    test ! -e /usr/include/node
    default 26 "$V26"
    npm install -g --no-audit --no-fund semver@7.7.2 >/dev/null
    test "$(semver 1.2.3)" = 1.2.3
    test -z "$(dpkg --audit)"
  '
done

publish 2

# --- round 2 ---------------------------------------------------------------

for id in "${upgrade24[@]}"; do
  log "upgrade with only nodejs-24 installed"
  client "$id" '
    if [ $fmt = deb ]; then apt-get update -qq; apt-get -y -qq upgrade >/dev/null; apt-get -y -qq dist-upgrade >/dev/null
    else dnf -y -q --refresh upgrade; fi
    test "$(version nodejs-24)" = "$V24"
    no installed nodejs-26
    no installed nodejs
    default 24 "$V24"
    versioned 24 "$V24"
    purge nodejs-24
    gone
  '
done

for image in $DEB_IMAGES $RPM_IMAGES; do
  log "$image: install, switch and remove"
  id=$(start "$image")
  client "$id" '
    add_repo
    inst nodejs-lts
    installed nodejs
    installed nodejs-26
    no installed nodejs-24
    no installed nodejs-22
    default 26 "$V26"
    versioned 26 "$V26"
    alt_display | grep -q "/usr/lib/nodejs-26/bin/node - priority 260"

    inst nodejs24
    installed nodejs-24
    test "$(version nodejs-24)" = "$V24"
    inst nodejs22
    installed nodejs-22
    test "$(version nodejs-22)" = "$V22"
    # The newest line stays the default; every line keeps its own commands.
    default 26 "$V26"
    versioned 24 "$V24"
    versioned 22 "$V22"

    alt_set /usr/lib/nodejs-24/bin/node
    default 24 "$V24"
    versioned 26 "$V26"
    alt_set /usr/lib/nodejs-22/bin/node
    default 22 "$V22"
    # An upgrade keeps the manual choice: reinstall stands in for one.
    if [ $fmt = deb ]; then apt-get install -y -qq --reinstall nodejs-22 >/dev/null; else dnf -y -q reinstall nodejs-22; fi
    default 22 "$V22"
    # Removing the selected line goes back to automatic mode: the newest.
    purge nodejs-22
    default 26 "$V26"
    no installed nodejs-22
    test ! -e /usr/lib/nodejs-22

    # Removing the default line falls back to the next one. The metapackage
    # goes with it (it depends on nodejs-26).
    purge nodejs-26
    no installed nodejs
    default 24 "$V24"
    versioned 24 "$V24"
    test ! -e /usr/bin/node-26
    test ! -e /usr/lib/nodejs-26

    purge nodejs-24
    gone
  '
done

log "Node.js test passed"
