# deno

This package provides [Deno](https://deno.com), the JavaScript, TypeScript and WebAssembly runtime, repackaged from the official `deno-x86_64-unknown-linux-gnu.zip` / `deno-aarch64-unknown-linux-gnu.zip` release builds. The binaries are not recompiled. Before packaging, we check each zip against upstream's `.zip.sha256sum` file. Upstream publishes no signatures.

## Package contents

| Path | Description |
|---|---|
| `/usr/bin/deno` | The upstream binary |
| `/usr/share/bash-completion/completions/deno`, `/usr/share/zsh/site-functions/_deno`, `/usr/share/fish/vendor_completions.d/deno.fish` | Shell completions, generated with `deno completions` |

The completions take precedence over the generic `deno` completions that bash-completion and fish ship.

## Updating

Update with `apt upgrade` / `dnf upgrade`. Do not use `deno upgrade` for this installation. The self-updater can only be removed at build time through the `upgrade` Cargo feature; this package uses unmodified release binaries. When run as root, it replaces `/usr/bin/deno` with a binary not tracked by dpkg or rpm; the next package update overwrites that binary. When run as a non-root user, it fails with a permission error.

Deno also checks for new releases in the background and suggests `deno upgrade`. Set `DENO_NO_UPDATE_CHECK=1` in your environment to disable this check.

## Global installs

`deno install -g` retains upstream behavior: it installs the command in `~/.deno/bin` of the user who runs it. Add that directory to your `PATH`:

```sh
export PATH="$HOME/.deno/bin:$PATH"
```

`DENO_INSTALL_ROOT` or `deno install -g --root DIR` changes the location.
