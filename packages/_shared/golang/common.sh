# shellcheck shell=bash
# Shared by packages/golang (the metapackage) and packages/golang-1.NN (one
# co-installable Go minor version each). See packages/golang/README.md.
#
# Each golang-1.NN package.sh sets BRANCHES=(1.NN) and sources this file; the
# metapackage sources it and follows GO_LATEST.

# Our supported minor versions are the packages/golang-1.NN directories; the
# newest one is what the golang metapackage installs.
GO_LATEST=$(cd "$PKG_DIR/.." && printf '%s\n' golang-[0-9]*.[0-9]* | sed 's/^golang-//' | sort -V | tail -n1)

# The single golang package that carried the whole toolchain before the split
# was published up to 2:1.27.3-1. golang-1.NN takes over its files and must not
# be configured while it is still installed.
GO_SPLIT=2:1.27.3-2~

godl_json() { curl -fsSL --retry 3 "https://go.dev/dl/?mode=json${1-}"; }

# Older minor versions ignore newer releases; only the newest one and the
# metapackage warn (in check.sh) when a new minor version comes out.
versions() {
  local v
  godl_json | jq -r '.[] | select(.stable) | .version | sub("^go"; "")' | while read -r v; do
    [[ ${BRANCHES[0]} != "$GO_LATEST" && $(printf '%s\n' "${v%.*}" "${BRANCHES[0]}" | sort -V | tail -n1) != "${BRANCHES[0]}" ]] ||
      echo "$v"
  done
}

# go_fetch VERSION ARCH: download, verify and unpack the official tarball to ./go.
go_fetch() {
  local version=$1 file sum
  file=go$version.linux-$2.tar.gz
  sum=$(godl_json "&include=all" | jq -r --arg f "$file" '.[].files[] | select(.filename == $f) | .sha256')
  [[ -n $sum ]] || die "no checksum for $file on go.dev"
  download "https://go.dev/dl/$file" "dl/$file"
  verify_sha256 "dl/$file" "$sum"
  tar -xzf "dl/$file"
  [[ $(head -n1 go/VERSION) == "go$version" ]] || die "unexpected go/VERSION"
}

# go_subst BRANCH FILE...: fill in the @...@ placeholders of the staged copies.
# Alternatives priority: 1.27 -> 127, so the newest version is the default.
go_subst() {
  local branch=$1 priority
  shift
  priority=$((${branch%%.*} * 100 + ${branch#*.}))
  sed -i -e "s/@BRANCH@/$branch/g" -e "s/@PRIORITY@/$priority/g" \
    -e "s/@LATEST@/$GO_LATEST/g" -e "s/@SPLIT@/$GO_SPLIT/g" "$@"
}

# Run in clean containers after installing golang-1.NN or the metapackage:
# the plain and the versioned commands both run the version in the file name.
TEST_CMD='
v=$(basename "$PKG" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
b=${v%.*}
mkdir -p /tmp/hello && cd /tmp/hello
printf "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"hello from\", \"go\")\n}\n" > main.go
for g in go "go-$b"; do
  "$g" version | grep -F "go version go$v linux/"
  test "$("$g" env GOROOT)" = "/usr/lib/go-$b"
  "$g" run main.go | grep -Fx "hello from go"
done
for f in gofmt "gofmt-$b"; do
  "$f" -l main.go
  test -z "$("$f" -l main.go)"
done
test "$(readlink -f /usr/bin/go)" = "/usr/lib/go-$b/bin/go"
test "$(readlink -f /usr/lib/go)" = "/usr/lib/go-$b"
if command -v dpkg >/dev/null; then test "$(readlink -f /usr/share/go)" = "/usr/lib/go-$b"; fi
'

prepare() {
  go_fetch "$1" "$2"
  go_subst "${BRANCHES[0]}" nfpm.yaml ./*.sh
}
