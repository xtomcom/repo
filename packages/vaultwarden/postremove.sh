#!/bin/sh
# /var/lib/vaultwarden, the vaultwarden user and (on rpm) a changed env file
# are kept, also on purge: they hold the vault and its secrets.
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
