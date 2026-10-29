# opencode-desktop

The [OpenCode](https://opencode.ai) desktop app (Electron), repackaged from upstream's `opencode-desktop-linux-amd64.deb` / `-arm64.deb` release builds. Nothing is recompiled. Upstream publishes no plain Linux tarball of the app, only `.deb`, `.rpm` and AppImage. We check the `.deb` against the sha256 digest GitHub records for the release asset, unpack it and build our own `.deb` and `.rpm` from its files. We follow the v2 line, like `opencode-cli`.

## What the package installs

| Path | |
|---|---|
| `/opt/OpenCode` | The app as upstream ships it, minus `resources/package-type` (see [Updating](#updating)). It includes its own copy of the CLI, `resources/opencode-cli`, which the app runs as its background server. |
| `/usr/bin/ai.opencode` | Starts the app. An `update-alternatives` link (group `ai.opencode`), as upstream's package sets it up. |
| `/usr/share/applications/ai.opencode.desktop.desktop`, `opencode-desktop.desktop` | Menu entries as upstream ships them. The first also handles `opencode://` links. |
| `/usr/share/icons/hicolor/*/apps/ai.opencode.png`, `/usr/share/metainfo/ai.opencode.desktop.metainfo.xml` | Icons and AppStream data |

Installing does what upstream's package does after installing:

- `/opt/OpenCode/chrome-sandbox` becomes setuid root only where unprivileged user namespaces don't work (`unshare --user true` fails); otherwise it stays `0755`. `rpm -V` therefore can report its mode as changed.
- On systems whose AppArmor understands upstream's profile (Ubuntu 24.04 and later restrict user namespaces unless a profile allows them), it copies `/opt/OpenCode/resources/apparmor-profile` to `/etc/apparmor.d/ai.opencode` and loads it. Removing the package removes and unloads it.

Dependencies are upstream's, plus the libraries `ai.opencode` links against that upstream leaves out: `libasound2` on Debian/Ubuntu; `alsa-lib`, `mesa-libgbm` and `cups-libs` on EL. The rpm doesn't depend on `libXScrnSaver` (upstream's does). EL10 doesn't have that package outside EPEL, and nothing in the app links against it. Upstream's own rpm can't be installed on Rocky/RHEL 10 without EPEL.

## Updating

Update with `apt upgrade` / `dnf upgrade`.

The app has a built-in updater (electron-updater). It checks `opencode.ai/update/api/latest/desktop/opencode/` every 10 minutes. electron-updater picks how to update from `resources/package-type`. With upstream's `deb` or `rpm` there, it would download upstream's package and install it with `pkexec`, replacing this one with upstream's `opencode`. We leave that file out, so electron-updater falls back to its AppImage updater. That updater does nothing outside an AppImage (`$APPIMAGE` is unset): it makes no network request, logs *"APPIMAGE env is not defined"* in `~/.config/ai.opencode.desktop/logs/*/main.log`, and the app reports itself as up to date, also when you use "Check for updates" in the menu. The test checks that log line.

## Coexistence with opencode-cli

`opencode-desktop` and `opencode-cli` share no files and can be installed together. The app doesn't use `/usr/bin/opencode`; it runs its bundled copy of the CLI of the same version. The first time a user starts a new version, the app copies that binary (about 250 MB) to `~/.config/ai.opencode.desktop/cli/<version>-<arch>/`, as upstream does. Like the CLI, it keeps sessions and settings in `~/.config/opencode` and `~/.local/share/opencode`, and the app's own data in `~/.config/ai.opencode.desktop`. The app also makes itself the user's handler for `opencode://` links (`~/.config/mimeapps.list`).

## Switching from upstream's package

Upstream's `.deb` and `.rpm` of the app are named `opencode`, without an epoch. `opencode-desktop` replaces them:

- **deb:** `Conflicts` and `Replaces: opencode (<< 1:0~)`. `apt install opencode-desktop` removes upstream's `opencode` and installs ours. Installing upstream's `.deb` again removes ours the same way.
- **rpm:** `Obsoletes: opencode < 1:0`. `dnf install opencode-desktop` replaces upstream's package, and so does a plain `dnf upgrade` once this repository is enabled.

`opencode-cli` provides `opencode` with epoch 1 (`opencode (= 1:VERSION-RELEASE)`), so these rules don't affect it. `apt install opencode` / `dnf install opencode` without upstream's package installs `opencode-cli`.

## Testing

`TEST_CMD` checks the files, the `ai.opencode` alternative, the setuid sandbox, the bundled CLI's version, missing libraries (`ldd`) and the `.desktop` files (`desktop-file-validate`). It then starts the app as a normal user and waits until the main log shows the window visible, the bundled CLI running as the background service and the updater in the state described above. Debian and Ubuntu run it under Xvfb. EL10 has no Xvfb, not even in EPEL, so there it runs on Chromium's headless Ozone backend (`--ozone-platform=headless`). It runs with `--no-sandbox` because a container has neither unprivileged user namespaces nor the privileges the setuid sandbox needs. The test shows that the app installs, starts and gets its server going. It doesn't test the UI.

Switching from upstream's packages in both directions, and installing next to `opencode-cli`, were tested by hand in debian:13, ubuntu:26.04 and rockylinux:10 (with EPEL for upstream's rpm).
