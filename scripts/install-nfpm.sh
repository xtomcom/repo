#!/usr/bin/env bash
# Usage: install-nfpm.sh [DIR]
# Installs the pinned nfpm release into DIR (default /usr/local/bin).

source "$(dirname "$0")/lib.sh"

NFPM_VERSION=2.48.0
dir=${1:-/usr/local/bin}
case $(uname -m) in x86_64) arch=x86_64 ;; aarch64) arch=arm64 ;; *) die "unsupported $(uname -m)" ;; esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
base=https://github.com/goreleaser/nfpm/releases/download/v$NFPM_VERSION
file=nfpm_${NFPM_VERSION}_Linux_$arch.tar.gz
download "$base/checksums.txt" "$tmp/checksums.txt"
download "$base/$file" "$tmp/$file"
verify_sums "$tmp/checksums.txt" "$tmp/$file"
tar -xzf "$tmp/$file" -C "$tmp" nfpm
install -m755 "$tmp/nfpm" "$dir/nfpm"
