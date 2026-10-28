#!/bin/sh
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload >/dev/null 2>&1 || :
fi
# deb purge: Debian's (upstream's) postrm removes the user, its data
# (certificates and keys), the logs and /etc/caddy.
if [ "$1" = purge ]; then
  userdel caddy >/dev/null 2>&1 || :
  rm -rf /var/lib/caddy /var/log/caddy /etc/caddy
fi
exit 0
