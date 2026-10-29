#!/bin/sh
# deb: "remove" or "purge"; rpm: 0 = removal. Not on upgrade, which runs after
# the new package's postinstall on rpm.
case $1 in
remove | purge | 0)
  rm -f /usr/local/etc/cloudflared/.installedFromPackageManager
  rmdir /usr/local/etc/cloudflared 2>/dev/null || :
  ;;
esac
exit 0
