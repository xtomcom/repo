#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers frp.conf
elif ! getent passwd frp >/dev/null; then
  useradd -rU -d / -s /usr/sbin/nologin -c "frp reverse proxy" frp
fi
# On a fresh install, let the services read their configuration and say how to
# start them (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  chgrp frp /etc/frp/frps.toml /etc/frp/frpc.toml
  cat <<'EOT'
frp is installed but not started. To start it:
  Server: edit /etc/frp/frps.toml, then systemctl enable --now frps
  Client: edit /etc/frp/frpc.toml, then systemctl enable --now frpc
EOT
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart frps.service frpc.service >/dev/null 2>&1 || :
fi
exit 0
