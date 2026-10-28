# shellcheck shell=bash
UPSTREAM=xtomcom/rdap
BRANCHES=(1)
TEST_CMD="rdap --version"

prepare() {
  local version=$1 file
  file=rdap-$version-linux-$(rpm_arch "$2")-musl
  download "https://github.com/$UPSTREAM/releases/download/v$version/SHA256SUMS" dl/SHA256SUMS
  download "https://github.com/$UPSTREAM/releases/download/v$version/$file" "dl/$file"
  verify_sums dl/SHA256SUMS "dl/$file"
  install -Dm755 "dl/$file" rdap
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE" LICENSE
}
