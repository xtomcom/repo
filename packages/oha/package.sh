# shellcheck shell=bash
UPSTREAM=hatoo/oha
BRANCHES=(1)
TEST_CMD='oha --version | grep -q "^oha [0-9]"
oha --help | grep -q "HTTP load generator"'

prepare() {
  # Static binaries. The faster -pgo build exists for amd64 only, so both
  # architectures use the plain build. No checksum file is published.
  local file=oha-linux-$2
  download "https://github.com/$UPSTREAM/releases/download/v$1/$file" "dl/$file"
  verify_sha256 "dl/$file" "$(gh_asset_sha256 "$UPSTREAM" "v$1" "$file")"
  check_glibc "dl/$file"
  install -Dm755 "dl/$file" oha
  download "https://raw.githubusercontent.com/$UPSTREAM/v$1/LICENSE" LICENSE
  download "https://raw.githubusercontent.com/$UPSTREAM/v$1/README.md" README.md
}
