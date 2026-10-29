#!/usr/bin/env bash
# Usage: test.sh NAME VERSION ARCH
# Installs the built .deb/.rpm in clean containers of the newest supported
# distributions, runs the package's TEST_CMD, then removes the package again.
# Packages that set SERVICE_TEST are also tested under a real systemd.
# The containers resolve dependencies from the distribution's own repositories,
# exactly like a user running `apt install ./x.deb` or `dnf install ./x.rpm`.

source "$(dirname "$0")/lib.sh"

DEB_IMAGES=${DEB_IMAGES:-"debian:13 ubuntu:26.04"}
RPM_IMAGES=${RPM_IMAGES:-"rockylinux/rockylinux:10"}

[[ $# -eq 3 ]] || die "usage: $0 NAME VERSION ARCH"
name=$1 version=$2 arch=$3
load_package "$name"
[[ -n $TEST_CMD ]] || die "$name: TEST_CMD is empty"

shopt -s nullglob
debs=("$DIST/${name}_"*"${version}-${RELEASE}_${arch}.deb")
rpms=("$DIST/${name}-${version}-${RELEASE}.xtom."*"$(rpm_arch "$arch").rpm")
shopt -u nullglob
[[ ${#debs[@]} -eq 1 ]] || die "expected one deb for $name $version $arch in $DIST, found ${#debs[@]}"
[[ ${#rpms[@]} -eq 1 ]] || die "expected one rpm for $name $version $arch in $DIST, found ${#rpms[@]}"

# A metapackage names the packages it depends on in TEST_DEPS. No repository
# has them inside the test containers, so build them at the same version and
# install them together with it. They are built into $DIST/.deps: their own CI
# jobs upload the real ones, and hidden paths are neither uploaded as
# artifacts nor published, so the two builds can never overwrite each other.
deps=$DIST/.deps
# built DEP: its .deb and .rpm in $deps, one per line (a subshell, so loading
# DEP doesn't replace this package's settings).
built() (
  load_package "$1"
  shopt -s nullglob
  printf '%s\n' "$deps/${1}_"*"${version}-${RELEASE}_${arch}.deb" "$deps/${1}-${version}-${RELEASE}.xtom."*"$(rpm_arch "$arch").rpm"
)
for dep in "${TEST_DEPS[@]}"; do
  [[ $(built "$dep" | wc -l) -eq 2 ]] || DIST=$deps "$ROOT/scripts/build.sh" "$dep" "$version" "$arch"
  mapfile -t found < <(built "$dep")
  [[ ${#found[@]} -eq 2 ]] || die "could not build $dep $version $arch"
  debs+=("${found[0]}") rpms+=("${found[1]}")
done
# Paths as seen inside the containers, which mount $DIST at /pkg.
pkgs() { local f out=(); for f in "$@"; do out+=("/pkg/${f#"$DIST"/}"); done; echo "${out[*]}"; }

run() {
  local image=$1 files=$2 script=$3
  log "test ${files//\/pkg\//} on $image"
  docker run --rm --platform "linux/$arch" \
    -v "$DIST:/pkg:ro" -e PKG="$files" -e NAME="$name" -e TEST_CMD="$TEST_CMD" \
    "$image" bash -euxc "$script"
}

for image in $DEB_IMAGES; do
  run "$image" "$(pkgs "${debs[@]}")" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    # shellcheck disable=SC2086 # PKG lists the package and its TEST_DEPS
    apt-get install -y -qq $PKG
    bash -euxc "$TEST_CMD"
    apt-get purge -y -qq "$NAME"
  '
done

for image in $RPM_IMAGES; do
  run "$image" "$(pkgs "${rpms[@]}")" '
    # shellcheck disable=SC2086
    dnf install -y -q $PKG
    bash -euxc "$TEST_CMD"
    dnf remove -y -q "$NAME"
  '
done

[[ -n $SERVICE_TEST ]] || exit 0

# Packages with a service also run under a real systemd (PID 1), where we
# check that installing prints the start notice but starts nothing, that
# SERVICE_TEST can configure and start the service and reach it, and that
# removing the package stops it.

# systemd_image IMAGE: a local image of IMAGE with systemd as its init.
systemd_image() {
  local tag=xtom-systemd-test:${1//[\/:]/-}-$arch install
  case $1 in
    rockylinux*) install='dnf install -y -q systemd procps-ng && dnf clean all' ;;
    *) install='apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv curl ca-certificates >/dev/null && apt-get clean' ;;
  esac
  printf 'FROM %s\nRUN %s\nCMD ["/sbin/init"]\n' "$1" "$install" |
    docker build -q --platform "linux/$arch" -t "$tag" - >/dev/null
  echo "$tag"
}

# Label the containers so they are removed however this script exits; a
# RETURN trap would not run when set -e ends it inside the function.
label=xtom-systemd-test=$$
trap 'docker ps -aq --filter "label=$label" | xargs -r docker rm -f >/dev/null' EXIT

run_systemd() {
  local image=$1 files=$2 install=$3 remove=$4 id state
  log "service test ${files//\/pkg\//} on $image"
  id=$(docker run -d --label "$label" --platform "linux/$arch" --privileged --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
    -v "$DIST:/pkg:ro" "$(systemd_image "$image")")
  for _ in $(seq 60); do
    state=$(docker exec "$id" systemctl is-system-running 2>/dev/null || true)
    [[ $state == running || $state == degraded ]] && break
    sleep 1
  done
  docker exec -e PKG="$files" -e NAME="$name" -e SERVICE_TEST="$SERVICE_TEST" \
    -e INSTALL="$install" -e REMOVE="$remove" "$id" bash -euxc '
    out=$(eval "$INSTALL" 2>&1) || { echo "$out"; exit 1; }
    echo "$out" | grep -q "is installed but not started" || { echo "$out"; echo "no start notice"; exit 1; }
    units=$( (dpkg -L "$NAME" 2>/dev/null || rpm -ql "$NAME") | grep -E "/systemd/system/[^@/]+\.service$" | xargs -rn1 basename)
    for u in $units; do
      [ "$(systemctl is-active "$u" || true)" = inactive ] || { echo "$u was started on install"; exit 1; }
    done
    bash -euxc "$SERVICE_TEST"
    # Removal must also undo `systemctl enable`, leaving no dangling links.
    for u in $units; do systemctl enable "$u"; done
    eval "$REMOVE"
    for u in $units; do
      [ "$(systemctl is-active "$u" || true)" != active ] || { echo "$u still running after removal"; exit 1; }
      ! systemctl cat "$u" >/dev/null 2>&1 || { echo "$u still installed after removal"; exit 1; }
    done
    dangling=$(find /etc/systemd/system -xtype l)
    [ -z "$dangling" ] || { echo "links to removed units left behind: $dangling"; exit 1; }
  '
  docker rm -f "$id" >/dev/null
}

for image in $DEB_IMAGES; do
  run_systemd "$image" "$(pkgs "${debs[@]}")" \
    'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y $PKG' \
    'DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq "$NAME"'
done
for image in $RPM_IMAGES; do
  run_systemd "$image" "$(pkgs "${rpms[@]}")" 'dnf install -y $PKG' 'dnf remove -y -q "$NAME"'
done
