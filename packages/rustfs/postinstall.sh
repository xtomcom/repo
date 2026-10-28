#!/bin/sh
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers rustfs.conf
elif ! getent passwd rustfs >/dev/null; then
  useradd -rU -d /opt/rustfs -s /usr/sbin/nologin -c "RustFS object storage" rustfs
fi
# Layout of upstream's deb/rpm; the unit needs these to exist before it starts.
for d in /opt/rustfs /data/rustfs /var/log/rustfs; do
  [ -d "$d" ] || install -d -m 0750 -o rustfs -g rustfs "$d"
done
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
RustFS is installed but not started. To start it:
  1. Edit /etc/default/rustfs (set RUSTFS_VOLUMES, RUSTFS_ACCESS_KEY and RUSTFS_SECRET_KEY)
  2. systemctl enable --now rustfs
EOF
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl try-restart rustfs.service || true
fi
