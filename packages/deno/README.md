# deno

[Deno](https://deno.com), the JavaScript, TypeScript and WebAssembly runtime, repackaged from the official `deno-x86_64-unknown-linux-gnu.zip` / `deno-aarch64-unknown-linux-gnu.zip` release builds. Nothing is recompiled. Before packaging, we check each zip against upstream's `.zip.sha256sum` file. Upstream publishes no signatures.

## What the package installs

| Path | |
|---|---|
| `/usr/bin/deno` | The upstream binary |
| `/usr/share/bash-completion/completions/deno`, `/usr/share/zsh/site-functions/_deno`, `/usr/share/fish/vendor_completions.d/deno.fish` | Shell completions, generated with `deno completions` |

The completions take precedence over the generic `deno` completions that bash-completion and fish ship.

## Updating

Update with `apt upgrade` / `dnf upgrade`. **Don't run `deno upgrade`.** Upstream can only remove it at build time (the `upgrade` Cargo feature), and we use the release binaries as they are. Run as root, it replaces `/usr/bin/deno` with a download that dpkg/rpm don't know about, and the next package update overwrites it again. As a normal user it fails with a permission error.

Deno also checks for new releases in the background and suggests `deno upgrade`. Set `DENO_NO_UPDATE_CHECK=1` in your environment to turn that off.

## Global installs

`deno install -g` works as upstream: it puts the command into `~/.deno/bin` of the user who runs it. Add that directory to your `PATH`:

```sh
export PATH="$HOME/.deno/bin:$PATH"
```

`DENO_INSTALL_ROOT` or `deno install -g --root DIR` changes the location.
