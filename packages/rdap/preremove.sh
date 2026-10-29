#!/bin/sh
# deb: "remove"; rpm: 0 = removal (not upgrade). Stop and disable, so no
# enablement links to the removed unit files are left behind.
if [ "$1" = remove ] || [ "$1" = 0 ]; then
  if [ -d /run/systemd/system ]; then
    systemctl stop rdap.service >/dev/null 2>&1 || :
  fi
  systemctl disable rdap.service >/dev/null 2>&1 || :
fi
exit 0
