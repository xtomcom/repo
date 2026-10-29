# shellcheck shell=bash
UPSTREAM=denoland/deno
BRANCHES=(2)
TEST_CMD='v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
deno --version | grep -qx "deno $v (stable, release, .*)"
test "$(deno eval "console.log(1+1)")" = 2
cd "$(mktemp -d)"
printf "const n: number = 6 * 7;\nconsole.log(Deno.version.deno, n);\n" >t.ts
test "$(deno run t.ts)" = "$v 42"
test -f /usr/share/bash-completion/completions/deno
test -f /usr/share/zsh/site-functions/_deno
test -f /usr/share/fish/vendor_completions.d/deno.fish'

# The zips use the Rust target triple.
deno_triple() { echo "$(rpm_arch "$1")-unknown-linux-gnu"; }

# fetch BASE ARCH: download, verify and unpack the zip for ARCH into dl/ARCH/.
fetch() {
  local file
  file=deno-$(deno_triple "$2").zip
  [[ -f dl/$file ]] && return 0
  download "$1/$file" "dl/$file"
  download "$1/$file.sha256sum" "dl/$file.sha256sum"
  verify_sums "dl/$file.sha256sum" "dl/$file"
  unzip -q "dl/$file" -d "dl/$2"
}

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/v$1 host s
  fetch "$base" "$2"
  check_glibc "dl/$2/deno"
  install -Dm755 "dl/$2/deno" deno
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE.md" LICENSE.md

  # Shell completions come from the binary itself; use one the build host can run.
  host=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
  fetch "$base" "$host"
  for s in bash zsh fish; do
    HOME=$PWD/dl DENO_DIR=$PWD/dl/deno-dir DENO_NO_UPDATE_CHECK=1 "dl/$host/deno" completions "$s" >"deno.$s"
  done
}
