# bun

This package provides [Bun](https://bun.com), the JavaScript runtime, bundler, test runner and package manager, repackaged from the official `bun-linux-x64.zip` / `bun-linux-aarch64.zip` release builds. The binaries are not recompiled. Before packaging, we check the signature on `SHASUMS256.txt.asc` against Bun's release key (`F3DCC08A8572C0749B3E18888EAB4D40A7B22B59`, the key upstream's Docker images pin) and then check the zip against the signed checksum.

## Package contents

| Path | Description |
|---|---|
| `/usr/bin/bun` | The upstream binary |
| `/usr/bin/bunx` | Symlink to `bun`, as the official installer creates it |
| `/usr/share/bash-completion/completions/bun`, `/usr/share/zsh/site-functions/_bun`, `/usr/share/fish/vendor_completions.d/bun.fish` | Shell completions, generated with `bun completions` |

On x86-64, upstream also publishes `bun-linux-x64-baseline.zip` for CPUs without AVX2, and the installer selects it on those CPUs. Current releases provide the same binary under both names, so a separate baseline package is not required.

## Updating

Update with `apt upgrade` / `dnf upgrade`. Do not use `bun upgrade` for this installation. The self-updater cannot be disabled. When run as root, it replaces `/usr/bin/bun` with a binary not tracked by dpkg or rpm; the next package update overwrites that binary. When run as a non-root user, it fails with a permission error.

## Global packages

`bun install -g` / `bun add -g` retain upstream behavior: packages are installed in `~/.bun/install/global` and their commands to `~/.bun/bin` of the user who runs them. Add that directory to your `PATH`:

```sh
export PATH="$HOME/.bun/bin:$PATH"
```

`BUN_INSTALL` (or `globalDir` / `globalBinDir` in `~/.bunfig.toml`) changes these locations.
