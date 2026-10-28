# shellcheck shell=bash
# golang: metapackage that installs the newest Go minor version we carry
# (golang-1.NN, the newest packages/golang-1.NN directory) and stands in for
# the distributions' golang, golang-go and golang-bin. It has no files; its
# version is that of the Go release it depends on. See README.md.
# shellcheck source=../_shared/golang/common.sh
source "$PKG_DIR/../_shared/golang/common.sh"
BRANCHES=("$GO_LATEST")
TEST_DEPS=("golang-$GO_LATEST")
# The single golang package with the whole toolchain was published as
# 2:1.27.3-1; this release turns it into the metapackage.
RELEASE=2

prepare() {
  godl_json "&include=all" | jq -e --arg v "go$1" 'any(.[]; .version == $v and .stable)' >/dev/null ||
    die "go$1 is not a stable release on go.dev"
  [[ ${1%.*} == "$GO_LATEST" ]] || die "golang follows Go $GO_LATEST, not $1"
  go_subst "$GO_LATEST" nfpm.yaml
}
