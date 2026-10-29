# codex

This package provides [Codex CLI](https://github.com/openai/codex), OpenAI's coding agent for the terminal, repackaged from the official `codex-package-x86_64-unknown-linux-musl.tar.gz` / `codex-package-aarch64-unknown-linux-musl.tar.gz` release archives (also used by `chatgpt.com/codex/install.sh`). The binaries are not recompiled. We check each archive against the release's `codex-package_SHA256SUMS`, as the installer does. The `.sigstore` bundles are not verified; verification would require cosign.

Only stable `rust-vX.Y.Z` releases are packaged. The daily `-alpha.N` prereleases are skipped.

## Package contents

| Path | Description |
|---|---|
| `/usr/lib/codex/` | The upstream archive, unchanged: `codex-package.json`, `bin/codex`, `bin/codex-code-mode-host`, `codex-path/rg` (ripgrep), `codex-resources/bwrap` (bubblewrap), `codex-resources/voice/` |
| `/usr/bin/codex` | Symlink to `../lib/codex/bin/codex` |
| `/etc/codex/config.toml` | System-wide defaults, see below (a conffile) |
| `/usr/share/bash-completion/completions/codex`, `/usr/share/zsh/site-functions/_codex`, `/usr/share/fish/vendor_completions.d/codex.fish` | Shell completions, generated with `codex completion` |

`codex` resolves its own path (through `/proc/self/exe`, independently of the symlink), finds `codex-package.json` one level above `bin/`, and loads ripgrep from `codex-path/`, bubblewrap from `codex-resources/` and the code-mode host from `bin/`. `codex doctor` reports the selected component paths. `codex`, the code-mode host and bwrap are static musl binaries. rg is also statically linked on x86-64. On arm64, upstream bundles ripgrep's glibc build (it needs glibc 2.18 and libgcc_s). The voice host in `codex-resources/voice/` is a glibc build (it needs glibc 2.28) and includes its own GLib/GStreamer libraries.

Download sizes are approximately 140 MB (.deb) and 155 MB (.rpm). The installed package occupies about 430 MB, primarily `bin/codex`.

## Updates and package defaults

Update with `apt upgrade` / `dnf upgrade`. Codex has three update mechanisms. None can replace `/usr/lib/codex`, but the startup update prompt and background daemon can lead to running a separately installed version. The package disables both by default in `/etc/codex/config.toml`:

```toml
check_for_update_on_startup = false

[features]
daemon_auto_start = false
```

These system-wide defaults can be overridden in `~/.codex/config.toml` or with `-c key=value`.

- **`codex update`** only supports npm, bun, pnpm, Vite+, Homebrew and its own installer (`~/.codex/packages/standalone`). It does not recognize `/usr/lib/codex` as any of these installation methods and exits with *"Could not detect the Codex installation method. Please update manually"* without modifying files, whether run as root or a non-root user. No environment variable or marker file redirects it to apt or dnf.
- **The startup update check** (`check_for_update_on_startup`) queries GitHub for the latest release once a day. When there is a newer one, the TUI shows *"Update available! See https://github.com/openai/codex for installation options."* The linked installation instructions can create a second copy in `~/.local/bin` that takes precedence over this package. Upstream documents the setting as "set to `false` only if your Codex updates are centrally managed", as they are for this package.
- **The shared app-server daemon** (`features.daemon_auto_start`, on by default upstream). The interactive TUI starts a background server that continues running after the TUI exits. Codex copies the full package into `~/.codex/packages/app-server-daemon/releases/` (about 430 MB per user) and starts a separate updater. Every hour the updater runs `chatgpt.com/codex/install.sh` and installs the latest upstream release. With this feature enabled, the `codex` command comes from this package, while the background server uses the latest upstream release. With the feature off, the TUI runs its own app-server in-process, as `codex --no-daemon` does.

To restore upstream behavior for a user, add the following to `~/.codex/config.toml`:

```toml
check_for_update_on_startup = true

[features]
daemon_auto_start = true
```

To stop a daemon that is already running, use `codex app-server daemon stop`. You can then delete `~/.codex/packages/app-server-daemon`. An administrator who wants these settings enforced rather than defaulted can set `check_for_update_on_startup` in `/etc/codex/requirements.toml`. Codex uses that file to enforce settings. This package does not include it.

When `/etc/codex/config.toml` exists, new users see the composer before the account check prompts them to sign in. Without that file, a startup shortcut displays the sign-in screen immediately.

If you edited `/etc/codex/config.toml`, upgrades keep your version (`config|noreplace`).

## Sandbox requirements

Codex sandboxes the commands it runs with bubblewrap, which needs unprivileged user namespaces. It uses the first `bwrap` on `PATH` and falls back to the bundled one, warning at startup when there is no system `bwrap`. The package therefore recommends `bubblewrap`. The system `bwrap` must support `--perms` (bubblewrap 0.5 or later). EL9's 0.4.1 does not, so Codex uses the bundled one there.

- Ubuntu 24.04 and later restrict unprivileged user namespaces with AppArmor. On 25.04 and later, the `apparmor` package's `bwrap-userns-restrict` profile covers `/usr/bin/bwrap`, so installing `bubblewrap` is enough. On 24.04, upstream says to load the extra profile too:

  ```sh
  sudo apt install apparmor-profiles apparmor-utils
  sudo install -m 0644 /usr/share/apparmor/extra-profiles/bwrap-userns-restrict /etc/apparmor.d/
  sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
  ```

  The bundled `/usr/lib/codex/codex-resources/bwrap` is not covered by that profile.
- In containers that block user namespaces (Docker's default seccomp profile, for example), the sandbox cannot start. Run Codex with `--sandbox danger-full-access` there, or allow user namespaces.

See [upstream's sandboxing notes](https://developers.openai.com/codex/concepts/sandboxing#prerequisites).

## Per-user data

Codex stores configuration, sign-in data, sessions and logs in `~/.codex` (or `$CODEX_HOME`). On startup it also creates small helper links in `~/.codex/tmp/arg0`. Package removal preserves these files.
