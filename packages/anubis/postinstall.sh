#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
Anubis is installed but not started. To run an instance named NAME:
  1. cp /etc/anubis/default.env /etc/anubis/NAME.env and edit it
  2. systemctl enable --now anubis@NAME
EOF
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart 'anubis@*.service' >/dev/null 2>&1 || :
fi
exit 0
