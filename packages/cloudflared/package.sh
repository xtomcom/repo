# shellcheck shell=bash
UPSTREAM=cloudflare/cloudflared
# Calendar versions (2026.10.6): carry the current year. A new year's first
# release replaces the last one of the old year; until it is out, the old one
# stays published.
BRANCHES=("$(date -u +%Y)")
TEST_CMD='
cloudflared --version | grep -q "^cloudflared version 20"
# The marker turns off self-update; updates come from the package manager.
test -f /usr/local/etc/cloudflared/.installedFromPackageManager
cloudflared update 2>&1 | grep -q "Please update using the same method"
if command -v dpkg >/dev/null; then dpkg -L cloudflared; else rpm -ql cloudflared; fi | grep -q /usr/share/man/man1/cloudflared.1.gz
'

prepare() {
  # Tags carry no "v". Checksums are only in the release notes.
  local file=cloudflared-linux-$2 raw=https://raw.githubusercontent.com/$UPSTREAM/$1
  download "https://github.com/$UPSTREAM/releases/download/$1/$file" "dl/$file"
  verify_sha256 "dl/$file" "$(gh_asset_sha256 "$UPSTREAM" "$1" "$file")"
  check_glibc "dl/$file"
  install -Dm755 "dl/$file" cloudflared
  download "$raw/LICENSE" LICENSE
  # The man page upstream's deb and rpm ship, from the same template.
  download "$raw/cloudflared_man_template" cloudflared.1
  sed -i -e "s/\${VERSION}/$1/" -e "s/\${DATE}/$(date -u +%F)/" cloudflared.1
  gzip -9n cloudflared.1
}
