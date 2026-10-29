#!/bin/sh
# deb postinst and rpm posttrans. What upstream's own package does after
# installing: /usr/bin/ai.opencode through update-alternatives, chrome-sandbox
# setuid only where unprivileged user namespaces don't work, and the AppArmor
# profile on systems whose AppArmor supports it (Ubuntu 24.04 and later
# restrict user namespaces unless a profile allows them).
set -e
app=/opt/OpenCode
update-alternatives --install /usr/bin/ai.opencode ai.opencode $app/ai.opencode 100

if [ -L /proc/self/ns/user ] && unshare --user true 2>/dev/null; then
  chmod 0755 $app/chrome-sandbox
else
  chmod 4755 $app/chrome-sandbox
fi

if apparmor_status --enabled >/dev/null 2>&1 &&
  apparmor_parser --skip-kernel-load --debug $app/resources/apparmor-profile >/dev/null 2>&1; then
  cp -f $app/resources/apparmor-profile /etc/apparmor.d/ai.opencode
  if ! { [ -x /usr/bin/ischroot ] && /usr/bin/ischroot; }; then
    apparmor_parser --replace --write-cache --skip-read-cache /etc/apparmor.d/ai.opencode || true
  fi
fi
exit 0
