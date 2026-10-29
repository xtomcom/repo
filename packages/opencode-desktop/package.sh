# shellcheck shell=bash
# shellcheck source=../_shared/opencode/common.sh
source "$PKG_DIR/../_shared/opencode/common.sh"
# Installs the test tools, checks the files, then starts the app as a normal
# user for real: with Xvfb on Debian/Ubuntu, with Chromium's headless Ozone
# backend on EL (no Xvfb in EL10, not even in EPEL). --no-sandbox because a
# container has neither unprivileged user namespaces nor the privileges the
# setuid chrome-sandbox needs. Passes once the window is up, the bundled CLI
# runs as the background service and the updater has found nothing to do.
TEST_CMD='v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
if command -v apt-get >/dev/null; then
  apt-get install -y -qq xvfb xauth desktop-file-utils procps >/dev/null
  run="xvfb-run -a /opt/OpenCode/ai.opencode --no-sandbox"
else
  dnf install -y -q desktop-file-utils procps-ng >/dev/null
  run="/opt/OpenCode/ai.opencode --no-sandbox --ozone-platform=headless"
fi
test "$(readlink -f /usr/bin/ai.opencode)" = /opt/OpenCode/ai.opencode
test "$(readlink /usr/bin/ai.opencode)" = /etc/alternatives/ai.opencode
test ! -e /opt/OpenCode/resources/package-type
test "$(cat /opt/OpenCode/resources/opencode-cli.version)" = "$v"
test "$(/opt/OpenCode/resources/opencode-cli --version </dev/null)" = "opencode v$v"
# No user namespaces in a container, so chrome-sandbox is setuid as upstream does it.
test "$(stat -c %a /opt/OpenCode/chrome-sandbox)" = 4755
for f in /opt/OpenCode/ai.opencode /opt/OpenCode/*.so* /opt/OpenCode/chrome_crashpad_handler; do
  if ldd "$f" | grep "not found"; then exit 1; fi
done
desktop-file-validate /usr/share/applications/ai.opencode.desktop.desktop /usr/share/applications/opencode-desktop.desktop
test -f /usr/share/icons/hicolor/128x128/apps/ai.opencode.png
useradd -m octest
su octest -c "cd && $run >app.log 2>&1 &"
log=/home/octest/.config/ai.opencode.desktop/logs/*/main.log
ok=
for i in $(seq 90); do
  if grep -q "main window visible" $log 2>/dev/null &&
    grep -q "v2 CLI background service ready" $log &&
    grep -q "to: .up-to-date." $log; then ok=1; break; fi
  sleep 1
done
pkill -u octest || true
cat /home/octest/app.log >&2
cat $log >&2
test -n "$ok"
grep -q "APPIMAGE env is not defined" $log
if grep "Checking for update" $log; then exit 1; fi
sleep 2; pkill -9 -u octest || true; userdel -r octest 2>/dev/null || true'

# Upstream ships the desktop app for Linux only as .deb, .rpm and AppImage.
# We take the .deb apart and package its files ourselves.
desktop_asset() { echo "opencode-desktop-linux-$1.deb"; }

prepare() {
  local version=$1 deb root
  command -v dpkg-deb >/dev/null || die "dpkg-deb not found"
  deb=$(desktop_asset "$2")
  fetch_asset "$version" "$deb"
  [[ $(dpkg-deb -f "dl/$deb" Package) == opencode ]] || die "$deb is not upstream's opencode package"
  [[ $(dpkg-deb -f "dl/$deb" Version) == "$version" ]] || die "$deb has version $(dpkg-deb -f "dl/$deb" Version), not $version"
  [[ $(dpkg-deb -f "dl/$deb" Architecture) == "$2" ]] || die "$deb is not for $2"
  root=dl/root
  dpkg-deb -x "dl/$deb" "$root"
  [[ -x $root/opt/OpenCode/ai.opencode && -x $root/opt/OpenCode/resources/opencode-cli ]] ||
    die "$deb has no /opt/OpenCode/ai.opencode or resources/opencode-cli"
  [[ $(cat "$root/opt/OpenCode/resources/opencode-cli.version") == "$version" ]] ||
    die "$deb bundles CLI $(cat "$root/opt/OpenCode/resources/opencode-cli.version"), not $version"
  # electron-updater picks its updater from resources/package-type. With "deb"
  # or "rpm" it downloads upstream's package and installs it with pkexec,
  # replacing this one; without the file it uses the AppImage updater, which
  # does nothing outside an AppImage ($APPIMAGE unset).
  rm -f "$root/opt/OpenCode/resources/package-type"
  check_glibc "$root/opt/OpenCode/ai.opencode" "$root/opt/OpenCode/resources/opencode-cli"
  mv "$root/opt/OpenCode" OpenCode
  mv "$root/usr/share" share
  # Fail on new files upstream adds outside of these, so a human looks at them.
  rm -rf share/doc
  find "$root" -mindepth 1 -not -type d | grep . && die "unexpected files in $deb"
  [[ $(find share -type f | sort | tr '\n' ' ') == "share/applications/ai.opencode.desktop.desktop share/applications/opencode-desktop.desktop share/icons/hicolor/128x128/apps/ai.opencode.png share/icons/hicolor/32x32/apps/ai.opencode.png share/icons/hicolor/64x64/apps/ai.opencode.png share/metainfo/ai.opencode.desktop.metainfo.xml " ]] ||
    die "$deb has other files in /usr/share than we package: $(find share -type f | tr '\n' ' ')"
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE" LICENSE
}
