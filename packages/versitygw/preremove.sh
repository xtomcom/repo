#!/bin/sh
# deb: "remove"; rpm: 0 = removal (not upgrade). Stop and disable every
# instance, so no enablement links to the removed template are left behind.
if [ "$1" = remove ] || [ "$1" = 0 ]; then
  if [ -d /run/systemd/system ]; then
    systemctl stop 'versitygw@*.service' >/dev/null 2>&1 || :
  fi
  for link in /etc/systemd/system/*.wants/versitygw@*.service; do
    [ -L "$link" ] && systemctl disable "${link##*/}" >/dev/null 2>&1 || :
  done
fi
exit 0
