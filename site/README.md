# xTom Package Repository

Up-to-date builds of open source server software for Debian, Ubuntu and RHEL-compatible systems, on `amd64` and `arm64`.

Every binary is the official upstream release, verified against upstream checksums or signatures where they exist. Nothing is rebuilt from source; we only package it. Source and packaging: https://github.com/xtomcom/repo

## Packages

<!-- packages -->

## Supported systems

- Debian 12 and 13
- Ubuntu 22.04, 24.04 and 26.04 LTS
- RHEL, Rocky Linux and AlmaLinux 9 and 10

We support only releases that their vendor still maintains.

## Quick setup

Run as root to add the repository on Debian 12+, Ubuntu 22.04+ or RHEL-compatible 9+ (it picks DEB822 sources or a `.repo` file for you):

```bash
curl -sL ba.sh/repo | bash
```

As a regular user with sudo:

```bash
curl -sL ba.sh/repo | sudo bash
```

Then install any package listed above, e.g. `apt install rdap` or `dnf install rdap`. The script is [`scripts/repo.sh`](https://github.com/xtomcom/repo/blob/main/scripts/repo.sh). To set things up by hand instead, use one of the methods below.

## Debian / Ubuntu

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

## RHEL / CentOS / Rocky / Alma / Fedora

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

Details, including what exactly is replaced on each distribution: [packages/nodejs/README.md](https://github.com/xtomcom/repo/blob/main/packages/nodejs/README.md).

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

Details: [packages/golang/README.md](https://github.com/xtomcom/repo/blob/main/packages/golang/README.md).

## Services

Packages that ship a service (anubis, caddy, dnsproxy, ferron, gitea, maddy, rustfs, vaultwarden, versitygw, yadex, yuki) do not start it on install. Edit the configuration first, then enable it with `systemctl enable --now <service>`. The exact steps are printed when the package is installed.

## Issues

Packaging problems and package requests: https://github.com/xtomcom/repo/issues
