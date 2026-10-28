# shellcheck shell=bash
UPSTREAM=AdguardTeam/dnsproxy
BRANCHES=(0)
TEST_CMD='
dnsproxy --version | grep "^dnsproxy version v"
test -f /usr/lib/systemd/system/dnsproxy.service
grep -q "^upstream:" /etc/dnsproxy/config.yaml
'

prepare() {
  local version=$1 file=dnsproxy-linux-$2-v$1.tar.gz
  # Upstream publishes no checksums or signatures for release assets.
  download "https://github.com/$UPSTREAM/releases/download/v$version/$file" "dl/$file"
  tar -xzf "dl/$file" -C dl
  install -Dm755 "dl/linux-$2/dnsproxy" dnsproxy
  mv "dl/linux-$2/config.dist.yaml" config.yaml
  mv "dl/linux-$2/LICENSE" "dl/linux-$2/README.md" .
}
