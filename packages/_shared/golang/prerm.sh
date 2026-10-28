#!/bin/sh
set -e
# Not on upgrade, which would forget a manual choice of this version.
if [ "$1" = remove ] || [ "$1" = deconfigure ]; then
  update-alternatives --remove go /usr/lib/go-@BRANCH@/bin/go
fi
