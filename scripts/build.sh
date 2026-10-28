#!/usr/bin/env bash
# Usage: build.sh NAME VERSION [ARCH...]
# Downloads the upstream binaries for NAME at VERSION, verifies them and wraps
# them into .deb and .rpm files under dist/. No compilation happens here.

source "$(dirname "$0")/lib.sh"

[[ $# -ge 2 ]] || die "usage: $0 NAME VERSION [ARCH...]"
name=$1 version=$2
shift 2
load_package "$name"
archs=("$@")
[[ ${#archs[@]} -gt 0 ]] || archs=("${ARCHS[@]}")

command -v nfpm >/dev/null || die "nfpm not found"
mkdir -p "$DIST"

for arch in "${archs[@]}"; do
  [[ " ${ARCHS[*]} " == *" $arch "* ]] || die "$name has no $arch build"

  # The stage holds a copy of packages/NAME plus whatever prepare() fetched,
  # so nfpm.yaml can refer to everything with relative paths.
  stage=$WORK/$name-$version-$arch
  rm -rf "$stage"
  mkdir -p "$stage/dl"
  cp -r "$PKG_DIR/." "$stage/"
  # packages/NAME/README.md documents the package in this repository only.
  rm -f "$stage/README.md"

  log "prepare $name $version $arch"
  (cd "$stage" && prepare "$version" "$arch")

  # rpm gets "<n>.xtom": rpmvercmp ranks "xtom" above "el10_x" or "fc43", so
  # we win against an EPEL/RHEL/Fedora build of the same upstream version.
  export VERSION=$version ARCH=$arch
  (cd "$stage" && RELEASE=$RELEASE nfpm package --config nfpm.yaml --packager deb --target "$DIST/")
  (cd "$stage" && RELEASE=$RELEASE.xtom nfpm package --config nfpm.yaml --packager rpm --target "$DIST/")

  # Record what was built so publish.sh can update versions.json.
  mkdir -p "$DIST/manifest"
  touch "$DIST/manifest/$name@$version@$arch"
done
