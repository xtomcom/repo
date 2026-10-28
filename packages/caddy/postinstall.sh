#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
set -e
# As Debian's postinst: caddy may read www-data's files, logs go to /var/log/caddy.
if getent group www-data >/dev/null; then
  usermod -aG www-data caddy
fi
[ -d /var/lib/caddy ] || install -d -m 0750 -o caddy -g caddy /var/lib/caddy
[ -d /var/log/caddy ] || install -d -o caddy -g caddy /var/log/caddy
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'MSG'
Caddy is installed but not started. To start it:
  1. Edit /etc/caddy/Caddyfile (the default serves /usr/share/caddy on port 80)
  2. systemctl enable --now caddy
To configure Caddy through its admin API instead, use caddy-api.service.
MSG
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart caddy.service caddy-api.service >/dev/null 2>&1 || :
fi
exit 0
