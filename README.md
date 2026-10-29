# xTom Package Repository

APT and DNF repository at **[repo.xtom.com](https://repo.xtom.com/)** with up-to-date builds of open source server software, for `amd64` and `arm64`.

A GitHub Actions job checks every upstream once a day and publishes new releases automatically.

> [!IMPORTANT]
> **We do not build anything from source.** Every binary in this repository is the official release binary, downloaded from the upstream project's own distribution channel (GitHub Releases, go.dev) and verified against the upstream checksums or signatures wherever upstream publishes them. We only wrap those binaries into `.deb` and `.rpm` packages: install paths, systemd units, system users and default config. The packaging is in [`packages/`](packages/), so you can check exactly what each package contains.

## Packages

| Package | Upstream | Architectures | Notes |
|---|---|---|---|
| `anubis` | [TecharoHQ/anubis](https://github.com/TecharoHQ/anubis) | amd64, arm64 | `anubis@.service` template, not enabled by default |
| `bun` | [oven-sh/bun](https://github.com/oven-sh/bun) | amd64, arm64 | `bun` and `bunx`. Update with apt/dnf, not `bun upgrade`. [Notes](packages/bun/README.md) |
| `caddy` | [caddyserver/caddy](https://github.com/caddyserver/caddy) | amd64, arm64 | `caddy.service` and `caddy-api.service`, Debian layout, not enabled by default |
| `deno` | [denoland/deno](https://github.com/denoland/deno) | amd64, arm64 | Update with apt/dnf, not `deno upgrade`. [Notes](packages/deno/README.md) |
| `dnsproxy` | [AdguardTeam/dnsproxy](https://github.com/AdguardTeam/dnsproxy) | amd64, arm64 | `dnsproxy.service`, config in `/etc/dnsproxy/config.yaml`, not enabled by default. Replaces the unrelated Debian/Ubuntu `dnsproxy` |
| `ferron` | [ferronweb/ferron](https://github.com/ferronweb/ferron) | amd64, arm64 | `ferron.service`, config in `/etc/ferron.kdl`, not enabled by default |
| `gitea` | [go-gitea/gitea](https://github.com/go-gitea/gitea) | amd64, arm64 | `gitea.service`, runs as `git`, not enabled by default |
| `golang` | [go.dev](https://go.dev/dl/) | amd64, arm64 | Metapackage for the newest Go (`golang-1.27`); also `go`. See [Go](#go) |
| `golang-1.27`, `golang-1.26` | [go.dev](https://go.dev/dl/) | amd64, arm64 | One Go minor version each, installable side by side; also `go1.27`, `go-1.27`, `golang1.27` |
| `goreleaser` | [goreleaser/goreleaser](https://github.com/goreleaser/goreleaser) | amd64, arm64 | |
| `maddy` | [foxcpp/maddy](https://github.com/foxcpp/maddy) | amd64, arm64 | `maddy.service`, not enabled by default |
| `nodejs` | [nodejs.org](https://nodejs.org/) | amd64, arm64 | Metapackage for the newest LTS (`nodejs-26`); also `nodejs-lts`. See [Node.js](#nodejs) |
| `nodejs-26`, `nodejs-24`, `nodejs-22` | [nodejs.org](https://nodejs.org/) | amd64, arm64 | One LTS line each, with npm, installable side by side; also `nodejs26`, `nodejs24`, `nodejs22` |
| `nfpm` | [goreleaser/nfpm](https://github.com/goreleaser/nfpm) | amd64, arm64 | The packager this repository is built with |
| `rclone` | [rclone/rclone](https://github.com/rclone/rclone) | amd64, arm64 | |
| `rdap` | [xtomcom/rdap](https://github.com/xtomcom/rdap) | amd64, arm64 | Replaces Debian/Ubuntu's `rdap` (OpenRDAP) |
| `rustfs` | [rustfs/rustfs](https://github.com/rustfs/rustfs) | amd64, arm64 | `rustfs.service`, config in `/etc/default/rustfs`, not enabled by default |
| `see` | [sdotee/cli](https://github.com/sdotee/cli) | amd64, arm64 | Also installable as `see-cli` |
| `vaultwarden` | [xtomcom/vaultwarden](https://github.com/xtomcom/vaultwarden) | amd64, arm64 | `vaultwarden.service`, config in `/etc/vaultwarden/vaultwarden.env`, not enabled by default. [Setup notes](packages/vaultwarden/README.md) |
| `versitygw` | [versity/versitygw](https://github.com/versity/versitygw) | amd64, arm64 | `versitygw@.service` template, configs in `/etc/versitygw.d/`, not enabled by default |
| `xcaddy` | [caddyserver/xcaddy](https://github.com/caddyserver/xcaddy) | amd64, arm64 | Needs Go (`golang`) to build Caddy |
| `yadex` | [ustclug/yadex](https://github.com/ustclug/yadex) | amd64 | Upstream ships no arm64 build. [Setup notes](packages/yadex/README.md) |
| `yuki` | [ustclug/Yuki](https://github.com/ustclug/Yuki) | amd64 | `yukid` and `yukictl`; upstream ships no arm64 build |

Package names, file locations and versions follow Debian's and Fedora/EPEL's own packaging of the same software. When your distribution also ships one of these packages, ours carries the newer upstream release, so a plain `apt upgrade` / `dnf upgrade` moves you to it.

For each package we choose which upstream release branches to carry (for example Go 1.27 and 1.26, Gitea 28) and keep only the newest release of each; older builds are removed when a new one is published. A new major version is added by hand once we have looked at it.

Services are never started on install. The steps to configure and start one are printed when its package is installed.

Want something added? [Request a package](https://github.com/xtomcom/repo/issues/new?template=package_request.yml).

## Supported systems

We only support distribution releases that are still maintained by their vendor (including Debian LTS). RHEL 8 and its rebuilds are not supported: their rpm cannot verify our Ed25519 package signatures. EOL releases may keep working, but we don't test them or fix problems specific to them.

- Debian 12 and 13
- Ubuntu 22.04, 24.04 and 26.04 LTS
- RHEL, Rocky Linux and AlmaLinux 9 and 10

Every package is test-installed on the newest of these (Debian 13, Ubuntu 26.04 and Rocky Linux 10) on both architectures before it is published.

The same rule applies to the software: when an upstream branch reaches end of life, we drop it.

## Usage

### Quick setup

Run as root to add the repository on Debian 12+, Ubuntu 22.04+ or RHEL-compatible 9+ (it picks DEB822 sources or a `.repo` file for you):

```bash
curl -sL ba.sh/repo | bash
```

As a regular user with sudo:

```bash
curl -sL ba.sh/repo | sudo bash
```

Then install any package listed above, e.g. `apt install rdap` or `dnf install rdap`. The script is [`scripts/repo.sh`](https://github.com/xtomcom/repo/blob/main/scripts/repo.sh). To set things up by hand instead, use one of the methods below.

### Debian / Ubuntu

Debian (via extrepo):

```bash
sudo apt update && sudo apt install extrepo -y
sudo extrepo enable xtom
sudo apt update
# Install any package listed above, for example:
sudo apt install rdap see golang
```

One-Line Style:

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

There is a single `stable` suite for every Debian and Ubuntu release, because the packaged binaries don't depend on the distribution version.

### RHEL / CentOS / Rocky / Alma / Fedora

```bash
# Add xTom repository
sudo curl -o /etc/yum.repos.d/xtom.repo https://repo.xtom.com/rpm/xtom.repo
# Install any package listed above, for example:
sudo dnf install rdap see golang
```

## Node.js

Every Node.js LTS line is its own package, built from the official binaries on nodejs.org (signature-checked against the Node.js release keys) and laid out like Debian's and Fedora's packages. npm and npx come with each line, corepack with 22 and 24 (upstream dropped it in Node.js 25).

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

- **Side by side:** each line lives in `/usr/lib/nodejs-NN` and the lines can be installed together. `node`, `npm`, `npx`, `corepack` and `nodejs` point at the newest installed line through alternatives; `node-24`, `npm-24`, `npx-24` always run that exact line.
- **Switching the default:** `update-alternatives --config node` (Debian/Ubuntu) or `alternatives --config node` (RHEL). npm and npx switch with it. `--auto` goes back to the newest.
- **Global npm packages** go to `/usr/local/lib/node_modules`, their commands to `/usr/local/bin`, as with Debian's npm. Native addons are built for one Node.js version: rebuild them (`npm rebuild -g`) after switching lines.
- **Replacing other Node.js packages:** ours replace the distribution's `nodejs`/`npm` and NodeSource's `nodejs`. Use `apt install nodejs` (or `apt full-upgrade`) rather than `apt upgrade` for the switch, and remove NodeSource's apt pin (`/etc/apt/preferences.d/nodejs`, `nsolid`) first, or apt keeps preferring NodeSource. On RHEL 9, an enabled `nodejs` module stream hides our packages: `dnf module reset nodejs`.
- **End of life:** when a line reaches end of life it leaves the repository. Installed copies keep working without updates.
- **Names:** aliases are resolved at install time. `dpkg -l`, `rpm -qa` and removal use the real name, e.g. `apt remove nodejs-24`.

Details, including what exactly is replaced on each distribution: [packages/nodejs/README.md](packages/nodejs/README.md).

## Go

Every supported Go minor version is its own package, from the official go.dev tarballs (SHA-256 checked), laid out like Debian's `golang-1.NN` packages.

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

- **Side by side:** GOROOT is `/usr/lib/go-1.NN`. `go`, `gofmt` and `/usr/lib/go` point at the newest installed version through alternatives; `go-1.26` and `gofmt-1.26` always run that version. Go finds its GOROOT from the binary, so there is nothing to set.
- **Switching the default:** `update-alternatives --config go` (Debian/Ubuntu) or `alternatives --config go` (RHEL).
- **Replacing other Go packages:** `golang` replaces the distribution's `golang-go`/`golang-src` (Debian, Ubuntu) and `golang`/`golang-bin` (RHEL), and the single `golang` package this repository published before; a normal upgrade moves you over. On RHEL, remove `go-toolset` first.
- **End of life:** Go supports the two newest minor versions. When Go 1.28 comes out, `golang` moves to `golang-1.28` and `golang-1.26` leaves the repository; installed copies keep working without updates.

Details: [packages/golang/README.md](packages/golang/README.md).

## How it works

```
scripts/check.sh    compare upstream releases with versions.json
scripts/build.sh    download, verify, and wrap the upstream binaries with nfpm
scripts/test.sh     install, run and remove the packages in clean containers
scripts/publish.sh  merge into the indexes, drop superseded builds, sign, upload, purge the CDN cache
```

`.github/workflows/update.yml` runs these steps every day. Each package and architecture is built and tested on a native GitHub runner, and a release is only published once all of its architectures have passed. `versions.json` records what the repository holds, as `VERSION-RELEASE`, so bumping `RELEASE` in a package republishes it.

You can also run the workflow by hand with a list of packages. `NAME` checks one package for new releases. `NAME@VERSION` builds that exact version. A file name is never published twice, because CDNs and clients cache pool files forever: to ship a packaging fix, bump `RELEASE` in the package's `package.sh`, and the next run publishes it.

The `README.md` served at repo.xtom.com is [`site/README.md`](site/README.md), with the package table filled in at publish time. The signing key `xtom.key` on the server is managed by hand; the scripts never write it.

### Adding a package

Each package is a directory under `packages/` with:

- `package.sh` sets `UPSTREAM`, `BRANCHES` (the release branches we carry, e.g. `(1.27 1.26)`), `ARCHS` and `TEST_CMD`, and defines `prepare VERSION ARCH`, which downloads and verifies the upstream files. It can also override `versions` when the upstream isn't a GitHub release, as for Go. Packages with a systemd service also set `SERVICE_TEST`: `scripts/test.sh` then installs them in Debian, Ubuntu and Rocky containers running systemd, checks that nothing starts on install, runs the test (which configures the service the way the install notice says, starts it and talks to it) and checks that removal stops it.
- `nfpm.yaml` is the [nfpm](https://nfpm.goreleaser.com/) package definition.
- When upstream ships both glibc and musl builds, use the glibc one and call `check_glibc` on it in `prepare`: it fails the build if the binary needs a newer glibc than the oldest supported system has (2.34, EL9). Use the musl build only when the glibc one needs more than that. Never ship both.
- Any unit files and maintainer scripts the package needs.
- Optionally a `README.md` with setup notes for users. It stays in this repository and is never packaged.
- A metapackage sets `TEST_DEPS` to the packages it depends on, so `scripts/test.sh` builds and installs them with it. Files shared by several packages (the Node.js lines, the Go versions) live in `packages/_shared/NAME/` and are linked into each package directory.

Build and test locally. You need Docker and nfpm (`npm install -g @goreleaser/nfpm`, or `apt install nfpm` from this repository):

```bash
scripts/build.sh rdap 1.0.9
scripts/test.sh rdap 1.0.9 amd64
tests/repo.sh       # end-to-end: publish to a local directory, install and upgrade with apt and dnf
tests/nodejs.sh     # Node.js lines: aliases, side by side, switching, removal, replacing distro/NodeSource
tests/golang.sh     # Go versions: the same, plus the upgrade from the old single golang package
tests/retention.sh  # which builds are kept per branch
```

## License

The packaging in this repository is [MIT](LICENSE) licensed. Each package keeps its upstream license, which ships inside the package.
