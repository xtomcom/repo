#!/bin/sh
# deb: "remove"; rpm: 0 = removal (not upgrade).
[ -d /run/systemd/system ] || exit 0
if [ "$1" = remove ] || [ "$1" = 0 ]; then
  systemctl stop 'anubis@*.service' >/dev/null 2>&1 || :
fi
exit 0
