#!/bin/sh
# deb: "remove"; rpm: 0 = erase (not upgrade).
case "$1" in
  remove | 0)
    if [ -d /run/systemd/system ]; then
      systemctl stop gitea.service || true
    fi
    systemctl disable gitea.service >/dev/null 2>&1 || true
    ;;
esac
