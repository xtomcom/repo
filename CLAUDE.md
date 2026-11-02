# Notes for AI agents

This file is for AI coding agents (`AGENTS.md` is a symlink to it). Read it before changing anything, and keep it current: when you change how something works or run into a new pitfall, update this file in the same commit.

This repository is public. Never write credentials, tokens, private hostnames, server paths, customer or user data, or anything else private into this file, commit messages, code or tests. Use placeholders such as `example.com`.

## What this repository is

It repackages official upstream amd64/arm64 release binaries as .deb and .rpm with nfpm. Nothing is compiled. The packages are published as a signed apt/dnf repository at https://repo.xtom.com. `README.md` ("How it works", "Adding a package") describes the scripts, the package layout and how to build and test; read it first.

Supported systems: Debian 12/13, Ubuntu 22.04/24.04/26.04, EL 9/10 (Rocky, Alma, RHEL).

## Rules

- Follow Debian and EPEL packaging conventions. Our version must sort newer than the distribution's own package of the same name.
- Verify every download: the upstream checksum file (`verify_sums`), a GPG signature, or, if upstream publishes neither, the SHA-256 digest GitHub records for the asset (`verify_sha256` with `gh_asset_sha256`). If none exists, pin the hashes in `prepare` and fail on unknown versions.
- Call `check_glibc` on glibc builds (oldest supported glibc is 2.34, EL9).
- Never start or enable a service on install. On a fresh install only, print a short notice: "NAME is installed but not started. To start it: ..." with the exact steps. On upgrade, `try-restart` the service. On removal, stop and disable it.
- A service must not run with an unsafe default. If upstream listens on all addresses without authentication when the configuration is empty or missing, ship a configuration that binds to 127.0.0.1, or make the unit refuse to start until the configuration has settings (see `packages/frp`).
- Configuration files that will hold secrets are `config|noreplace`, mode 0600 or 0640 with the service's group.
- Prefer a dedicated system user created with a sysusers.d file; run as root only when the job needs it (e.g. backups).
- Published filenames are never reused. To ship a packaging fix for an already published version, increment `RELEASE` in `package.sh`.
- `README.md`, `site/README.md` and the per-package `README.md` files are written by the maintainer. Only add or correct facts (e.g. a new package row, using "and/or" when either of two services can be used); do not rewrite their prose.
- Commit and push only when asked. Do not trigger the Update workflow (`gh workflow run update.yml`), which publishes to the live repository, unless explicitly asked. Never touch the signing key on the server.
- Only stage files you changed yourself.

## Before committing

```bash
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable \
  scripts/*.sh tests/*.sh packages/*/*.sh packages/_shared/*/*.sh
scripts/check.sh NAME          # should list the new version, without warnings
scripts/build.sh NAME VERSION amd64
scripts/test.sh NAME VERSION amd64
```

arm64 cannot be tested on a machine without emulation (exit status 255); CI tests it on native arm64 runners.

## Pitfalls we have hit

Testing:

- The Ubuntu Docker image excludes `/usr/share/doc` and `/usr/share/man` on install, so `test -f` on them fails there. Check the package's file list instead: `if command -v dpkg >/dev/null; then dpkg -L NAME; else rpm -ql NAME; fi | grep -q PATH`.
- The Debian image has no `ps`. Check a service's user with `stat -c %U /proc/$(systemctl show -p MainPID --value UNIT)`.
- `$VERSION` is not set inside `TEST_CMD` and `SERVICE_TEST`.
- A simple TCP service for tunnel tests: `systemd-run --unit echo systemd-socket-activate -l 127.0.0.1:8080 --inetd -a cat`.
- Test the real behaviour under systemd (`SERVICE_TEST`), not just that the unit file exists. Several bugs below only showed up there.

Upstream quirks:

- Forgejo 16+ ships `Type=notify`, but never reports ready while the web installer runs, so starting a fresh install times out. We switch the unit to `Type=simple`.
- UPX-packed binaries (rathole) crash with `MemoryDenyWriteExecute=yes`. Leave that option out for them and say why in the unit.
- frps with a configuration that holds only comments listens on 0.0.0.0:7000 with no authentication; the units therefore refuse to start until the configuration has a setting.
- GoBackup's web UI and API default to 0.0.0.0:2703 without a password and can download backups; the shipped configuration binds it to 127.0.0.1. Without a model, `gobackup run` exits with status 1 (hence `RestartPreventExitStatus=1`).
- opencode's x64 and x64-baseline tarballs can differ by one byte in the Bun trailer; the package uses the baseline build. bun has a similar check that may fail one day for the same reason.
- cloudflared's self-update is disabled by the marker file `/usr/local/etc/cloudflared/.installedFromPackageManager`, which the package creates.
- Gitea and Forgejo run as `git`, like upstream's docs and the default SSH clone URL `git@host`. Users migrating a manual install that used another user (e.g. `gitea`) need a `systemctl edit` override with `User=`, `Group=` and `Environment=USER=... HOME=...`, then `gitea admin regenerate keys` and `regenerate hooks` (the old `authorized_keys` and hooks contain the old binary path).

Scripts and CI:

- Version lookups that call an upstream API run in every `stale()` subshell during publishing. Cache the result (see `forgejo_tracks` in `packages/_shared/forgejo/common.sh`) and fall back to a mirror, or the publish log fills with 5xx errors.
- `scripts/check.sh` warns when upstream has a release newer than `BRANCHES`. A package that deliberately follows an older line (e.g. `forgejo-lts`) must filter `versions()`.
- Files shared by several packages live in `packages/_shared/NAME/` and are symlinked; a change there makes `scripts/ci-matrix.sh` build every package that links to or sources it.
- The bot pushes "chore: publish ..." commits to `main`; pull with `--rebase` before pushing.
- `ci.yml` ignores changes to `versions.json` and Markdown files.
