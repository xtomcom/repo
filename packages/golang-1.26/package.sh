# shellcheck shell=bash
# Go 1.26 from go.dev in /usr/lib/go-1.26, co-installable with the other
# golang-1.NN packages. Everything but the branch is shared with them, see
# packages/golang/README.md.
BRANCHES=(1.26)
# shellcheck source=../_shared/golang/common.sh
source "$PKG_DIR/../_shared/golang/common.sh"
