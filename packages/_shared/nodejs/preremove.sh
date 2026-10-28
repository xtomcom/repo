#!/bin/sh
# deb prerm and rpm preun: leave the "node" alternatives group on removal,
# not on upgrade. deb passes remove/deconfigure/upgrade/failed-upgrade; rpm
# passes the number of versions left (0 on erase).
set -e
case "$1" in
  remove | deconfigure | 0)
    update-alternatives --remove node /usr/lib/nodejs-@MAJOR@/bin/node
    ;;
esac
