#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOT'
gobackup is installed but not started. To start it:
  1. Add your backups (models) to /etc/gobackup/gobackup.yml
  2. systemctl enable --now gobackup
EOT
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart gobackup.service >/dev/null 2>&1 || :
fi
exit 0
