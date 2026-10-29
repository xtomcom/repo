# shellcheck shell=bash
UPSTREAM=oven-sh/bun
BRANCHES=(1)
# robobun.asc is the release signing key that upstream inlines in its own
# Docker images (dockerhub/*/Dockerfile, gpg --assert-signer).
BUN_KEY=F3DCC08A8572C0749B3E18888EAB4D40A7B22B59
TEST_CMD='v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
test "$(bun --version)" = "$v"
test "$(readlink /usr/bin/bunx)" = bun
test "$(bunx --version)" = "$v"
test "$(bun -e "console.log(1+1)")" = 2
cd "$(mktemp -d)"
printf "const n: number = 6 * 7;\nconsole.log(Bun.version, n);\n" >t.ts
test "$(bun t.ts)" = "$v 42"
test -f /usr/share/bash-completion/completions/bun
test -f /usr/share/zsh/site-functions/_bun
test -f /usr/share/fish/vendor_completions.d/bun.fish'

# Tags are "bun-vX.Y.Z" (gh_versions only strips a "v").
versions() {
  gh api "repos/$UPSTREAM/releases?per_page=100" \
    --jq '.[] | select(.draft | not) | select(.prerelease | not) | .tag_name
      | select(test("^bun-v[0-9]+\\.[0-9]+\\.[0-9]+$")) | sub("^bun-v"; "")'
}

# The zips use x64 / aarch64.
bun_arch() { case $1 in amd64) echo x64 ;; arm64) echo aarch64 ;; *) die "unknown arch $1" ;; esac; }

# fetch BASE NAME: download, verify and unpack bun-linux-NAME.zip into dl/.
fetch() {
  [[ -d dl/bun-linux-$2 ]] && return 0
  download "$1/bun-linux-$2.zip" "dl/bun-linux-$2.zip"
  verify_sums dl/SHASUMS256.txt "dl/bun-linux-$2.zip"
  unzip -q "dl/bun-linux-$2.zip" -d dl
}

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/bun-v$1 gnupg fpr name host s
  # SHASUMS256.txt.asc is clearsigned: check it against the pinned key and only
  # trust the checksums inside the signed body.
  download "$base/SHASUMS256.txt.asc" dl/SHASUMS256.txt.asc
  gnupg=$(mktemp -d)
  gpg --homedir "$gnupg" -q --import robobun.asc 2>/dev/null
  fpr=$(gpg --homedir "$gnupg" --status-fd 1 -q -o dl/SHASUMS256.txt --decrypt dl/SHASUMS256.txt.asc 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }')
  rm -rf "$gnupg"
  [[ $fpr == "$BUN_KEY" ]] || die "bad signature on SHASUMS256.txt"

  name=$(bun_arch "$2")
  fetch "$base" "$name"
  if [[ $2 == amd64 ]]; then
    # The installer (bun.sh/install) picks x64-baseline on CPUs without AVX2,
    # but current releases ship the same binary under both names (one build
    # for every x86-64 CPU), so we package bun-linux-x64. Fail if that ever
    # changes, so a human decides how to handle two builds.
    fetch "$base" x64-baseline
    s=$(sha256sum dl/bun-linux-x64/bun dl/bun-linux-x64-baseline/bun | awk '{ print $1 }' | sort -u | wc -l)
    [[ $s -eq 1 ]] || die "bun-linux-x64 and bun-linux-x64-baseline differ in $version; decide which to package"
  fi
  check_glibc "dl/bun-linux-$name/bun"
  install -Dm755 "dl/bun-linux-$name/bun" bun
  download "https://raw.githubusercontent.com/$UPSTREAM/bun-v$version/LICENSE.md" LICENSE.md

  # Shell completions come from the binary itself; use one the build host can
  # run. With stdout not a terminal, `bun completions` prints the script for
  # the shell named in $SHELL instead of installing it.
  host=$(bun_arch "$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')")
  fetch "$base" "$host"
  for s in bash zsh fish; do
    HOME=$PWD/dl SHELL=/bin/$s "dl/bun-linux-$host/bun" completions >"bun.$s"
    [[ -s bun.$s ]] || die "bun completions printed nothing for $s"
  done
}
