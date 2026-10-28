# xTom Package Repository

APT and DNF repository at **[repo.xtom.com](https://repo.xtom.com/)** with up-to-date builds of open source server software, for `amd64` and `arm64`.

A GitHub Actions job checks every upstream once a day and publishes new releases automatically.

> [!IMPORTANT]
> **We do not build anything from source.** Every binary in this repository is the official release binary, downloaded from the upstream project's own distribution channel (GitHub Releases, go.dev) and verified against the upstream checksums or signatures wherever upstream publishes them. We only wrap those binaries into `.deb` and `.rpm` packages: install paths, systemd units, system users and default config. The packaging is in [`packages/`](packages/), so you can check exactly what each package contains.

## Packages

| Package | Upstream | Architectures | Notes |
|---|---|---|---|
| `anubis` | [TecharoHQ/anubis](https://github.com/TecharoHQ/anubis) | amd64, arm64 | `anubis@.service` template, not enabled by default |
| `dnsproxy` | [AdguardTeam/dnsproxy](https://github.com/AdguardTeam/dnsproxy) | amd64, arm64 | `dnsproxy.service`, config in `/etc/dnsproxy/config.yaml`, not enabled by default. Replaces the unrelated Debian/Ubuntu `dnsproxy` |
| `gitea` | [go-gitea/gitea](https://github.com/go-gitea/gitea) | amd64, arm64 | `gitea.service`, runs as `git`, not enabled by default |
| `golang` | [go.dev](https://go.dev/dl/) | amd64, arm64 | Replaces the distribution's Go; also installable as `go` |
| `maddy` | [foxcpp/maddy](https://github.com/foxcpp/maddy) | amd64, arm64 | `maddy.service`, not enabled by default |
| `nfpm` | [goreleaser/nfpm](https://github.com/goreleaser/nfpm) | amd64, arm64 | The packager this repository is built with |
| `rclone` | [rclone/rclone](https://github.com/rclone/rclone) | amd64, arm64 | |
| `rdap` | [xtomcom/rdap](https://github.com/xtomcom/rdap) | amd64, arm64 | Replaces Debian/Ubuntu's `rdap` (OpenRDAP) |
| `see` | [sdotee/cli](https://github.com/sdotee/cli) | amd64, arm64 | Also installable as `see-cli` |
| `yadex` | [ustclug/yadex](https://github.com/ustclug/yadex) | amd64 | Upstream ships no arm64 build |
| `yuki` | [ustclug/Yuki](https://github.com/ustclug/Yuki) | amd64 | `yukid` and `yukictl`; upstream ships no arm64 build |

Package names, file locations and versions follow Debian's and Fedora/EPEL's own packaging of the same software. When your distribution also ships one of these packages, ours carries the newer upstream release, so a plain `apt upgrade` / `dnf upgrade` moves you to it.

For each package we choose which upstream release branches to carry (for example Go 1.27 and 1.26, Gitea 28) and keep only the newest release of each; older builds are removed when a new one is published. A new major version is added by hand once we have looked at it.

Services are never started on install. The steps to configure and start one are printed when its package is installed.

Want something added? [Request a package](https://github.com/xtomcom/repo/issues/new?template=package_request.yml).

## Supported systems

We only support distribution releases that are still maintained by their vendor (including Debian LTS). EOL releases may keep working, but we don't test them or fix problems specific to them.

- Debian 12 and 13
- Ubuntu 22.04, 24.04 and 26.04 LTS
- RHEL, Rocky Linux and AlmaLinux 8, 9 and 10

Every package is test-installed on the newest of these (Debian 13, Ubuntu 26.04 and Rocky Linux 10) on both architectures before it is published.

The same rule applies to the software: when an upstream branch reaches end of life, we drop it.

## Usage

### Quick setup

Run as root to add the repository on Debian 12+, Ubuntu 22.04+ or RHEL-compatible 8+ (it picks DEB822 sources or a `.repo` file for you):

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

## How it works

```
scripts/check.sh    compare upstream releases with versions.json
scripts/build.sh    download, verify, and wrap the upstream binaries with nfpm
scripts/test.sh     install, run and remove the packages in clean containers
scripts/publish.sh  merge into the indexes, drop superseded builds, sign, upload, purge the CDN cache
```

`.github/workflows/update.yml` runs these steps every day. Each package and architecture is built and tested on a native GitHub runner, and a release is only published once all of its architectures have passed. `versions.json` records what the repository holds.

You can also run the workflow by hand with a list of packages. `NAME` checks one package for new releases. `NAME@VERSION` builds that exact version. A file name is never published twice, because CDNs and clients cache pool files forever: to ship a packaging fix, bump `RELEASE` in the package's `package.sh` first.

The `README.md` served at repo.xtom.com is [`site/README.md`](site/README.md), with the package table filled in at publish time. The signing key `xtom.key` on the server is managed by hand; the scripts never write it.

### Adding a package

Each package is a directory under `packages/` with:

- `package.sh` sets `UPSTREAM`, `BRANCHES` (the release branches we carry, e.g. `(1.27 1.26)`), `ARCHS` and `TEST_CMD`, and defines `prepare VERSION ARCH`, which downloads and verifies the upstream files. It can also override `versions` when the upstream isn't a GitHub release, as for Go.
- `nfpm.yaml` is the [nfpm](https://nfpm.goreleaser.com/) package definition.
- Any unit files and maintainer scripts the package needs.

Build and test locally. You need Docker and nfpm (`npm install -g @goreleaser/nfpm`, or `apt install nfpm` from this repository):

```bash
scripts/build.sh rdap 1.0.9
scripts/test.sh rdap 1.0.9 amd64
tests/repo.sh       # end-to-end: publish to a local directory, install and upgrade with apt and dnf
tests/retention.sh  # which builds are kept per branch
```

## License

The packaging in this repository is [MIT](LICENSE) licensed. Each package keeps its upstream license, which ships inside the package.
