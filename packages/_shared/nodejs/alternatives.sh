#!/bin/sh
# deb postinst and rpm posttrans: register this Node.js line in the "node"
# alternatives group. The newest major has the highest priority, so it is the
# default unless the admin picked another with update-alternatives --set node.
# npm, npx and corepack point at the npm-NN wrappers, which always run under
# the matching node.
set -e
# NodeSource's nodejs makes /usr/bin/nodejs the master of its own group
# "nodejs" (-> /usr/bin/node) and only drops it on removal, not when our
# nodejs replaces it as an upgrade. Ours has nodejs as a slave of node.
update-alternatives --remove nodejs /usr/bin/node >/dev/null 2>&1 || true
dir=/usr/lib/nodejs-@MAJOR@
# Node.js 25 and later no longer ship corepack.
corepack=
if [ -e /usr/bin/corepack-@MAJOR@ ]; then
  corepack="--slave /usr/bin/corepack corepack /usr/bin/corepack-@MAJOR@"
fi
# shellcheck disable=SC2086 # $corepack is several words or none
update-alternatives --install /usr/bin/node node $dir/bin/node @PRIORITY@ \
  --slave /usr/bin/nodejs nodejs $dir/bin/node \
  --slave /usr/bin/npm npm /usr/bin/npm-@MAJOR@ \
  --slave /usr/bin/npx npx /usr/bin/npx-@MAJOR@ \
  $corepack \
  --slave /usr/share/man/man1/node.1.gz node.1.gz $dir/share/man/man1/node.1.gz
