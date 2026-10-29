# opencode-cli

[OpenCode](https://opencode.ai), the open source coding agent, repackaged from the official `opencode-linux-x64.tar.gz` / `opencode-linux-arm64.tar.gz` release builds. Nothing is recompiled. We follow the v2 line, which `https://opencode.ai/v2/install` installs (upstream still releases v1.x alongside it, and GitHub marks those "Latest"). Before packaging, we check each tarball against the sha256 digest GitHub records for the release asset.

The package is named `opencode-cli` and provides `opencode` (with epoch 1, `opencode (= 1:VERSION-RELEASE)`), so `apt install opencode` / `dnf install opencode` find it too. The plain name `opencode` belongs to upstream's own desktop app packages (`opencode-desktop-linux-*.deb` / `.rpm`, the Electron app in `/opt/OpenCode` with `/usr/bin/ai.opencode`). Under that name, ours would sort as a newer version, and an upgrade would replace the desktop app with the CLI. This repository has the desktop app as [`opencode-desktop`](../opencode-desktop/README.md), which replaces upstream's `opencode` package. It conflicts only with `opencode` versions without an epoch, which is why the provide here has one. Either desktop package can be installed next to `opencode-cli`; they share no files.

## What the package installs

| Path | |
|---|---|
| `/usr/bin/opencode` | The upstream binary (the official installer puts it in `~/.opencode/bin`) |
| `/usr/share/bash-completion/completions/opencode`, `/usr/share/zsh/site-functions/_opencode`, `/usr/share/fish/vendor_completions.d/opencode.fish` | Shell completions, generated with `opencode --completions` |

The installer also creates `~/.opencode/bin/opencode2`, a shim for old v1 setups; this package doesn't ship it.

On x86-64, upstream also publishes `opencode-linux-x64-baseline.tar.gz` for CPUs without AVX2, and the installer picks it on such CPUs. Current releases ship the identical tarball under both names, so one package fits every x86-64 CPU.

`git` and `ripgrep` are recommended. OpenCode uses `rg` from `PATH`; without it, it downloads its own copy to `~/.cache/opencode/bin` the first time it searches files. On EL, `ripgrep` comes from EPEL.

## Updating

Update with `apt upgrade` / `dnf upgrade`.

- **`opencode upgrade`** only knows its own installer (`~/.opencode/bin`), npm, pnpm, bun, yarn, Vite+, Homebrew and WinGet. For `/usr/bin/opencode` it finds none of them and stops with *"Could not detect the installation method"* without changing anything, as root or as a normal user. Don't pass `--method`: `--method curl` installs a second copy into `~/.opencode/bin` and adds it to your shell's `PATH`, where it shadows this package.
- **The update check.** Upstream's interactive TUI asks opencode.ai for the latest release every 10 minutes and shows *"Update available"*. Installing from that dialog fails the same way (*"Update with your package manager"*), and the advice it leads to (`--method curl`) would put a second copy in front of this one. opencode reads this setting only from the user's own config or the environment, not from `/etc`, so the package installs `/etc/profile.d/opencode.sh`, which sets

  ```sh
  OPENCODE_DISABLE_AUTOUPDATE=1   # only if you haven't set it yourself
  ```

  With `1` or `true`, opencode skips the update check entirely.

  - It applies to login shells that read `/etc/profile`: bash and sh on every supported system, and zsh on RHEL/Rocky/Alma (Debian's and Ubuntu's zsh don't read it by default). fish never reads it, nor do services, cron jobs or `ssh host opencode …` without a login shell. Set the variable yourself there if you want the same behaviour, or use `{ "autoupdate": false }` in `~/.config/opencode/opencode.json`.
  - To get the update check back, put `export OPENCODE_DISABLE_AUTOUPDATE=0` in `~/.profile` / `~/.bashrc`, or delete `/etc/profile.d/opencode.sh` for everyone. It is a configuration file, so package upgrades leave your edit or deletion alone.
  - Open a new login shell after installing for it to take effect.

The TUI starts a per-user background server. After a package update, the next `opencode` notices the version change and restarts it.

## Data and removal

OpenCode keeps its configuration in `~/.config/opencode`, sessions and credentials in `~/.local/share/opencode`, state in `~/.local/state/opencode` and a cache in `~/.cache/opencode`, as upstream does. Removing the package leaves all of them. `opencode uninstall` (run as each user before removing the package) stops that user's background server and deletes the cache; it keeps the rest and reports that it can't remove the binary itself.

System-wide configuration goes in `/etc/opencode/opencode.json`, which upstream loads as managed settings that override user and project config. The package doesn't ship one.
