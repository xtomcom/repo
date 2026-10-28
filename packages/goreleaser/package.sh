# shellcheck shell=bash
UPSTREAM=goreleaser/goreleaser
BRANCHES=(2)
TEST_CMD='goreleaser --version | grep -q "GitVersion"
git --version
test -f /usr/share/bash-completion/completions/goreleaser
test -f /usr/share/zsh/site-functions/_goreleaser
test -f /usr/share/fish/vendor_completions.d/goreleaser.fish
if command -v dpkg >/dev/null; then dpkg -L goreleaser; else rpm -ql goreleaser; fi | grep -q /usr/share/man/man1/goreleaser.1.gz'

prepare() {
  local base=https://github.com/$UPSTREAM/releases/download/v$1 file
  # The tarballs carry no version (only the tag does) and use x86_64 / arm64.
  file=goreleaser_Linux_$(case $2 in amd64) echo x86_64 ;; arm64) echo arm64 ;; esac).tar.gz
  download "$base/checksums.txt" dl/checksums.txt
  download "$base/$file" "dl/$file"
  verify_sums dl/checksums.txt "dl/$file"
  tar -xzf "dl/$file" goreleaser LICENSE.md README.md completions manpages
}
