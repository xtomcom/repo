# bun

[Bun](https://bun.com), the JavaScript runtime, bundler, test runner and package manager, repackaged from the official `bun-linux-x64.zip` / `bun-linux-aarch64.zip` release builds. Nothing is recompiled. Before packaging, we check the signature on `SHASUMS256.txt.asc` against Bun's release key (`F3DCC08A8572C0749B3E18888EAB4D40A7B22B59`, the key upstream's Docker images pin) and then check the zip against the signed checksum.

## What the package installs

| Path | |
|---|---|
| `/usr/bin/bun` | The upstream binary |
| `/usr/bin/bunx` | Symlink to `bun`, as the official installer creates it |
| `/usr/share/bash-completion/completions/bun`, `/usr/share/zsh/site-functions/_bun`, `/usr/share/fish/vendor_completions.d/bun.fish` | Shell completions, generated with `bun completions` |

On x86-64, upstream also publishes `bun-linux-x64-baseline.zip` for CPUs without AVX2, and the installer picks it on such CPUs. Current releases ship the identical binary under both names, so one package fits every x86-64 CPU.

## Updating

Update with `apt upgrade` / `dnf upgrade`. **Don't run `bun upgrade`.** It can't be turned off; run as root it replaces `/usr/bin/bun` with a download that dpkg/rpm don't know about, and the next package update overwrites it again. As a normal user it fails with a permission error.

## Global packages

`bun install -g` / `bun add -g` work as upstream: packages go to `~/.bun/install/global` and their commands to `~/.bun/bin` of the user who runs them. Add that directory to your `PATH`:

```sh
export PATH="$HOME/.bun/bin:$PATH"
```

`BUN_INSTALL` (or `globalDir` / `globalBinDir` in `~/.bunfig.toml`) changes these locations.
