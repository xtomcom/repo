# shellcheck shell=bash
UPSTREAM=fastfetch-cli/fastfetch
BRANCHES=(2)
TEST_CMD='fastfetch --version | grep -q "^fastfetch [0-9]"
fastfetch --pipe --logo none --structure OS:Kernel | grep -q "^OS: "
flashfetch >/dev/null
test -f /usr/share/fastfetch/presets/neofetch.jsonc
test -f /usr/share/bash-completion/completions/fastfetch
if command -v dpkg >/dev/null; then dpkg -L fastfetch; else rpm -ql fastfetch; fi | grep -q /usr/share/man/man1/fastfetch.1.gz'

prepare() {
  # The plain build needs glibc 2.34 (EL9's); the -polyfilled one exists for
  # older systems. Tags carry no "v". No checksum file is published.
  local file
  file=fastfetch-linux-$(case $2 in amd64) echo amd64 ;; arm64) echo aarch64 ;; esac).tar.gz
  download "https://github.com/$UPSTREAM/releases/download/$1/$file" "dl/$file"
  verify_sha256 "dl/$file" "$(gh_asset_sha256 "$UPSTREAM" "$1" "$file")"
  tar -xzf "dl/$file" --strip-components=1
  check_glibc usr/bin/fastfetch usr/bin/flashfetch
  gzip -9n usr/share/man/man1/fastfetch.1
}
