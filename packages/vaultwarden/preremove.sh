#!/bin/sh
# deb: "remove"; rpm: 0 = erase (not upgrade).
case "$1" in
  remove | 0)
    if [ -d /run/systemd/system ]; then
      systemctl stop vaultwarden.service || true
    fi
    systemctl disable vaultwarden.service >/dev/null 2>&1 || true
    ;;
esac
