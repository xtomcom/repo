#!/usr/bin/env bash
# Usage: test.sh NAME VERSION ARCH
# Installs the built .deb/.rpm in clean containers of the newest supported
# distributions, runs the package's TEST_CMD, then removes the package again.
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

run() {
  local image=$1 file=$2 script=$3
  log "test $(basename "$file") on $image"
  docker run --rm --platform "linux/$arch" \
    -v "$file:/pkg/$(basename "$file"):ro" \
    -e PKG="/pkg/$(basename "$file")" -e NAME="$name" -e TEST_CMD="$TEST_CMD" \
    "$image" bash -euxc "$script"
}

for image in $DEB_IMAGES; do
  run "$image" "${debs[0]}" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq "$PKG"
    bash -euxc "$TEST_CMD"
    apt-get purge -y -qq "$NAME"
  '
done

for image in $RPM_IMAGES; do
  run "$image" "${rpms[0]}" '
    dnf install -y -q "$PKG"
    bash -euxc "$TEST_CMD"
    dnf remove -y -q "$NAME"
  '
done
