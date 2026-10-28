# shellcheck shell=bash
UPSTREAM=TecharoHQ/anubis
BRANCHES=(1)
TEST_CMD='
anubis --version | grep "^Anubis v"
anubis-robots2policy -h 2>&1 | grep -q robots.txt
test -f /usr/lib/systemd/system/anubis@.service
grep -q "^TARGET=" /etc/anubis/default.env
'

prepare() {
  local version=$1 dir=anubis-$1-linux-$2
  local url=https://github.com/$UPSTREAM/releases/download/v$version/$dir.tar.gz
  download "$url" "dl/$dir.tar.gz"
  download "$url.asc" "dl/$dir.tar.gz.asc"
  # Detached signature by "Techaro Packages Signatures <gpg+packages@techaro.lol>".
  gpg --dearmor <techaro-packages.asc >dl/keyring.gpg
  gpgv --keyring "$PWD/dl/keyring.gpg" "dl/$dir.tar.gz.asc" "dl/$dir.tar.gz" ||
    die "bad signature for $dir.tar.gz"
  tar -xzf "dl/$dir.tar.gz" -C dl
  install -Dm755 "dl/$dir/bin/anubis" anubis
  install -Dm755 "dl/$dir/bin/anubis-robots2policy" anubis-robots2policy
  mv "dl/$dir/README.md" "dl/$dir/doc/LICENSE" "dl/$dir/doc/botPolicies.yaml" "dl/$dir/doc/data" .
  # Unit and default instance config as shipped in upstream's own deb/rpm.
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/run/anubis@.service" anubis@.service
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/run/default.env" default.env
}
