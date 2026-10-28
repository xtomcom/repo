#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
versitygw is installed but not started. To start a gateway named NAME:
  1. Copy /etc/versitygw.d/example.conf to /etc/versitygw.d/NAME.conf and set
     VGW_BACKEND_ARG, ROOT_ACCESS_KEY_ID and ROOT_SECRET_ACCESS_KEY
  2. systemctl enable --now versitygw@NAME
EOF
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart 'versitygw@*.service' >/dev/null 2>&1 || :
fi
exit 0
