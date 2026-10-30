#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers rathole.conf
elif ! getent passwd rathole >/dev/null; then
  useradd -rU -d / -s /usr/sbin/nologin -c "rathole reverse proxy" rathole
fi
# On a fresh install, let the services read their configuration and say how to
# start them (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  chgrp rathole /etc/rathole/server.toml /etc/rathole/client.toml
  cat <<'EOT'
rathole is installed but not started. To start it:
  Server: edit /etc/rathole/server.toml, then systemctl enable --now rathole-server
  Client: edit /etc/rathole/client.toml, then systemctl enable --now rathole-client
EOT
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart rathole-server.service rathole-client.service >/dev/null 2>&1 || :
fi
exit 0
