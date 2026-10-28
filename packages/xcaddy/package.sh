# shellcheck shell=bash
UPSTREAM=caddyserver/xcaddy
BRANCHES=(0)
TEST_CMD='
v=$(basename "$PKG" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
xcaddy version | grep "^v$v "
go version
test -f /usr/share/bash-completion/completions/xcaddy
test -f /usr/share/zsh/site-functions/_xcaddy
test -f /usr/share/fish/vendor_completions.d/xcaddy.fish
'

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/v$1 a file host
  download "$base/xcaddy_${version}_checksums.txt" dl/checksums.txt
  for a in "$2" "$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"; do
    file=xcaddy_${version}_linux_$a.tar.gz
    [[ -f dl/$file ]] && continue
    download "$base/$file" "dl/$file"
    verify_sums dl/checksums.txt "dl/$file"
    mkdir -p "dl/$a"
    tar -xzf "dl/$file" -C "dl/$a"
  done
  install -Dm755 "dl/$2/xcaddy" xcaddy
  cp "dl/$2/LICENSE" "dl/$2/README.md" .

  # Shell completions come from the binary itself; use one the build host can run.
  host=dl/$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')/xcaddy
  for a in bash zsh fish; do
    "$host" completion "$a" >"xcaddy.$a"
  done
}
