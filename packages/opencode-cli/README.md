# opencode-cli

This package provides [OpenCode](https://opencode.ai), the open source coding agent, repackaged from the official `opencode-linux-x64.tar.gz` / `opencode-linux-arm64.tar.gz` release builds. The binaries are not recompiled. The package tracks v2, the release line installed by `https://opencode.ai/v2/install`. Upstream also releases v1.x, which GitHub marks as "Latest". Before packaging, we check each tarball against the SHA-256 digest GitHub records for the release asset.

The package is named `opencode-cli` and provides `opencode` (with epoch 1, `opencode (= 1:VERSION-RELEASE)`), so it is also available through `apt install opencode` / `dnf install opencode`. The package name `opencode` is used by upstream's own desktop app packages (`opencode-desktop-linux-*.deb` / `.rpm`, the Electron app in `/opt/OpenCode` with `/usr/bin/ai.opencode`). Using that name for the CLI package would give it a higher version than the upstream desktop package, causing upgrades to replace the desktop application with the CLI. This repository has the desktop app as [`opencode-desktop`](../opencode-desktop/README.md), which replaces upstream's `opencode` package. It conflicts only with `opencode` versions without an epoch, so the CLI package uses an epoch in its provided version. Either desktop package can coexist with `opencode-cli`; they share no files.

## Package contents

| Path | Description |
|---|---|
| `/usr/bin/opencode` | The upstream binary (the official installer puts it in `~/.opencode/bin`) |
| `/usr/share/bash-completion/completions/opencode`, `/usr/share/zsh/site-functions/_opencode`, `/usr/share/fish/vendor_completions.d/opencode.fish` | Shell completions, generated with `opencode --completions` |

The installer also creates `~/.opencode/bin/opencode2`, a compatibility shim for v1 installations; this package does not ship it.

On x86-64, the package uses `opencode-linux-x64-baseline.tar.gz`, the build the installer selects on CPUs without AVX2. It runs on any x86-64 CPU. Its code is the same as `opencode-linux-x64.tar.gz`.

`git` and `ripgrep` are recommended. OpenCode uses `rg` from `PATH`; without it, it downloads its own copy to `~/.cache/opencode/bin` the first time it searches files. On EL, `ripgrep` comes from EPEL.

## Updating

Update with `apt upgrade` / `dnf upgrade`.

- **`opencode upgrade`** only supports its own installer (`~/.opencode/bin`), npm, pnpm, bun, yarn, Vite+, Homebrew and WinGet. It does not recognize `/usr/bin/opencode` as any of these installation methods and exits with *"Could not detect the installation method"* without modifying files, whether run as root or a non-root user. Do not pass `--method`: `--method curl` installs a second copy into `~/.opencode/bin` and adds it to your shell's `PATH`, where it takes precedence over this package.
- **Update check:** The upstream interactive TUI queries opencode.ai for the latest release every 10 minutes and shows *"Update available"*. Installation through that dialog also fails (*"Update with your package manager"*), and the suggested `--method curl` option installs a second copy that takes precedence over this package. opencode reads this setting only from the user's own config or the environment, not from `/etc`, so the package installs `/etc/profile.d/opencode.sh`, which sets

  ```sh
  OPENCODE_DISABLE_AUTOUPDATE=1   # only if you haven't set it yourself
  ```

  With `1` or `true`, opencode skips the update check entirely.

  - It applies to login shells that read `/etc/profile`: bash and sh on every supported system, and zsh on RHEL/Rocky/Alma (Debian's and Ubuntu's zsh do not read it by default). fish never reads it, nor do services, cron jobs or `ssh host opencode …` without a login shell. Set the variable explicitly in those environments to disable the check, or use `{ "autoupdate": false }` in `~/.config/opencode/opencode.json`.
  - To restore the update check, add `export OPENCODE_DISABLE_AUTOUPDATE=0` in `~/.profile` / `~/.bashrc`, or delete `/etc/profile.d/opencode.sh` for all users. Package upgrades preserve modifications to or deletion of this configuration file.
  - Open a new login shell after installing for it to take effect.

The TUI starts a per-user background server. After a package update, the next invocation of `opencode` detects the version change and restarts the server.

## Data and removal

OpenCode keeps its configuration in `~/.config/opencode`, sessions and credentials in `~/.local/share/opencode`, state in `~/.local/state/opencode` and a cache in `~/.cache/opencode`, as upstream does. Package removal preserves these directories. `opencode uninstall` (run as each user before removing the package) stops that user's background server and deletes the cache; it preserves other data and reports that it cannot remove the binary itself.

System-wide configuration is stored in `/etc/opencode/opencode.json`, which upstream loads as managed settings that override user and project config. The package does not include this file.
