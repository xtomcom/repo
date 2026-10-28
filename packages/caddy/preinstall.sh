#!/bin/sh
# Create the caddy user before the files land (rpm owns /var/lib/caddy as
# caddy:caddy). Same entry as /usr/lib/sysusers.d/caddy.conf; without
# systemd-sysusers, the useradd call from Debian's (upstream's) postinst.
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  echo 'u caddy - "Caddy web server" /var/lib/caddy /sbin/nologin' |
    systemd-sysusers --replace=/usr/lib/sysusers.d/caddy.conf -
else
  getent group caddy >/dev/null || groupadd --system caddy
  getent passwd caddy >/dev/null ||
    useradd --system --gid caddy --no-create-home --home-dir /var/lib/caddy \
      --shell /usr/sbin/nologin --comment "Caddy web server" caddy
fi
