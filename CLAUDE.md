# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` is a symlink to this file, so other AI agents read it too. Keep it current: when you change how something works or run into a new pitfall, update this file in the same commit.

This repository is public. Never write credentials, tokens, private hostnames, server paths, customer or user data, or anything else private into this file, commit messages, code or tests. Use placeholders such as `example.com`.

## What this repository is

It repackages official upstream amd64/arm64 release binaries as .deb and .rpm with nfpm. Nothing is compiled. The packages are published as a signed apt/dnf repository at https://repo.xtom.com. `README.md` ("How it works", "Adding a package") documents the package layout and the `package.sh` variables; read it first.

Supported systems: Debian 12/13, Ubuntu 22.04/24.04/26.04, EL 9/10 (Rocky, Alma, RHEL).

## Commands

Needs Docker, nfpm (`npm install -g @goreleaser/nfpm`), `gh` (logged in, for GitHub release lookups) and `jq`.

```bash
scripts/check.sh NAME              # JSON list of what would be built; warns about newer upstream branches
scripts/check.sh NAME@VERSION      # force one version
scripts/build.sh NAME VERSION amd64        # into dist/
scripts/test.sh NAME VERSION amd64         # Debian 13, Ubuntu 26.04, Rocky 10, then the same under systemd if SERVICE_TEST is set
DEB_IMAGES="debian:12 ubuntu:22.04" RPM_IMAGES=rockylinux/rockylinux:9 scripts/test.sh NAME VERSION amd64   # other images (empty means the default)

# Lint, as CI does (CI runs `shellcheck -x` with .shellcheckrc)
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable \
  scripts/*.sh tests/*.sh packages/*/*.sh packages/_shared/*/*.sh

tests/retention.sh   # which builds stale() keeps (fast, needs dpkg)
tests/repo.sh        # end-to-end publish to a local directory, install and upgrade with apt and dnf
tests/nodejs.sh      # Node.js lines; tests/golang.sh: Go versions
```

arm64 cannot be tested on a machine without emulation (exit status 255); CI tests it on native arm64 runners. `.shellcheckrc` disables SC2016 and friends because `TEST_CMD`/`SERVICE_TEST` are single-quoted on purpose: they expand inside the test container.

## Architecture

