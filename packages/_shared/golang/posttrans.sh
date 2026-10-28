#!/bin/sh
# The single golang package used before golang-1.NN registered
# /usr/lib/golang/bin/go and removes it only on erase, not when it is upgraded
# to the metapackage: drop that entry once its file is gone. Fedora's own
# golang-bin registers the same path, so keep it while the file exists.
if [ ! -e /usr/lib/golang/bin/go ]; then
  /usr/sbin/update-alternatives --remove go /usr/lib/golang/bin/go >/dev/null 2>&1 || :
fi
# The newest version has the highest priority; a choice made with
# alternatives --set is kept.
/usr/sbin/update-alternatives --install /usr/bin/go go /usr/lib/go-@BRANCH@/bin/go @PRIORITY@ \
  --slave /usr/bin/gofmt gofmt /usr/lib/go-@BRANCH@/bin/gofmt \
  --slave /usr/lib/go golang-lib /usr/lib/go-@BRANCH@
