#!/bin/sh
# deb postrm and rpm postun: drop the AppArmor profile postinstall.sh copied,
# on removal only (deb: remove/purge; rpm: 0 versions left).
set -e
case "$1" in
  remove | purge | 0) ;;
  *) exit 0 ;;
esac
profile=/etc/apparmor.d/ai.opencode
[ -f $profile ] || exit 0
if apparmor_status --enabled >/dev/null 2>&1 && ! { [ -x /usr/bin/ischroot ] && /usr/bin/ischroot; }; then
  apparmor_parser --remove $profile || true
fi
rm -f $profile
