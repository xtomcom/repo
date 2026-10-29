#!/bin/sh
# As upstream's own packages do: cloudflared does not update itself (nor lets
# "cloudflared update" or the timer from "cloudflared service install" replace
# /usr/bin/cloudflared) when this marker exists.
mkdir -p /usr/local/etc/cloudflared
touch /usr/local/etc/cloudflared/.installedFromPackageManager
exit 0
