# shellcheck shell=bash
UPSTREAM=sdotee/cli
BRANCHES=(1)
TEST_CMD='see version | grep -q "see-cli version"
test -f /usr/share/bash-completion/completions/see
test -f /usr/share/zsh/site-functions/_see
test -f /usr/share/fish/vendor_completions.d/see.fish'

# see_Linux_<arch>.tar.gz uses x86_64 / arm64.
see_arch() { case $1 in amd64) echo x86_64 ;; arm64) echo arm64 ;; *) die "unknown arch $1" ;; esac; }

prepare() {
  local base=https://github.com/$UPSTREAM/releases/download/v$1 a file host
  download "$base/checksums.txt" dl/checksums.txt
  for a in "$2" "$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"; do
    file=see_Linux_$(see_arch "$a").tar.gz
    [[ -f dl/$file ]] && continue
    download "$base/$file" "dl/$file"
    verify_sums dl/checksums.txt "dl/$file"
    mkdir -p "dl/$a"
    tar -xzf "dl/$file" -C "dl/$a"
  done
  install -Dm755 "dl/$2/see" see
  cp "dl/$2/LICENSE" "dl/$2/README.md" .

  # Shell completions come from the binary itself; use one the build host can run.
  # It refuses to start without an API key, even for completion, so pass a dummy.
  host=dl/$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')/see
  for a in bash zsh fish; do
    SEE_API_KEY=unused "$host" completion "$a" >"see.$a"
  done
}
