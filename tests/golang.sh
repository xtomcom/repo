#!/usr/bin/env bash
# Usage: tests/golang.sh
# End-to-end test of the Go packages (the golang metapackage and the
# co-installable golang-1.NN) through a local signed repository, as a user
# sees them, on every client image. Like tests/repo.sh, a throwaway GPG key
# signs and a local directory is the server. Checks:
#   - the single golang package published before the split (built from
#     OLD_REF) upgrades with apt upgrade / dnf upgrade to the metapackage plus
#     golang-1.NN, with go working, no stale alternatives and no file conflicts
#   - the distribution's own golang upgrades to ours
#   - install golang / go gives the newest version; every alias of the older
#     version (golang1.NN, go1.NN, go-1.NN, Debian's golang-1.NN-go) installs it
#   - with both installed the newest is the default, the alternatives switch
#     go, gofmt and GOROOT, and the versioned commands always work
#   - removing the newest falls back to the older one, which a full upgrade
#     never replaces with the newest
#   - removing everything leaves no links, alternatives or GOROOTs behind
# Builds only ARCH (amd64 by default); publish.sh is told the others passed.

source "$(dirname "$0")/../scripts/lib.sh"

PUBLISH_IMAGE=${PUBLISH_IMAGE:-debian:13}
DEB_IMAGES=${DEB_IMAGES:-"debian:13 ubuntu:26.04"}
RPM_IMAGES=${RPM_IMAGES:-"rockylinux/rockylinux:10"}
ARCH=${ARCH:-amd64}
# The last commit with the single golang package, and the version of it that
# users have installed.
OLD_REF=${OLD_REF:-c096158}
OLD_VERSION=${OLD_VERSION:-1.27.3}

command -v nfpm >/dev/null || die "nfpm not found"

