#!/usr/bin/env bash
# Adds the xTom package repository (https://repo.xtom.com) to this system.
#
#   curl -sL ba.sh/repo | bash
#
# Debian 12+ and Ubuntu 22.04+ get /etc/apt/sources.list.d/xtom.sources;
# RHEL, Rocky Linux, AlmaLinux, CentOS Stream and Oracle Linux 9+ get
# /etc/yum.repos.d/xtom.repo. Must run as root. Safe to run again.

set -euo pipefail

REPO_URL=${REPO_URL:-https://repo.xtom.com}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || fail "run this as root, e.g.: curl -sL ba.sh/repo | sudo bash"
[[ -r /etc/os-release ]] || fail "cannot detect the distribution: /etc/os-release is missing"
# shellcheck source=/dev/null
. /etc/os-release

# version_ge A B: whether version A >= B, comparing numeric parts.
version_ge() { [[ $(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1) == "$2" ]]; }

setup_apt() {
  local arch keyring=/usr/share/keyrings/xtom.asc sources=/etc/apt/sources.list.d/xtom.sources
  command -v curl >/dev/null || fail "curl is required: apt install curl"
  arch=$(dpkg --print-architecture)
  [[ $arch == amd64 || $arch == arm64 ]] || fail "unsupported architecture $arch (amd64 and arm64 only)"

  if [[ -f /etc/apt/sources.list.d/extrepo_xtom.sources ]]; then
    echo "The xTom repository is already enabled via extrepo."
    return
  fi

  curl -fsSL "$REPO_URL/xtom.key" -o "$keyring.tmp" || fail "cannot download $REPO_URL/xtom.key"
  mv "$keyring.tmp" "$keyring"
  chmod 644 "$keyring"
  # Replace an older one-line style entry, so apt doesn't see the repo twice.
  rm -f /etc/apt/sources.list.d/xtom.list
  cat > "$sources" <<EOF
Types: deb
URIs: $REPO_URL/deb
Suites: stable
Components: main
Architectures: $arch
Signed-By: $keyring
EOF

  apt-get update -qq || fail "apt-get update failed, see the messages above"
  echo "The xTom repository has been added. Install packages with: apt install <package>"
}

setup_dnf() {
  command -v curl >/dev/null || fail "curl is required: dnf install curl"
  case $(uname -m) in x86_64 | aarch64) ;; *) fail "unsupported architecture $(uname -m) (x86_64 and aarch64 only)" ;; esac
  curl -fsSL "$REPO_URL/rpm/xtom.repo" -o /etc/yum.repos.d/xtom.repo.tmp ||
    fail "cannot download $REPO_URL/rpm/xtom.repo"
  mv /etc/yum.repos.d/xtom.repo.tmp /etc/yum.repos.d/xtom.repo
  chmod 644 /etc/yum.repos.d/xtom.repo

  # Imports the signing key and checks that the repository is reachable.
  dnf -y -q makecache --repo xtom || fail "dnf makecache failed, see the messages above"
  echo "The xTom repository has been added. Install packages with: dnf install <package>"
}

case ${ID:-} in
  debian)
    # Testing and unstable have no VERSION_ID; they are newer than any release.
    [[ -z ${VERSION_ID:-} ]] || version_ge "$VERSION_ID" 12 ||
      fail "Debian $VERSION_ID is not supported, Debian 12 or newer is required"
    setup_apt
    ;;
  ubuntu)
    version_ge "${VERSION_ID:-0}" 22.04 ||
      fail "Ubuntu ${VERSION_ID:-unknown} is not supported, Ubuntu 22.04 or newer is required"
    setup_apt
    ;;
  rhel | rocky | almalinux | centos | ol)
    # rpm 4.14 in EL8 cannot verify Ed25519 signatures, so it rejects our packages.
    version_ge "${VERSION_ID%%.*}" 9 ||
      fail "$NAME $VERSION_ID is not supported, version 9 or newer is required"
    setup_dnf
    ;;
  *)
    fail "${PRETTY_NAME:-this distribution} is not supported (Debian, Ubuntu and RHEL-compatible systems only)"
    ;;
esac
