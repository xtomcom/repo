# shellcheck shell=bash
# Official Go toolchain from go.dev, laid out like the distributions' own
# golang packages so it upgrades them in place:
#   deb: GOROOT /usr/lib/go-1.NN, /usr/lib/go and /usr/share/go symlinks,
#        /usr/bin/{go,gofmt} -> ../lib/go-1.NN/bin/* (Debian golang-go/golang-1.NN-go)
#   rpm: GOROOT /usr/lib/golang, /usr/bin/{go,gofmt} via alternatives (Fedora/RHEL golang-bin)
# Both formats use epoch 2 (Debian's golang-defaults epoch; RHEL has none) so
# we sort above the distribution packages.
BRANCHES=(1.27 1.26)
TEST_CMD='
  v=$(basename "$PKG" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
  go version | grep -F "go version go$v linux/"
  test "$(go env GOROOT)" = "$(readlink -f /usr/bin/go | sed "s|/bin/go$||")"
  mkdir -p /tmp/hello && cd /tmp/hello
  printf "package main\n\nimport \"fmt\"\n\nfunc main() { fmt.Println(\"hello from\", \"go\") }\n" > main.go
  gofmt -d main.go
  go run main.go | grep -Fx "hello from go"
'

godl_json() { curl -fsSL --retry 3 "https://go.dev/dl/?mode=json${1-}"; }

versions() {
  godl_json | jq -r '.[] | select(.stable) | .version | sub("^go"; "")'
}

prepare() {
  local version=$1 file sum
  file=go$version.linux-$2.tar.gz
  sum=$(godl_json "&include=all" | jq -r --arg f "$file" '.[].files[] | select(.filename == $f) | .sha256')
  [[ -n $sum ]] || die "no checksum for $file on go.dev"
  download "https://go.dev/dl/$file" "dl/$file"
  verify_sha256 "dl/$file" "$sum"
  tar -xzf "dl/$file"
  [[ $(head -n1 go/VERSION) == "go$version" ]] || die "unexpected go/VERSION"
  # GOROOT and symlink targets on Debian carry the major version (go-1.NN).
  sed -i "s/@MAJOR@/${version%.*}/g" nfpm.yaml
}
