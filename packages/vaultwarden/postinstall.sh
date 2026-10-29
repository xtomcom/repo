#!/bin/sh
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers vaultwarden.conf
elif ! getent passwd vaultwarden >/dev/null; then
  useradd -rU -d /var/lib/vaultwarden -s /usr/sbin/nologin -c "Vaultwarden password manager" vaultwarden
fi
# The data folder (database, RSA keys, attachments). Not part of the package,
# so it survives removal and purge.
[ -d /var/lib/vaultwarden ] || install -d -m 0700 -o vaultwarden -g vaultwarden /var/lib/vaultwarden
# The env file holds secrets (ADMIN_TOKEN, SMTP and database passwords) and is
# shipped root:root 0640; let the service user read it. Only while it is still
# root's group, so an admin's own ownership survives upgrades.
env=/etc/vaultwarden/vaultwarden.env
if [ -f "$env" ] && [ "$(stat -c %G "$env")" = root ]; then
  chgrp vaultwarden "$env"
  chmod 0640 "$env"
fi
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOT'
Vaultwarden is installed but not started. To start it:
  1. Edit /etc/vaultwarden/vaultwarden.env (set DOMAIN and ADMIN_TOKEN; it listens
     on ROCKET_ADDRESS=127.0.0.1, ROCKET_PORT=8000 and keeps its data in
     DATA_FOLDER=/var/lib/vaultwarden)
  2. systemctl enable --now vaultwarden
Browsers only open the web vault over HTTPS: put a reverse proxy in front of it.
EOT
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl try-restart vaultwarden.service || true
fi
