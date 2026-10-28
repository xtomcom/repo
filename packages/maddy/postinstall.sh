#!/bin/sh
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers maddy.conf
elif ! getent passwd maddy >/dev/null; then
  useradd -rU -d /var/lib/maddy -s /usr/sbin/nologin -c "maddy mail server" maddy
fi
# StateDirectory= creates it too, but `maddy creds` etc. need it before first start.
[ -d /var/lib/maddy ] || install -d -o maddy -g maddy /var/lib/maddy
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
maddy is installed but not started. To start it:
  1. Edit /etc/maddy/maddy.conf (hostname, primary_domain, TLS certificates)
  2. systemctl enable --now maddy
EOF
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl try-restart maddy.service 'maddy@*.service' || true
fi
