#!/bin/sh
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers gitea.conf
elif ! getent passwd git >/dev/null; then
  useradd -rU -d /home/git -s /bin/bash -c "Git Version Control" git
fi
# Layout from https://docs.gitea.com/installation/install-from-binary; only
# created when missing so later admin changes (e.g. chmod 750 /etc/gitea) stick.
home=$(getent passwd git | cut -d: -f6)
[ -d "$home" ] || install -d -m 0750 -o git -g git "$home"
for d in /var/lib/gitea /var/lib/gitea/custom /var/lib/gitea/data /var/lib/gitea/log; do
  [ -d "$d" ] || install -d -m 0750 -o git -g git "$d"
done
[ -d /etc/gitea ] || install -d -m 0770 -o root -g git /etc/gitea
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
Gitea is installed but not started. To start it:
  1. systemctl enable --now gitea
  2. Open http://<this server>:3000 to finish the setup
EOF
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl try-restart gitea.service || true
fi
