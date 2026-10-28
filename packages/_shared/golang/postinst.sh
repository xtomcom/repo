#!/bin/sh
set -e
# Register this version for go, gofmt and the GOROOT links Debian's golang-go
# and golang-src ship (/usr/lib/go, /usr/share/go). The newest version has the
# highest priority; a choice made with update-alternatives --set is kept.
if [ "$1" = configure ] || [ "$1" = abort-upgrade ] || [ "$1" = abort-remove ] || [ "$1" = abort-deconfigure ]; then
  update-alternatives --install /usr/bin/go go /usr/lib/go-@BRANCH@/bin/go @PRIORITY@ \
    --slave /usr/bin/gofmt gofmt /usr/lib/go-@BRANCH@/bin/gofmt \
    --slave /usr/lib/go golang-lib /usr/lib/go-@BRANCH@ \
    --slave /usr/share/go golang-share /usr/share/go-@BRANCH@
fi