# The two newest golang-1.NN packages: B1 is what the metapackage installs.
mapfile -t branches < <(cd "$ROOT/packages" && printf '%s\n' golang-[0-9]*.[0-9]* | sed 's/^golang-//' | sort -rV)
[[ ${#branches[@]} -ge 2 ]] || die "need two golang-1.NN packages"
B1=${branches[0]} B2=${branches[1]}
latest() { VERSIONS_FILE=/dev/null "$ROOT/scripts/check.sh" "golang-$1" | jq -r '.[0].version'; }
V1=$(latest "$B1") V2=$(latest "$B2")
load_package golang
META=$V1-$RELEASE
log "golang $META -> golang-$B1 $V1, golang-$B2 $V2; old golang $OLD_VERSION from $OLD_REF"

tmp=$(mktemp -d)
# Containers are started from $(...) subshells, so track them by label.
label=xtom-golang-test=$$
cleanup() {
  docker ps -aq --filter "label=$label" | xargs -r docker rm -f >/dev/null
  docker run --rm -v "$tmp:/t" "$PUBLISH_IMAGE" sh -c 'rm -rf /t/*'
  rm -rf "$tmp"
}
trap cleanup EXIT

# build ROOT DIST NAME VERSION: build for ARCH only and mark the other
# architectures as passed, so publish.sh takes the release.
build() {
  DIST=$2 WORK=$tmp/work "$1/scripts/build.sh" "$3" "$4" "$ARCH"
  touch "$2/manifest/$3@$4@amd64" "$2/manifest/$3@$4@arm64"
}
# The old package with the scripts of its time, as a temporary ROOT.
mkdir -p "$tmp/old"
git -C "$ROOT" archive "$OLD_REF" scripts site packages/golang | tar -x -C "$tmp/old"
build "$tmp/old" "$tmp/dist-old" golang "$OLD_VERSION"
build "$ROOT" "$tmp/dist-new" "golang-$B1" "$V1"
build "$ROOT" "$tmp/dist-new" "golang-$B2" "$V2"
build "$ROOT" "$tmp/dist-new" golang "$V1"
rm -rf "$tmp/work"
mkdir -p "$tmp/www"

# Helpers for the clients, sourced by every run below.
cat > "$tmp/client.sh" <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if command -v dpkg >/dev/null; then deb=true; else deb=false; fi
fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "--- $*" >&2; }
# quiet CMD...: run CMD, showing its output only when it fails.
quiet() { "$@" >/tmp/out 2>&1 || { cat /tmp/out; fail "$*"; }; }
inst() {
  step "install $*"
  if $deb; then quiet apt-get install -y --no-install-recommends "$@"
  else quiet dnf -y --setopt=install_weak_deps=False install "$@"; fi
}
remove() {
  step "remove $*"
  if $deb; then quiet apt-get purge -y --autoremove "$@"
  else quiet dnf -y remove "$@"; fi
}
installed() {
  if $deb; then dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q " installed$"
  else rpm -q "$1" >/dev/null 2>&1; fi
}
version() {
  if $deb; then dpkg-query -W -f='${Version}' "$1"
  else rpm -q --qf '%{EPOCH}:%{VERSION}-%{RELEASE}' "$1" | sed 's/\.xtom$//'; fi
}
# The alternatives of go, one path per line.
alts() {
  if $deb; then update-alternatives --list go 2>/dev/null || true
  else alternatives --display go 2>/dev/null | sed -n 's| - priority.*||p'; fi
}
# expect_alts BRANCH...: go has exactly these alternatives.
expect_alts() {
  local want got b
  want=$(for b in "$@"; do echo "/usr/lib/go-$b/bin/go"; done | sort)
  got=$(alts | sort)
  [ "$got" = "$want" ] || fail "alternatives for go: got [$got], want [$want]"
}
# set_go BRANCH: choose the default go by hand.
set_go() {
  step "select go $1"
  if $deb; then update-alternatives --set go "/usr/lib/go-$1/bin/go"
  else alternatives --set go "/usr/lib/go-$1/bin/go"; fi
}
hello() {
  mkdir -p /tmp/hello
  printf 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("hello from", "go")\n}\n' > /tmp/hello/main.go
  (cd /tmp/hello && "$1" run main.go) | grep -Fx "hello from go" >/dev/null || fail "$1 run"
}
# check_go CMD BRANCH VERSION: CMD (go or go-1.NN) is that version and works.
check_go() {
  "$1" version | grep -F "go version go$3 linux/" >/dev/null || fail "$1 version: $("$1" version)"
  [ "$("$1" env GOROOT)" = "/usr/lib/go-$2" ] || fail "$1 env GOROOT: $("$1" env GOROOT)"
  hello "$1"
}
# check_default BRANCH VERSION: go, gofmt and the GOROOT links point to it.
check_default() {
  step "default go is $2"
  check_go go "$1" "$2"
  [ "$(readlink -f /usr/bin/gofmt)" = "/usr/lib/go-$1/bin/gofmt" ] || fail "gofmt -> $(readlink -f /usr/bin/gofmt)"
  [ "$(readlink -f /usr/lib/go)" = "/usr/lib/go-$1" ] || fail "/usr/lib/go -> $(readlink -f /usr/lib/go)"
  if $deb; then
    [ "$(readlink -f /usr/share/go)" = "/usr/lib/go-$1" ] || fail "/usr/share/go -> $(readlink -f /usr/share/go)"
  fi
  gofmt -l /tmp/hello/main.go >/dev/null
}
# check_versioned BRANCH VERSION: go-1.NN and gofmt-1.NN work.
check_versioned() {
  step "go-$1 is $2"
  check_go "go-$1" "$1" "$2"
  [ -z "$("gofmt-$1" -l /tmp/hello/main.go)" ] || fail "gofmt-$1"
}
# check_ours BRANCH: golang-BRANCH is installed and is ours, not the distribution's.
check_ours() {
  installed "golang-$1" || fail "golang-$1 is not installed"
  version "golang-$1" | grep -q "^2:$1\." || fail "golang-$1 $(version "golang-$1") is not ours"
}
# no_old_goroot: nothing left of the GOROOT of the old package or Fedora's
# golang. Rocky's golang-bin leaves the unowned, empty bin/linux_ARCH
# directories behind even when it is simply removed, so only files count.
no_old_goroot() {
  local left
  left=$(find /usr/lib/golang ! -type d 2>/dev/null || true)
  [ -z "$left" ] || fail "left in /usr/lib/golang: $left"
}
check_clean() {
  local f left
  step "nothing left"
  no_old_goroot
  for f in /usr/bin/go /usr/bin/gofmt /usr/lib/go /usr/share/go \
    /etc/alternatives/go /etc/alternatives/gofmt /etc/alternatives/golang-lib /etc/alternatives/golang-share \
    /var/lib/dpkg/alternatives/go /var/lib/alternatives/go; do
    [ ! -e "$f" ] && [ ! -L "$f" ] || fail "$f is left"
  done
  left=$(ls -d /usr/lib/go-* /usr/share/go-* /usr/bin/go-* /usr/bin/gofmt-* 2>/dev/null || true)
  [ -z "$left" ] || fail "left: $left"
  left=$(find /etc/alternatives -xtype l)
  [ -z "$left" ] || fail "dangling alternatives: $left"
  [ -z "$(alts)" ] || fail "go alternatives left: $(alts)"
  if $deb; then left=$(dpkg-query -W -f='${Package} ${Status}\n' 'golang*' 2>/dev/null | grep " installed$" || true)
  else left=$(rpm -qa 'golang*'); fi
  [ -z "$left" ] || fail "packages left: $left"
}
# add_repo: our repository, as users add it.
add_repo() {
  step "add repository"
  if $deb; then quiet apt-get update && quiet apt-get install -y curl; fi
  REPO_URL=file:///repo quiet bash /src/scripts/repo.sh
}
refresh() { if $deb; then quiet apt-get update; else quiet dnf -y makecache --refresh; fi; }
EOF

# start IMAGE: a long-running container with the repo mounted at /repo; prints its id.
start() {
  docker run -d --label "$label" --platform "linux/$ARCH" -v "$ROOT:/src:ro" -v "$tmp:/t" -v "$tmp/www:/repo" \
    -e B1="$B1" -e V1="$V1" -e B2="$B2" -e V2="$V2" -e META="$META" -e OLD_VERSION="$OLD_VERSION" \
    -e TEST_CMD="$TEST_CMD" "$1" sleep infinity
}
run() { docker exec "$1" bash -euc "source /t/client.sh; $2"; }

publisher=$(start "$PUBLISH_IMAGE")
run "$publisher" '
  quiet apt-get update
  quiet apt-get install -y apt-utils createrepo-c rpm gnupg rsync jq xz-utils
  export GNUPGHOME=/t/gnupg
  mkdir -m700 "$GNUPGHOME"
  quiet gpg --batch --passphrase "" --quick-gen-key "Test <test@example.com>" ed25519 sign never
  gpg --armor --export > /t/www/xtom.key
  # As on the server, versions.json exists (publish.sh fails without it).
  echo "{}" > /t/versions.json
'
# publish ROOT DIST: publish.sh of that tree, with the shared versions.json.
publish() {
  run "$publisher" "
    export GNUPGHOME=/t/gnupg REPO_DEST=/t/www PUBLIC_URL=file:///repo WORK=/t/work VERSIONS_FILE=/t/versions.json
    export GPG_KEY_ID=\$(gpg --list-keys --with-colons | awk -F: '/^fpr/ {print \$10; exit}')
    DIST=$2 $1/scripts/publish.sh
  "
}

log "publish the old golang $OLD_VERSION"
publish /t/old /t/dist-old

# Per image: one client upgrading the old package, one upgrading the
# distribution's golang, one starting fresh.
declare -A old_client=() distro_client=()
for image in $DEB_IMAGES $RPM_IMAGES; do
  log "$image: install the old golang $OLD_VERSION"
  id=$(start "$image")
  old_client[$image]=$id
  run "$id" '
    add_repo
    inst golang
    version golang | grep -q "^2:$OLD_VERSION-1$" || fail "old golang is $(version golang)"
    go version | grep -qF "go$OLD_VERSION "
    hello go
  '
  log "$image: install the distribution's golang"
  id=$(start "$image")
  distro_client[$image]=$id
  run "$id" '
    if $deb; then quiet apt-get update; fi
    inst golang
    go version
    hello go
  '
done

log "publish the new packages"
publish /src /t/dist-new
run "$publisher" '
  cat /t/versions.json
  test "$(jq -c ".golang" /t/versions.json)" = "[\"$META\"]"
  test "$(jq -c ".[\"golang-$B1\"]" /t/versions.json)" = "[\"$V1-1\"]"
  test "$(jq -c ".[\"golang-$B2\"]" /t/versions.json)" = "[\"$V2-1\"]"
  # The old single package is gone from the indexes and the server.
  ! find /t/www -name "golang[_-]$OLD_VERSION-1[._]*" | grep .
'

for image in $DEB_IMAGES $RPM_IMAGES; do
  log "$image: upgrade the old golang"
  run "${old_client[$image]}" '
    refresh
    step "upgrade"
    if $deb; then quiet apt upgrade -y; else quiet dnf -y upgrade; fi
    [ "$(version golang)" = "2:$META" ] || fail "golang is $(version golang)"
    check_ours "$B1"
    ! installed "golang-$B2" || fail "golang-$B2 was installed"
    check_default "$B1" "$V1"
    check_versioned "$B1" "$V1"
    expect_alts "$B1"
    if $deb; then
      # Every file of golang-1.NN belongs to it alone.
      dpkg -S "/usr/lib/go-$B1/bin/go" | grep -qx "golang-$B1: /usr/lib/go-$B1/bin/go"
      quiet dpkg --audit
    else
      no_old_goroot
      quiet rpm -V "golang-$B1"
    fi
    remove golang "golang-$B1"
    check_clean
  '

  log "$image: upgrade the distribution's golang"
  run "${distro_client[$image]}" '
    add_repo
    step "upgrade"
    if $deb; then quiet apt-get full-upgrade -y; else quiet dnf -y upgrade; fi
    [ "$(version golang)" = "2:$META" ] || fail "golang is $(version golang)"
    check_ours "$B1"
    check_default "$B1" "$V1"
    if $deb; then
      for p in golang-go golang-src golang-doc; do ! installed $p || fail "$p is still installed"; done
      quiet dpkg --audit
    else
      for p in golang-bin golang-src; do ! installed $p || fail "$p is still installed"; done
      no_old_goroot
    fi
    # Ubuntu has its own golang-1.NN for its golang, which we upgrade too.
    if installed "golang-$B2"; then
      check_ours "$B2"
      check_versioned "$B2" "$V2"
      expect_alts "$B1" "$B2"
    else
      expect_alts "$B1"
    fi
    pkgs="golang golang-$B1"
    if installed "golang-$B2"; then pkgs="$pkgs golang-$B2"; fi
    remove $pkgs
    check_clean
  '

  log "$image: fresh installs"
  id=$(start "$image")
  run "$id" '
    add_repo
    for name in golang go; do
      inst $name
      [ "$(version golang)" = "2:$META" ] || fail "$name: golang is $(version golang)"
      check_ours "$B1"
      ! installed "golang-$B2" || fail "$name: golang-$B2 was installed"
      check_default "$B1" "$V1"
      check_versioned "$B1" "$V1"
      expect_alts "$B1"
      # The package test of build.sh/test.sh, which cannot install the
      # metapackage on its own.
      (cd /tmp && PKG=golang_$META bash -euc "$TEST_CMD" >/dev/null) || fail "TEST_CMD"
      remove golang "golang-$B1"
      check_clean
    done

    aliases="golang$B2 go$B2 go-$B2"
    # Debian names the same version golang-1.NN-go; use it only where the
    # distribution has no real package of that name.
    if $deb && ! apt-cache show "golang-$B2-go" 2>/dev/null | grep "^Package:" >/dev/null; then
      aliases="$aliases golang-$B2-go"
    fi
    for name in $aliases; do
      inst "$name"
      check_ours "$B2"
      ! installed golang || fail "$name: golang was installed"
      ! installed "golang-$B1" || fail "$name: golang-$B1 was installed"
      check_default "$B2" "$V2"
      check_versioned "$B2" "$V2"
      expect_alts "$B2"
      remove "golang-$B2"
      check_clean
    done

    step "both versions"
    inst golang "golang-$B2"
    check_default "$B1" "$V1"
    check_versioned "$B1" "$V1"
    check_versioned "$B2" "$V2"
    expect_alts "$B1" "$B2"
    set_go "$B2"
    check_default "$B2" "$V2"
    check_versioned "$B1" "$V1"
    set_go "$B1"
    check_default "$B1" "$V1"
    check_versioned "$B2" "$V2"

    # The newest chosen by hand, then removed: back to the older one.
    remove "golang-$B1"
    ! installed golang || fail "golang is still installed"
    check_ours "$B2"
    check_default "$B2" "$V2"
    check_versioned "$B2" "$V2"
    expect_alts "$B2"

    step "full upgrade with only golang-$B2"
    if $deb; then quiet apt-get full-upgrade -y; else quiet dnf -y upgrade; fi
    ! installed "golang-$B1" || fail "the upgrade installed golang-$B1"
    ! installed golang || fail "the upgrade installed golang"
    check_default "$B2" "$V2"

    remove "golang-$B2"
    check_clean
  '
done

log "golang test passed"
