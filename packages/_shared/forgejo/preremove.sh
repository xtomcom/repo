#!/bin/sh
# deb: "remove"; rpm: 0 = erase (not upgrade).
case "$1" in
  remove | 0)
    if [ -d /run/systemd/system ]; then
      systemctl stop forgejo.service || true
    fi
    systemctl disable forgejo.service >/dev/null 2>&1 || true
    ;;
esac
