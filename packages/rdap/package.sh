# shellcheck shell=bash
UPSTREAM=xtomcom/rdap
BRANCHES=(1)
# 1.0.10-1 was the musl build; this is the glibc build.
RELEASE=2
TEST_CMD="rdap --version"

prepare() {
  local version=$1 file
  file=rdap-$version-linux-$(rpm_arch "$2")
  download "https://github.com/$UPSTREAM/releases/download/v$version/SHA256SUMS" dl/SHA256SUMS
  download "https://github.com/$UPSTREAM/releases/download/v$version/$file" "dl/$file"
  verify_sums dl/SHA256SUMS "dl/$file"
  check_glibc "dl/$file"
  install -Dm755 "dl/$file" rdap
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE" LICENSE
}
