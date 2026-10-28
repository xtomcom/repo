#!/bin/sh
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers ferron.conf
elif ! getent passwd ferron >/dev/null; then
  useradd -rU -d /var/lib/ferron -s /usr/sbin/nologin -c "Ferron web server" ferron
fi
# Layout of upstream's deb/rpm: state (ACME) in /var/lib/ferron, logs in
# /var/log/ferron, and a default webroot only if /var/www/ferron is missing.
for d in /var/lib/ferron /var/log/ferron; do
  [ -d "$d" ] || install -d -m 0755 -o ferron -g ferron "$d"
done
if [ ! -e /var/www/ferron ]; then
  mkdir -p /var/www
  cp -r /usr/share/ferron/wwwroot /var/www/ferron
  chown -R ferron:ferron /var/www/ferron
fi
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
Ferron is installed but not started. To start it:
  1. Edit /etc/ferron.kdl (the default serves /var/www/ferron on port 80)
  2. systemctl enable --now ferron
EOF
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl try-restart ferron.service || true
fi
