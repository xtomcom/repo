#!/usr/bin/env bash
# Usage: tests/repo.sh [NAME OLD_VERSION NEW_VERSION]
# End-to-end repository test with a throwaway GPG key and a local directory as
# the server. OLD and NEW must be in the same branch of NAME. Checks that:
#   - the first publish turns the old real rpm/elN directories into symlinks
#   - apt and dnf trust the repo and install OLD, also via rpm/el$releasever
#   - publishing NEW upgrades those clients and removes OLD from the indexes
#     and from the server
#   - publishing a file name that already exists is refused
#   - xtom.key on the server is never touched, README.md lists the package

source "$(dirname "$0")/../scripts/lib.sh"

name=${1:-rdap} old=${2:-1.0.8} new=${3:-1.0.9}
PUBLISH_IMAGE=${PUBLISH_IMAGE:-debian:13}
DEB_IMAGES=${DEB_IMAGES:-"debian:13 ubuntu:26.04"}
RPM_IMAGES=${RPM_IMAGES:-"rockylinux/rockylinux:10"}

tmp=$(mktemp -d)
containers=()
cleanup() {
  [[ ${#containers[@]} -eq 0 ]] || docker rm -f "${containers[@]}" >/dev/null
  docker run --rm -v "$tmp:/t" "$PUBLISH_IMAGE" sh -c 'rm -rf /t/*'
  rm -rf "$tmp"
}
trap cleanup EXIT

# start IMAGE: a long-running container with the repo mounted at /repo; prints its id.
start() {
  local id
  id=$(docker run -d -v "$ROOT:/src:ro" -v "$tmp:/t" -v "$tmp/www:/repo" \
    -e NAME="$name" -e OLD="$old" -e NEW="$new" "$1" sleep infinity)
  containers+=("$id")
  echo "$id"
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
  # xtom.key is maintained by hand on the server; publish.sh must leave it alone.
  gpg --armor --export > /t/www/xtom.key
  sha256sum /t/www/xtom.key > /t/xtom.key.sha256
  # The old layout had a real directory per EL release.
  mkdir -p /t/www/rpm/el9/x86_64/repodata /t/www/rpm/el9/x86_64/Packages
  touch /t/www/rpm/el9/x86_64/repodata/repomd.xml /t/www/rpm/el9/x86_64/Packages/old.rpm
'
publish() {
  run "$publisher" "
    export GNUPGHOME=/t/gnupg REPO_DEST=/t/www PUBLIC_URL=file:///repo WORK=/t/work VERSIONS_FILE=/t/versions.json
    export GPG_KEY_ID=\$(gpg --list-keys --with-colons | awk -F: '/^fpr/ {print \$10; exit}')
    DIST=/t/dist-$1 /src/scripts/publish.sh
  "
}

log "publish $old"
publish "$old"
run "$publisher" 'test "$(readlink /t/www/rpm/el9)" = .'

deb_clients=() rpm_clients=()
for image in $DEB_IMAGES; do
  log "apt install $old on $image"
  id=$(start "$image")
  deb_clients+=("$id")
  run "$id" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq gpg >/dev/null
    gpg --dearmor < /repo/xtom.key > /usr/share/keyrings/xtom.gpg
    echo "deb [signed-by=/usr/share/keyrings/xtom.gpg] file:///repo/deb stable main" > /etc/apt/sources.list.d/xtom.list
    apt-get update -qq
    apt-get install -y -qq "$NAME"
    dpkg-query -W -f="\${Version}\n" "$NAME" | grep -q -- ":\?$OLD-"
  '
done
for image in $RPM_IMAGES; do
  log "dnf install $old on $image"
  id=$(start "$image")
  rpm_clients+=("$id")
  run "$id" '
    cp /repo/rpm/xtom.repo /etc/yum.repos.d/
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
  test "$(jq -c --arg n "$NAME" ".[\$n]" /t/versions.json)" = "[\"$NEW\"]"
  ! find /t/www -name "*$OLD*" | grep .
  sha256sum -c --quiet /t/xtom.key.sha256
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

log "repository test passed"
