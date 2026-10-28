# shellcheck shell=bash
# The nodejs metapackage: no files, depends on the newest LTS line
# (nodejs-$NODE_LTS) and follows its version. When a newer line becomes LTS,
# NODE_LTS in packages/_shared/nodejs/common.sh moves to it; check.sh warns
# about that ("newer than BRANCHES"), since versions() lists every LTS line.
# shellcheck source=../_shared/nodejs/common.sh
source "$PKG_DIR/../_shared/nodejs/common.sh"
# test.sh builds and installs these along, as no repository has them there.
TEST_DEPS=("nodejs-$NODE_LTS")
TEST_CMD='
v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
test "$(node -v)" = "v$v"
npm -v
if command -v dpkg >/dev/null; then
  dpkg-query -W -f="\${Depends}\n" nodejs | grep -qx "nodejs-${v%%.*}"
  dpkg-query -W -f="\${Provides}\n" nodejs | grep -q "nodejs-lts"
else
  rpm -q --requires nodejs | grep -qx "nodejs-${v%%.*}"
  rpm -q --whatprovides nodejs-lts | grep -q "^nodejs-${v}-"
fi
'

prepare() {
  [[ ${1%%.*} == "$NODE_LTS" ]] || die "$1 is not a Node.js $NODE_LTS release"
  sed -i "s/@MAJOR@/$NODE_LTS/g" nfpm.yaml
}
