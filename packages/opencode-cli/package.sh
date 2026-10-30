# shellcheck shell=bash
# shellcheck source=../_shared/opencode/common.sh
source "$PKG_DIR/../_shared/opencode/common.sh"
TEST_CMD='v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
test "$(opencode --version </dev/null)" = "opencode v$v"
opencode --help </dev/null | grep -q "^  opencode <subcommand>"
opencode run --help </dev/null | grep -q "Run OpenCode with a message"
test -f /usr/share/bash-completion/completions/opencode
test -f /usr/share/zsh/site-functions/_opencode
test -f /usr/share/fish/vendor_completions.d/opencode.fish
grep -q "^#compdef opencode" /usr/share/zsh/site-functions/_opencode
# opencode upgrade finds no installation method it knows for /usr/bin and
# changes nothing.
if out=$(opencode upgrade </dev/null 2>&1); then echo "opencode upgrade succeeded: $out"; exit 1; fi
echo "$out" | grep -q "Could not detect the installation method"
test ! -e /root/.opencode
# Login shells get the update check turned off, unless set otherwise.
test "$(bash -lc "echo \$OPENCODE_DISABLE_AUTOUPDATE")" = 1
test "$(OPENCODE_DISABLE_AUTOUPDATE=0 bash -lc "echo \$OPENCODE_DISABLE_AUTOUPDATE")" = 0'

# The tarballs use x64 / arm64. On amd64 we take x64-baseline, which the
# installer (opencode.ai/v2/install) picks on CPUs without AVX2 and which runs
# on any x86-64 CPU. Up to 2.2.1 it was the same file as x64; since 2.2.2 the
# two differ in one flag byte of the embedded Bun trailer, not in code.
opencode_arch() { case $1 in amd64) echo x64-baseline ;; arm64) echo arm64 ;; *) die "unknown arch $1" ;; esac; }

# fetch VERSION NAME: download, verify and unpack opencode-linux-NAME.tar.gz into dl/NAME.
fetch() {
  [[ -d dl/$2 ]] && return 0
  fetch_asset "$1" "opencode-linux-$2.tar.gz"
  mkdir -p "dl/$2"
  tar -xzf "dl/opencode-linux-$2.tar.gz" -C "dl/$2"
  [[ -f dl/$2/opencode ]] || die "opencode-linux-$2.tar.gz has no opencode binary"
}

prepare() {
  local version=$1 name host s
  name=$(opencode_arch "$2")
  fetch "$version" "$name"
  check_glibc "dl/$name/opencode"
  install -Dm755 "dl/$name/opencode" opencode
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE" LICENSE

  # Shell completions come from the binary itself; use one the build host can run.
  host=$(opencode_arch "$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')")
  fetch "$version" "$host"
  for s in bash zsh fish; do
    HOME=$PWD/dl/home "dl/$host/opencode" --completions "$s" </dev/null >"opencode.$s"
    [[ -s opencode.$s ]] || die "opencode --completions printed nothing for $s"
  done
}
