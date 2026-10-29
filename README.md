# xTom Package Repository

The xTom APT and DNF repository at [repo.xtom.com](https://repo.xtom.com/) provides packages of open source server software for `amd64` and `arm64`.

A daily GitHub Actions job checks upstream releases and publishes package updates automatically.

Packages use official release binaries from upstream distribution channels, including GitHub Releases and go.dev. Binaries are verified against upstream checksums or signatures where available and are not compiled from source. The `.deb` and `.rpm` packages define installation paths, systemd units, system users and default configuration. Package definitions are available in [`packages/`](packages/).

## Packages

| Package | Upstream | Architectures | Notes |
|---|---|---|---|
| `anubis` | [TecharoHQ/anubis](https://github.com/TecharoHQ/anubis) | amd64, arm64 | `anubis@.service` template, not enabled by default |
| `bun` | [oven-sh/bun](https://github.com/oven-sh/bun) | amd64, arm64 | `bun` and `bunx`. Update with apt/dnf, not `bun upgrade`. [Notes](packages/bun/README.md) |
| `caddy` | [caddyserver/caddy](https://github.com/caddyserver/caddy) | amd64, arm64 | `caddy.service` and `caddy-api.service`, Debian layout, not enabled by default |
| `codex` | [openai/codex](https://github.com/openai/codex) | amd64, arm64 | OpenAI Codex CLI. Includes `/etc/codex/config.toml` to disable the update check and the self-updating background daemon. [Notes](packages/codex/README.md) |
| `deno` | [denoland/deno](https://github.com/denoland/deno) | amd64, arm64 | Update with apt/dnf, not `deno upgrade`. [Notes](packages/deno/README.md) |
| `dnsproxy` | [AdguardTeam/dnsproxy](https://github.com/AdguardTeam/dnsproxy) | amd64, arm64 | `dnsproxy.service`, config in `/etc/dnsproxy/config.yaml`, not enabled by default. Replaces the unrelated Debian/Ubuntu `dnsproxy` |
| `ferron` | [ferronweb/ferron](https://github.com/ferronweb/ferron) | amd64, arm64 | `ferron.service`, config in `/etc/ferron.kdl`, not enabled by default |
| `fastfetch` | [fastfetch-cli/fastfetch](https://github.com/fastfetch-cli/fastfetch) | amd64, arm64 | Replaces the distribution's older `fastfetch`; includes `flashfetch` |
| `gitea` | [go-gitea/gitea](https://github.com/go-gitea/gitea) | amd64, arm64 | `gitea.service`, runs as `git`, not enabled by default |
| `golang` | [go.dev](https://go.dev/dl/) | amd64, arm64 | Metapackage for the newest Go (`golang-1.27`); also `go`. See [Go](#go) |
| `golang-1.27`, `golang-1.26` | [go.dev](https://go.dev/dl/) | amd64, arm64 | One Go minor version each, installable side by side; also `go1.27`, `go-1.27`, `golang1.27` |
| `goreleaser` | [goreleaser/goreleaser](https://github.com/goreleaser/goreleaser) | amd64, arm64 | |
| `maddy` | [foxcpp/maddy](https://github.com/foxcpp/maddy) | amd64, arm64 | `maddy.service`, not enabled by default |
| `nodejs` | [nodejs.org](https://nodejs.org/) | amd64, arm64 | Metapackage for the newest LTS (`nodejs-26`); also `nodejs-lts`. See [Node.js](#nodejs) |
| `nodejs-26`, `nodejs-24`, `nodejs-22` | [nodejs.org](https://nodejs.org/) | amd64, arm64 | One LTS line each, with npm, installable side by side; also `nodejs26`, `nodejs24`, `nodejs22` |
| `nfpm` | [goreleaser/nfpm](https://github.com/goreleaser/nfpm) | amd64, arm64 | Packaging tool used by this repository |
| `oha` | [hatoo/oha](https://github.com/hatoo/oha) | amd64, arm64 | HTTP load generator |
| `opencode-cli` | [anomalyco/opencode](https://github.com/anomalyco/opencode) | amd64, arm64 | opencode 2.x CLI; also installable as `opencode`. [Notes](packages/opencode-cli/README.md) |
| `opencode-desktop` | [anomalyco/opencode](https://github.com/anomalyco/opencode) | amd64, arm64 | Desktop app (Electron), its self-updater disabled; replaces upstream's `opencode` desktop package. [Notes](packages/opencode-desktop/README.md) |
| `rclone` | [rclone/rclone](https://github.com/rclone/rclone) | amd64, arm64 | |
| `rdap` | [xtomcom/rdap](https://github.com/xtomcom/rdap) | amd64, arm64 | Replaces Debian/Ubuntu's `rdap` (OpenRDAP). Optional API server: `rdap.service`, config in `/etc/default/rdap`, not enabled by default |
| `rustfs` | [rustfs/rustfs](https://github.com/rustfs/rustfs) | amd64, arm64 | `rustfs.service`, config in `/etc/default/rustfs`, not enabled by default |
| `see` | [sdotee/cli](https://github.com/sdotee/cli) | amd64, arm64 | Also installable as `see-cli` |
| `vaultwarden` | [xtomcom/vaultwarden](https://github.com/xtomcom/vaultwarden) | amd64, arm64 | `vaultwarden.service`, config in `/etc/vaultwarden/vaultwarden.env`, not enabled by default. [Setup notes](packages/vaultwarden/README.md) |
| `versitygw` | [versity/versitygw](https://github.com/versity/versitygw) | amd64, arm64 | `versitygw@.service` template, configs in `/etc/versitygw.d/`, not enabled by default |
| `xcaddy` | [caddyserver/xcaddy](https://github.com/caddyserver/xcaddy) | amd64, arm64 | Requires Go (`golang`) to build Caddy |
| `yadex` | [ustclug/yadex](https://github.com/ustclug/yadex) | amd64 | Upstream does not provide an arm64 build. [Setup notes](packages/yadex/README.md) |
| `yuki` | [ustclug/Yuki](https://github.com/ustclug/Yuki) | amd64 | `yukid` and `yukictl`; upstream does not provide an arm64 build |

Package names, file locations and versions follow Debian and Fedora/EPEL packaging conventions for the same software. Where the distribution provides the same package, this repository provides a newer upstream release, installed through `apt upgrade` / `dnf upgrade`.

Each package tracks selected upstream release branches, such as Go 1.27 and 1.26 or Gitea 28. Only the latest release of each branch is retained; publishing a new release removes older builds. New major versions are added manually after review.

Services are not started during installation. Each service package prints configuration and startup instructions when installed.

To request additional software, [submit a package request](https://github.com/xtomcom/repo/issues/new?template=package_request.yml).

## Supported systems

Support is limited to distribution releases maintained by their vendor, including Debian LTS. RHEL 8 and its rebuilds are unsupported because their RPM versions cannot verify the repository's Ed25519 package signatures. End-of-life releases may remain compatible, but are not tested and do not receive fixes for release-specific issues.

- Debian 12 and 13
- Ubuntu 22.04, 24.04 and 26.04 LTS
- RHEL, Rocky Linux and AlmaLinux 9 and 10

Before publication, each package is tested by installing it on Debian 13, Ubuntu 26.04 and Rocky Linux 10 on both architectures.

Software branches are removed from the repository when they reach upstream end of life.

## Usage

### Quick setup

Run the following command as root on Debian 12+, Ubuntu 22.04+ or RHEL-compatible 9+. The setup script adds DEB822 sources or a `.repo` file as appropriate:

```bash
curl -sL ba.sh/repo | bash
```

For a non-root user with sudo privileges:

```bash
curl -sL ba.sh/repo | sudo bash
```

Install a package using, for example, `apt install rdap` or `dnf install rdap`. The setup script is available at [`scripts/repo.sh`](https://github.com/xtomcom/repo/blob/main/scripts/repo.sh). Manual setup instructions follow.

### Debian / Ubuntu

Debian (via extrepo):

```bash
sudo apt update && sudo apt install extrepo -y
sudo extrepo enable xtom
sudo apt update
# Install any package listed above, for example:
sudo apt install rdap see golang
```

One-line sources format:

```bash
sudo apt install -y lsb-release ca-certificates apt-transport-https curl gnupg dpkg
# Add xTom repository
curl -fsSL https://repo.xtom.com/xtom.key | sudo bash -c 'gpg --dearmor > /usr/share/keyrings/xtom.gpg'
echo "deb [signed-by=/usr/share/keyrings/xtom.gpg] https://repo.xtom.com/deb stable main" | sudo tee /etc/apt/sources.list.d/xtom.list
sudo apt update
# Install any package listed above, for example:
sudo apt install rdap see golang
```

DEB822:

```bash
sudo apt install -y lsb-release ca-certificates apt-transport-https curl gnupg dpkg
curl -fsSL https://repo.xtom.com/xtom.key | sudo bash -c 'gpg --dearmor > /usr/share/keyrings/xtom.gpg'
sudo bash -c 'cat > /etc/apt/sources.list.d/xtom.sources << EOF
Components: main
Architectures: $(dpkg --print-architecture)
Suites: stable
Types: deb
Uris: https://repo.xtom.com/deb
Signed-By: /usr/share/keyrings/xtom.gpg
EOF'
sudo apt update
# Install any package listed above, for example:
sudo apt install rdap see golang
```

There is a single `stable` suite for every Debian and Ubuntu release, because the packaged binaries do not depend on the distribution version.

### RHEL / CentOS / Rocky / Alma / Fedora

```bash
# Add xTom repository
sudo curl -o /etc/yum.repos.d/xtom.repo https://repo.xtom.com/rpm/xtom.repo
# Install any package listed above, for example:
sudo dnf install rdap see golang
```

## Node.js

Each Node.js LTS line has a separate package using official binaries from nodejs.org, verified against the Node.js release signing keys. The installation layout follows Debian and Fedora conventions. All lines include npm and npx. Node.js 22 and 24 also include corepack, which upstream removed in Node.js 25.

| Package | Also known as | Installs |
|---|---|---|
| `nodejs` | `nodejs-lts` | The newest LTS line, currently `nodejs-26` |
| `nodejs-26` | `nodejs26` | Node.js 26.x, supported until 2029-04-30 |
| `nodejs-24` | `nodejs24` | Node.js 24.x, supported until 2028-04-30 |
| `nodejs-22` | `nodejs22` | Node.js 22.x, supported until 2027-04-30 |

```bash
apt install nodejs        # newest LTS, follows future LTS lines too
apt install nodejs-24     # stays on 24.x; upgrades never bring 26
dnf install nodejs22      # aliases work with apt and dnf alike
```

- **Side by side:** each line is installed in `/usr/lib/nodejs-NN` and the lines can be installed together. `node`, `npm`, `npx`, `corepack` and `nodejs` point at the newest installed line through alternatives; `node-24`, `npm-24`, `npx-24` always run that exact line.
- **Switching the default:** `update-alternatives --config node` (Debian/Ubuntu) or `alternatives --config node` (RHEL). npm and npx switch with it. `--auto` restores selection of the latest installed line.
- **Global npm packages** are installed in `/usr/local/lib/node_modules`, with commands in `/usr/local/bin`, as with Debian's npm. Native addons are built for one Node.js version: rebuild them (`npm rebuild -g`) after switching lines.
- **Replacing other Node.js packages:** these packages replace the distribution's `nodejs`/`npm` and NodeSource's `nodejs`. Use `apt install nodejs` (or `apt full-upgrade`) rather than `apt upgrade` for the switch, and remove NodeSource's apt pin (`/etc/apt/preferences.d/nodejs`, `nsolid`) first. Otherwise, apt continues to prefer NodeSource. On RHEL 9, an enabled `nodejs` module stream hides our packages: `dnf module reset nodejs`.
- **End of life:** when a line reaches end of life it leaves the repository. Installed copies continue to work but receive no further updates.
- **Names:** aliases are resolved at install time. `dpkg -l`, `rpm -qa` and removal use the real name, e.g. `apt remove nodejs-24`.

Package details and distribution-specific replacement behavior: [packages/nodejs/README.md](packages/nodejs/README.md).

## Go

Each supported Go minor version has a separate package using official go.dev tarballs verified against SHA-256 checksums. The installation layout follows Debian's `golang-1.NN` packages.

| Package | Also known as | Installs |
|---|---|---|
| `golang` | `go`, and provides `golang-go` | The newest Go, currently `golang-1.27` |
| `golang-1.27` | `golang1.27`, `go1.27`, `go-1.27`, `golang-1.27-go` | Go 1.27.x |
| `golang-1.26` | `golang1.26`, `go1.26`, `go-1.26`, `golang-1.26-go` | Go 1.26.x |

```bash
apt install golang        # newest Go, follows future minor versions too
apt install golang-1.26   # stays on 1.26.x
dnf install go1.26        # aliases work with apt and dnf alike
```

- **Side by side:** GOROOT is `/usr/lib/go-1.NN`. `go`, `gofmt` and `/usr/lib/go` point at the newest installed version through alternatives; `go-1.26` and `gofmt-1.26` always run that version. Go determines GOROOT from the binary path; manual configuration is not required.
- **Switching the default:** `update-alternatives --config go` (Debian/Ubuntu) or `alternatives --config go` (RHEL).
- **Replacing other Go packages:** `golang` replaces the distribution's `golang-go`/`golang-src` (Debian, Ubuntu) and `golang`/`golang-bin` (RHEL), and the single `golang` package this repository published before; a standard upgrade performs the migration. On RHEL, remove `go-toolset` first.
- **End of life:** Go supports the two newest minor versions. When Go 1.28 is released, `golang` moves to `golang-1.28` and `golang-1.26` leaves the repository; installed copies continue to work but receive no further updates.

Details: [packages/golang/README.md](packages/golang/README.md).

## How it works

```
scripts/check.sh    compare upstream releases with versions.json
scripts/build.sh    download, verify, and wrap the upstream binaries with nfpm
scripts/test.sh     install, run and remove the packages in clean containers
scripts/publish.sh  merge into the indexes, drop superseded builds, sign, upload, purge the CDN cache
```

`.github/workflows/update.yml` runs these steps every day. Each package and architecture is built and tested on a native GitHub runner, and a release is only published once all of its architectures have passed. `versions.json` records the published versions, as `VERSION-RELEASE`, so incrementing `RELEASE` republishes the package.

The workflow also accepts a package list for manual runs. `NAME` checks one package for new releases. `NAME@VERSION` builds that exact version. Published filenames are not reused because CDNs and clients cache pool files indefinitely. To publish a packaging fix, increment `RELEASE` in the package's `package.sh`; the next run publishes the revised package.

The `README.md` served at repo.xtom.com is [`site/README.md`](site/README.md), with the package table filled in at publish time. The signing key `xtom.key` on the server is managed manually; the scripts never write it.

### Adding a package

Each package is a directory under `packages/` with:

- `package.sh` sets `UPSTREAM`, `BRANCHES` (the supported release branches, e.g. `(1.27 1.26)`), `ARCHS` and `TEST_CMD`, and defines `prepare VERSION ARCH`, which downloads and verifies the upstream files. It can also override `versions` when the upstream is not a GitHub release, as for Go. Packages with a systemd service also set `SERVICE_TEST`: `scripts/test.sh` then installs them in Debian, Ubuntu and Rocky containers running systemd, verifies that installation does not start the service, configures it according to the installation notice, starts it, tests communication with it and verifies that package removal stops it.
- `nfpm.yaml` is the [nfpm](https://nfpm.goreleaser.com/) package definition.
- When upstream ships both glibc and musl builds, use the glibc one and call `check_glibc` on it in `prepare`: it fails the build if the binary needs a newer glibc than the oldest supported system has (2.34, EL9). Use the musl build only when the glibc one needs more than that. Never ship both.
- Any unit files and maintainer scripts the package needs.
- Optionally a `README.md` with setup notes for users. It stays in this repository and is never packaged.
- A metapackage sets `TEST_DEPS` to the packages it depends on, so `scripts/test.sh` builds and installs them with it. Files shared by several packages (the Node.js lines, the Go versions) are stored in `packages/_shared/NAME/` and are linked into each package directory.

Build and test locally. You need Docker and nfpm (`npm install -g @goreleaser/nfpm`, or `apt install nfpm` from this repository):

```bash
scripts/build.sh rdap 1.1.0
scripts/test.sh rdap 1.1.0 amd64
tests/repo.sh       # end-to-end: publish to a local directory, install and upgrade with apt and dnf
tests/nodejs.sh     # Node.js lines: aliases, side by side, switching, removal, replacing distro/NodeSource
tests/golang.sh     # Go versions: the same, plus the upgrade from the old single golang package
tests/retention.sh  # which builds are kept per branch
```

## Support

For questions or problems, contact [packages@xtom.com](mailto:packages@xtom.com) or [open an issue](https://github.com/xtomcom/repo/issues).

## License

The packaging in this repository is licensed under [MIT](LICENSE). Each package retains and includes its upstream license.
