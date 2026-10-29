#!/bin/sh
set -e
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers forgejo-runner.conf
elif ! getent passwd runner >/dev/null; then
  useradd -rU -d /home/runner -s /bin/bash -c "Forgejo Runner" runner
fi
home=$(getent passwd runner | cut -d: -f6)
[ -d "$home" ] || install -d -m 0750 -o runner -g runner "$home"
# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOT'
Forgejo Runner is installed but not started. To start it:
  1. As runner in /home/runner: forgejo-runner generate-config > runner-config.yml
  2. Add the runner's url, uuid and token from Forgejo to server.connections
  3. To run jobs in Docker: usermod -aG docker runner
  4. systemctl enable --now forgejo-runner
EOT
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
  systemctl try-restart forgejo-runner.service || true
fi
