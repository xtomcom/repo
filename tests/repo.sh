#!/usr/bin/env bash
# Usage: tests/repo.sh [NAME OLD_VERSION NEW_VERSION]
# End-to-end repository test with a throwaway GPG key and a local directory as
# the server. OLD and NEW must be in the same branch of NAME. Checks that:
#   - the first publish turns the old real rpm/elN directories into symlinks
#     and removes rpm/el8
#   - apt and dnf trust the repo and install OLD, also via rpm/el$releasever
#   - publishing NEW upgrades those clients and removes OLD from the indexes
#     and from the server
#   - publishing a file name that already exists is refused
#   - xtom.key on the server is never touched, README.md lists the package
#   - scripts/repo.sh sets up both client families and refuses unsupported ones
#   - the Cloudflare purge covers the indexes and every changed directory
#     listing (a fake curl records the API calls)

source "$(dirname "$0")/../scripts/lib.sh"

name=${1:-nfpm} old=${2:-2.47.0} new=${3:-2.48.0}
PUBLISH_IMAGE=${PUBLISH_IMAGE:-debian:13}
DEB_IMAGES=${DEB_IMAGES:-"debian:13 ubuntu:26.04"}
RPM_IMAGES=${RPM_IMAGES:-"rockylinux/rockylinux:10"}

tmp=$(mktemp -d)
# Containers are started from $(...) subshells, so track them by label.
label=xtom-repo-test=$$
cleanup() {
  docker ps -aq --filter "label=$label" | xargs -r docker rm -f >/dev/null
  docker run --rm -v "$tmp:/t" "$PUBLISH_IMAGE" sh -c 'rm -rf /t/*'
  rm -rf "$tmp"
}
trap cleanup EXIT

# start IMAGE: a long-running container with the repo mounted at /repo; prints its id.
start() {
  docker run -d --label "$label" -v "$ROOT:/src:ro" -v "$tmp:/t" -v "$tmp/www:/repo" \
    -e NAME="$name" -e OLD="$old" -e NEW="$new" "$1" sleep infinity
}
run() { docker exec "$1" bash -euc "$2"; }

for v in "$old" "$new"; do
  DIST=$tmp/dist-$v WORK=$tmp/work "$ROOT/scripts/build.sh" "$name" "$v"
done
mkdir -p "$tmp/www"

publisher=$(start "$PUBLISH_IMAGE")
run "$publisher" '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq apt-utils createrepo-c rpm gnupg rsync jq xz-utils >/dev/null
  export GNUPGHOME=/t/gnupg
  mkdir -m700 "$GNUPGHOME"
  gpg --batch --passphrase "" --quick-gen-key "Test <test@example.com>" ed25519 sign never
  # Stand-in for the Cloudflare API: record what would be purged.
  mkdir -p /t/bin
  printf "%s\n" "#!/bin/sh" \
    "case \"\$*\" in *api.cloudflare.com*) cat >> /t/purged.json; echo \"{\\\"success\\\": true}\" ;; *) exec /usr/bin/curl \"\$@\" ;; esac" > /t/bin/curl
  chmod +x /t/bin/curl
  # xtom.key is maintained by hand on the server; publish.sh must leave it alone.
  gpg --armor --export > /t/www/xtom.key
  sha256sum /t/www/xtom.key > /t/xtom.key.sha256
  # The old layout had a real directory per EL release.
  mkdir -p /t/www/rpm/el9/x86_64/repodata /t/www/rpm/el9/x86_64/Packages
  touch /t/www/rpm/el9/x86_64/repodata/repomd.xml /t/www/rpm/el9/x86_64/Packages/old.rpm
  # el8 is no longer supported; its link must go away.
  ln -s . /t/www/rpm/el8
'
publish() {
  run "$publisher" "
    export GNUPGHOME=/t/gnupg REPO_DEST=/t/www PUBLIC_URL=file:///repo WORK=/t/work VERSIONS_FILE=/t/versions.json
    export PATH=/t/bin:\$PATH CF_ZONE_ID=test CF_API_TOKEN=test
    export GPG_KEY_ID=\$(gpg --list-keys --with-colons | awk -F: '/^fpr/ {print \$10; exit}')
    DIST=/t/dist-$1 /src/scripts/publish.sh
  "
}

