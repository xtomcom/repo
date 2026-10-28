# shellcheck shell=bash
UPSTREAM=goreleaser/nfpm
BRANCHES=(2)
TEST_CMD='nfpm --version | grep -q "GitVersion"
test -f /usr/share/bash-completion/completions/nfpm
test -f /usr/share/zsh/site-functions/_nfpm
test -f /usr/share/fish/vendor_completions.d/nfpm.fish
if command -v dpkg >/dev/null; then dpkg -L nfpm; else rpm -ql nfpm; fi | grep -q /usr/share/man/man1/nfpm.1.gz'

prepare() {
  local base=https://github.com/$UPSTREAM/releases/download/v$1 file
  # The tarballs use x86_64 / arm64.
  file=nfpm_$1_Linux_$(case $2 in amd64) echo x86_64 ;; arm64) echo arm64 ;; esac).tar.gz
  download "$base/checksums.txt" dl/checksums.txt
  download "$base/$file" "dl/$file"
  verify_sums dl/checksums.txt "dl/$file"
  tar -xzf "dl/$file" nfpm LICENSE.md README.md completions manpages
}