- `scripts/lib.sh` holds the helpers (`download`, `verify_sums`, `verify_sha256`, `gh_asset_sha256`, `check_glibc`, `gh_versions`) and `load_package`, which resets the defaults (`ARCHS=(amd64 arm64)`, `RELEASE=1`, `versions()` = stable GitHub releases of `UPSTREAM`) and sources `packages/NAME/package.sh`. Each `package.sh` must set `BRANCHES` and define `prepare VERSION ARCH`, which runs in a work directory and leaves the files that `nfpm.yaml` refers to.
- **Branches and retention.** `BRANCHES` lists the upstream lines we carry (`(28)` for Gitea 28.x, `(1.27 1.26)` style for side-by-side lines). `check.sh` builds the newest release of each branch that differs from `versions.json`; a release newer than every branch only warns, since moving to a new major is a human decision. During publishing `stale()` drops every build that is not the newest of its branch, and every build of a package whose directory was removed from `packages/` (retired).
- **`versions.json`** records what is on the server as `VERSION-RELEASE`. `publish.sh` regenerates it from the server's indexes and the bot commits it ("chore: publish ..."). Do not edit it by hand.
- **Workflows.** `update.yml` (daily, or `workflow_dispatch` with `packages=NAME` / `NAME@VERSION`, or `repository_dispatch` `upstream-release`) runs `check.sh`, then `build.yml` builds and tests each package/arch on a native runner, then `publish.sh` merges the new files into the server's indexes, signs, uploads with rsync, deletes superseded files, purges the CDN cache and writes `versions.json`. A release is only published once all its architectures passed, and a deb whose dependency (one of our packages) is not available is skipped. Runs are serialized (`concurrency: publish`). `ci.yml` runs on push/PR: lint, `tests/retention.sh`, and `scripts/ci-matrix.sh` decides which packages to build and test from the changed files (any change under `scripts/` or the workflows rebuilds everything).
- **Repository layout.** deb: `deb/dists/stable` with `pool/main/<prefix>/<name>/`; rpm: `rpm/<arch>/` with createrepo_c metadata. rpm releases are `RELEASE.xtom`. `site/README.md` is the page served at the repository root (the package table is filled in at publish time); `scripts/repo.sh` is the client setup script users pipe to bash.
- **Shared packages.** `packages/_shared/NAME/` holds files used by several packages (the Node.js lines, the Go versions, forgejo/forgejo-lts, opencode), symlinked or sourced from each package directory. `nodejs` and `golang` are metapackages for the newest line, with `TEST_DEPS` so the test builds the line they depend on.
- **Sorting above the distribution.** Packages that share a name with a distribution package use an nfpm `epoch` (e.g. `golang*` uses 2, like Debian's `golang-go`), so ours always win.

## Rules

- Follow Debian and EPEL packaging conventions. Our version must sort newer than the distribution's own package of the same name.
- Verify every download: the upstream checksum file (`verify_sums`), a GPG signature, or, if upstream publishes neither, the SHA-256 digest GitHub records for the asset (`verify_sha256` with `gh_asset_sha256`). If none exists, pin the hashes in `prepare` and fail on unknown versions.
- Call `check_glibc` on glibc builds (oldest supported glibc is 2.34, EL9). Use the musl build only when the glibc one needs more.
- Never start or enable a service on install. On a fresh install only, print a short notice: "NAME is installed but not started. To start it: ..." with the exact steps. On upgrade, `try-restart` the service. On removal, stop and disable it. Copy the maintainer scripts of a similar package (e.g. `packages/frp`).
- A service must not run with an unsafe default. If upstream listens on all addresses without authentication when the configuration is empty or missing, ship a configuration that binds to 127.0.0.1, or make the unit refuse to start until the configuration has settings (see `packages/frp`).
- Configuration files that will hold secrets are `config|noreplace`, mode 0600 or 0640 with the service's group.
- Prefer a dedicated system user created with a sysusers.d file; run as root only when the job needs it (e.g. backups).
- Published filenames are never reused. To ship a packaging fix for an already published version, increment `RELEASE` in `package.sh`.
- A new package also gets a row in the `README.md` package table and, if it ships a service, a mention in the service list of `site/README.md`.
- `README.md`, `site/README.md` and the per-package `README.md` files are written by the maintainer. Only add or correct facts (e.g. a new package row, using "and/or" when either of two services can be used); do not rewrite their prose.
- Commit and push only when asked. Do not trigger the Update workflow (`gh workflow run update.yml`), which publishes to the live repository, unless explicitly asked. Never touch the signing key on the server.
- Only stage files you changed yourself.

## Pitfalls we have hit

Testing:

- The Ubuntu Docker image excludes `/usr/share/doc` and `/usr/share/man` on install, so `test -f` on them fails there. Check the package's file list instead: `if command -v dpkg >/dev/null; then dpkg -L NAME; else rpm -ql NAME; fi | grep -q PATH`.
- The Debian image has no `ps`. Check a service's user with `stat -c %U /proc/$(systemctl show -p MainPID --value UNIT)`.
- `$VERSION` is not set inside `TEST_CMD` and `SERVICE_TEST`.
- A simple TCP service for tunnel tests: `systemd-run --unit echo systemd-socket-activate -l 127.0.0.1:8080 --inetd -a cat`.
- Test the real behaviour under systemd (`SERVICE_TEST`), not just that the unit file exists. Several bugs below only showed up there.
- The anubis service test has failed once on Ubuntu without a code change and passed on rerun; rerun a failed job before hunting for a cause in unrelated changes.

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
- A package that deliberately follows an older line (e.g. `forgejo-lts`) must filter `versions()`, or `check.sh` keeps warning about the newer one.
- The bot pushes "chore: publish ..." commits to `main`; pull with `--rebase` before pushing.
- `ci.yml` ignores changes to `versions.json` and Markdown files, so a docs-only push runs no CI.
