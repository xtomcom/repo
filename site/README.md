# xTom Package Repository

Packages of open source server software for Debian, Ubuntu and RHEL-compatible systems on `amd64` and `arm64`.

Packages use official upstream release binaries, verified against upstream checksums or signatures where available. Binaries are not compiled from source. Repository source and package definitions are available on [GitHub](https://github.com/xtomcom/repo).

## Packages

<!-- packages -->

## Supported systems

- Debian 12 and 13
- Ubuntu 22.04, 24.04 and 26.04 LTS
- RHEL, Rocky Linux and AlmaLinux 9 and 10

Support is limited to distribution releases maintained by their vendor.

## Quick setup

Run the following command as root on Debian 12+, Ubuntu 22.04+ or RHEL-compatible 9+. The setup script adds DEB822 sources or a `.repo` file as appropriate:

```bash
curl -sL ba.sh/repo | bash
```

For a non-root user with sudo privileges:

```bash
curl -sL ba.sh/repo | sudo bash
```

Install a package using, for example, `apt install rdap` or `dnf install rdap`. The setup script is available at [`scripts/repo.sh`](https://github.com/xtomcom/repo/blob/main/scripts/repo.sh). Manual setup instructions follow.

## Debian / Ubuntu

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

## RHEL / CentOS / Rocky / Alma / Fedora

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

Package details and distribution-specific replacement behavior: [packages/nodejs/README.md](https://github.com/xtomcom/repo/blob/main/packages/nodejs/README.md).

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

Details: [packages/golang/README.md](https://github.com/xtomcom/repo/blob/main/packages/golang/README.md).

## Services

Packages that ship a service (anubis, caddy, dnsproxy, ferron, gitea, maddy, rdap, rustfs, vaultwarden, versitygw, yadex, yuki) do not start it on install. Edit the configuration first, then enable it with `systemctl enable --now <service>`. The exact steps are printed when the package is installed.

## Support

For questions or problems, contact [packages@xtom.com](mailto:packages@xtom.com) or [open an issue](https://github.com/xtomcom/repo/issues). Package requests can also be submitted through Issues.
