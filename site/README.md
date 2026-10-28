# xTom Package Repository

Up-to-date builds of open source server software for Debian, Ubuntu and RHEL-compatible systems, on `amd64` and `arm64`.

Every binary is the official upstream release, verified against upstream checksums or signatures where they exist. Nothing is rebuilt from source; we only package it. Source and packaging: https://github.com/xtomcom/repo

## Packages

<!-- packages -->

## Supported systems

- Debian 12 and 13
- Ubuntu 22.04, 24.04 and 26.04 LTS
- RHEL, Rocky Linux and AlmaLinux 8, 9 and 10

We support only releases that their vendor still maintains.

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

## Services

Packages that ship a service (anubis, dnsproxy, gitea, maddy, yadex, yuki) do not start it on install. Edit the configuration first, then enable it with `systemctl enable --now <service>`. The exact steps are printed when the package is installed.

## Issues

Packaging problems and package requests: https://github.com/xtomcom/repo/issues
