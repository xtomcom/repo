# codex

[Codex CLI](https://github.com/openai/codex), OpenAI's coding agent for the terminal, repackaged from the official `codex-package-x86_64-unknown-linux-musl.tar.gz` / `codex-package-aarch64-unknown-linux-musl.tar.gz` release archives (the ones `chatgpt.com/codex/install.sh` installs). Nothing is recompiled. We check each archive against the release's `codex-package_SHA256SUMS`, as the installer does. We don't check the `.sigstore` bundles, which would need cosign.

Only stable `rust-vX.Y.Z` releases are packaged. The daily `-alpha.N` prereleases are skipped.

## What the package installs

| Path | |
|---|---|
| `/usr/lib/codex/` | The upstream archive, unchanged: `codex-package.json`, `bin/codex`, `bin/codex-code-mode-host`, `codex-path/rg` (ripgrep), `codex-resources/bwrap` (bubblewrap), `codex-resources/voice/` |
| `/usr/bin/codex` | Symlink to `../lib/codex/bin/codex` |
| `/etc/codex/config.toml` | System-wide defaults, see below (a conffile) |
| `/usr/share/bash-completion/completions/codex`, `/usr/share/zsh/site-functions/_codex`, `/usr/share/fish/vendor_completions.d/codex.fish` | Shell completions, generated with `codex completion` |

`codex` resolves its own path (`/proc/self/exe`, so the symlink doesn't matter), finds `codex-package.json` one level above `bin/`, and takes ripgrep from `codex-path/`, bubblewrap from `codex-resources/` and the code-mode host from `bin/`. `codex doctor` shows which ones it uses. `codex`, the code-mode host and bwrap are static musl binaries. So is rg on x86-64, but on arm64 upstream bundles ripgrep's glibc build (it needs glibc 2.18 and libgcc_s). The voice host in `codex-resources/voice/` is a glibc build (it needs glibc 2.28) and brings its own GLib/GStreamer libraries.

The package is large: about 140 MB (.deb) / 155 MB (.rpm) to download and 430 MB installed, most of it `bin/codex`.

## Updating, and what we change

Update with `apt upgrade` / `dnf upgrade`. Upstream has three ways of updating itself. None of them can replace `/usr/lib/codex`, but two of them would quietly leave you running something other than this package. `/etc/codex/config.toml` turns those two off by default:

```toml
check_for_update_on_startup = false

[features]
daemon_auto_start = false
```

This is Codex's system config layer: anything in your `~/.codex/config.toml` (or `-c key=value`) wins over it.

- **`codex update`** only knows npm, bun, pnpm, Vite+, Homebrew and its own installer (`~/.codex/packages/standalone`). For `/usr/lib/codex` it finds none of them and stops with *"Could not detect the Codex installation method. Please update manually"*, as root or as a normal user, without changing anything. There is no environment variable or marker file that makes it point to apt/dnf instead.
- **The startup update check** (`check_for_update_on_startup`) asks GitHub for the latest release once a day. When there is a newer one, the TUI shows *"Update available! See https://github.com/openai/codex for installation options."*, which would lead people to install a second copy in `~/.local/bin` that shadows this one. Upstream documents the setting as "set to `false` only if your Codex updates are centrally managed", which is the case here.
- **The shared app-server daemon** (`features.daemon_auto_start`, on by default upstream). The interactive TUI starts a background server that outlives it. To run it, Codex copies the whole package into `~/.codex/packages/app-server-daemon/releases/` (about 430 MB per user) and starts an updater next to it. Every hour the updater runs `chatgpt.com/codex/install.sh` and swaps in the newest upstream release. The `codex` you start comes from this package, but the server doing the work would be whatever upstream shipped last. With the feature off, the TUI runs its own app-server in-process, as `codex --no-daemon` does.

To get upstream's behaviour back for yourself, put this in `~/.codex/config.toml`:

```toml
check_for_update_on_startup = true

[features]
daemon_auto_start = true
```

To stop a daemon that is already running, use `codex app-server daemon stop`. You can then delete `~/.codex/packages/app-server-daemon`. An administrator who wants these settings enforced rather than defaulted can set `check_for_update_on_startup` in `/etc/codex/requirements.toml`. That file is Codex's own mechanism for enforced settings, and this package doesn't ship one.

When `/etc/codex/config.toml` exists, Codex skips one startup shortcut that otherwise shows the sign-in screen right away to brand-new users. They see the composer first, and the usual account check then asks them to sign in.

If you edited `/etc/codex/config.toml`, upgrades keep your version (`config|noreplace`).

## Sandbox requirements

Codex sandboxes the commands it runs with bubblewrap, which needs unprivileged user namespaces. It uses the first `bwrap` on `PATH` and falls back to the bundled one, warning at startup when there is no system `bwrap`. That's why the package recommends `bubblewrap`. The system `bwrap` must support `--perms` (bubblewrap 0.5 or later). EL9's 0.4.1 doesn't, so Codex uses the bundled one there.

- Ubuntu 24.04 and later restrict unprivileged user namespaces with AppArmor. On 25.04 and later, the `apparmor` package's `bwrap-userns-restrict` profile covers `/usr/bin/bwrap`, so installing `bubblewrap` is enough. On 24.04, upstream says to load the extra profile too:

  ```sh
  sudo apt install apparmor-profiles apparmor-utils
  sudo install -m 0644 /usr/share/apparmor/extra-profiles/bwrap-userns-restrict /etc/apparmor.d/
  sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
  ```

  The bundled `/usr/lib/codex/codex-resources/bwrap` is not covered by that profile.
- In containers that block user namespaces (Docker's default seccomp profile, for example), the sandbox can't start. Run Codex with `--sandbox danger-full-access` there, or allow user namespaces.

See [upstream's sandboxing notes](https://developers.openai.com/codex/concepts/sandboxing#prerequisites).

## Per-user data

Everything Codex writes goes to `~/.codex` (or `$CODEX_HOME`): config, sign-in, sessions, logs. On startup it also creates small helper links in `~/.codex/tmp/arg0`. Removing the package leaves all of this alone.
