#!/bin/sh
# deb: "configure [old-version]"; rpm: 1 = install, 2 = upgrade.
if command -v systemd-sysusers >/dev/null 2>&1; then
  systemd-sysusers yuki.conf
elif ! getent passwd mirror >/dev/null; then
  useradd --system --user-group --no-create-home --home-dir / \
    --shell /usr/sbin/nologin --comment "Yuki mirror sync user" mirror
fi
# yukid runs its sync jobs through Docker as the mirror user.
if getent group docker >/dev/null; then usermod -aG docker mirror; fi

# On a fresh install, say how to start the service (deb: no old version; rpm: 1).
if [ "$1" = 1 ] || { [ "$1" = configure ] && [ -z "$2" ]; }; then
  cat <<'EOF'
Yuki is installed but not started. To start it:
  1. cp /etc/yuki/daemon.example.toml /etc/yuki/daemon.toml and edit it;
     put repository configs (*.yaml) in /etc/yuki/repos
  2. systemctl enable --now yukid
EOF
  getent group docker >/dev/null ||
    echo "Docker is not installed. After installing it, run: usermod -aG docker mirror"
fi
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload >/dev/null 2>&1 || :
if [ -n "$2" ] || [ "$1" = 2 ]; then
  systemctl try-restart yukid.service >/dev/null 2>&1 || :
fi
exit 0