log "publish $old"
publish "$old"
run "$publisher" 'test "$(readlink /t/www/rpm/el9)" = . && test ! -e /t/www/rpm/el8 && test ! -L /t/www/rpm/el8'

deb_clients=() rpm_clients=()
for image in $DEB_IMAGES; do
  log "apt install $old on $image"
  id=$(start "$image")
  deb_clients+=("$id")
  run "$id" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq curl >/dev/null
    # An entry in the old one-line style, which repo.sh must replace.
    echo "deb file:///repo/deb stable main" > /etc/apt/sources.list.d/xtom.list
    REPO_URL=file:///repo bash /src/scripts/repo.sh
    test ! -e /etc/apt/sources.list.d/xtom.list
    apt-get install -y -qq "$NAME"
    dpkg-query -W -f="\${Version}\n" "$NAME" | grep -q -- ":\?$OLD-"
  '
done
for image in $RPM_IMAGES; do
  log "dnf install $old on $image"
  id=$(start "$image")
  rpm_clients+=("$id")
  run "$id" '
    REPO_URL=file:///repo bash /src/scripts/repo.sh
    # Old configs point at rpm/el$releasever/$basearch, which must keep working.
    sed "s|rpm/|rpm/el\$releasever/|; s|^\[xtom\]|[xtom-el]|" /repo/rpm/xtom.repo > /etc/yum.repos.d/xtom-el.repo
    dnf -y -q install "$NAME"
    test "$(rpm -q --qf "%{VERSION}" "$NAME")" = "$OLD"
  '
done

log "publish $new"
publish "$new"
run "$publisher" '
  cat /t/versions.json
  test "$(jq -c --arg n "$NAME" ".[\$n]" /t/versions.json)" = "[\"$NEW-1\"]"
  test -z "$(find /t/www -name "*$OLD*")"
  sha256sum -c --quiet /t/xtom.key.sha256
  # The publishes purged the indexes, the listings of the directories they
  # changed and their parents, also under the el9/el10 links.
  jq -r ".files[]" /t/purged.json | sort -u > /t/purged.txt
  for u in deb/dists/stable/InRelease rpm/x86_64/repodata/repomd.xml README.md "" deb/ deb/pool/main/ \
    "deb/pool/main/${NAME:0:1}/$NAME/" rpm/x86_64/Packages/ rpm/el9/x86_64/Packages/ rpm/el10/ deb/dists/stable/main/binary-amd64/; do
    grep -qxF "file:///repo/$u" /t/purged.txt || { echo "not purged: $u"; exit 1; }
  done
  test "$(jq -s "map(.files | length) | max" /t/purged.json)" -le 30
  grep -q "^| \[$NAME\](.*) | $NEW | " /t/www/README.md
'

for id in "${deb_clients[@]}"; do
  log "apt upgrade to $new"
  run "$id" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    test "$(apt-cache madison "$NAME" | grep -c file:/repo)" = 1
    apt-get install -y -qq --only-upgrade "$NAME"
    dpkg-query -W -f="\${Version}\n" "$NAME" | grep -q -- ":\?$NEW-"
  '
done
for id in "${rpm_clients[@]}"; do
  log "dnf upgrade to $new"
  run "$id" '
    test "$(dnf -q --refresh --showduplicates list available "$NAME" 2>/dev/null | grep -c "^$NAME" || true)" -le 2
    dnf -y -q upgrade "$NAME"
    test "$(rpm -q --qf "%{VERSION}" "$NAME")" = "$NEW"
  '
done

log "republishing $new must be refused"
if publish "$new" 2>/dev/null; then die "republishing $new was not refused"; fi

log "repo.sh must refuse unsupported setups"
refuse() {
  local image=$1 want=$2 out
  shift 2
  if out=$(docker run --rm "$@" -v "$ROOT:/src:ro" "$image" bash /src/scripts/repo.sh 2>&1); then
    die "repo.sh succeeded on $image $*"
  fi
  [[ $out == *"$want"* ]] || die "repo.sh on $image $*: unexpected output: $out"
}
refuse debian:13 "run this as root" --user 1000
refuse debian:11 "Debian 12 or newer is required"
refuse ubuntu:20.04 "Ubuntu 22.04 or newer is required"
refuse rockylinux:8 "version 9 or newer is required"

log "repository test passed"
