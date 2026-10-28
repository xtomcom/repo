# shellcheck shell=bash
UPSTREAM=AdguardTeam/dnsproxy
BRANCHES=(0)
RELEASE=2
TEST_CMD='
dnsproxy --version | grep "^dnsproxy version v"
test -f /usr/lib/systemd/system/dnsproxy.service
grep -q "^upstream:" /etc/dnsproxy/config.yaml
'
# Keep port 53 (needs the unit's CAP_NET_BIND_SERVICE) but only on loopback, and
# ask for localhost, which dnsproxy answers from /etc/hosts without an upstream.
SERVICE_TEST='
sed -i "s/\"0.0.0.0\"/\"127.0.0.1\"/" /etc/dnsproxy/config.yaml
grep -A1 "^listen-addrs:" /etc/dnsproxy/config.yaml | grep -q 127.0.0.1
systemctl start dnsproxy
query() {
  exec 3<>/dev/udp/127.0.0.1/53
  printf "\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x09localhost\x00\x00\x01\x00\x01" >&3
  timeout 2 dd bs=512 count=1 <&3 2>/dev/null | od -An -tx1 | tr -d " \n"
  exec 3>&-
}
for _ in 1 2 3 4 5; do r=$(query || true); [ -n "$r" ] && break; sleep 1; done
# Same ID, NOERROR with one answer, and the answer is 127.0.0.1.
[[ $r == 12348180000100010000* && $r == *7f000001 ]]
systemctl is-active dnsproxy
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
