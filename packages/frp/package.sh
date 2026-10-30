# shellcheck shell=bash
UPSTREAM=fatedier/frp
BRANCHES=(0)
TEST_CMD='
frps --version
frpc --version
test -f /usr/lib/systemd/system/frps.service
test -f /usr/lib/systemd/system/frpc.service
if command -v dpkg >/dev/null; then dpkg -L frp; else rpm -ql frp; fi | grep -q /usr/share/doc/frp/frps_full_example.toml
getent passwd frp
test "$(stat -c %U:%G:%a /etc/frp/frps.toml)" = root:frp:640
test "$(stat -c %U:%G:%a /etc/frp/frpc.toml)" = root:frp:640
'
# Unedited, frps would accept anyone on 0.0.0.0:7000, so the units refuse to
# start until the configuration has a setting. Then a server and a client on
# the same machine tunnel an echo service.
SERVICE_TEST='
! systemctl start frps
! systemctl is-active frps
journalctl -u frps --no-pager | grep -q "has no settings yet"
cat >/etc/frp/frps.toml <<TOML
bindAddr = "127.0.0.1"
bindPort = 7000
auth.token = "test-token"
TOML
cat >/etc/frp/frpc.toml <<TOML
serverAddr = "127.0.0.1"
serverPort = 7000
auth.token = "test-token"
[[proxies]]
name = "echo"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 6000
TOML
systemd-run --unit echo systemd-socket-activate -l 127.0.0.1:8080 --inetd -a cat
systemctl start frps frpc
r=
for _ in $(seq 20); do
  r=$(exec 3<>/dev/tcp/127.0.0.1/6000 && echo hello >&3 && timeout 2 head -n1 <&3) && [ "$r" = hello ] && break
  sleep 1
done
journalctl -u frps -u frpc --no-pager | tail -n 10
[ "$r" = hello ]
for u in frps frpc; do
  test "$(stat -c %U "/proc/$(systemctl show -p MainPID --value $u)")" = frp
done
'

prepare() {
  local version=$1 dir=frp_$1_linux_$2 raw=https://raw.githubusercontent.com/$UPSTREAM/v$1
  download "https://github.com/$UPSTREAM/releases/download/v$version/frp_sha256_checksums.txt" dl/sums.txt
  download "https://github.com/$UPSTREAM/releases/download/v$version/$dir.tar.gz" "dl/$dir.tar.gz"
  verify_sums dl/sums.txt "dl/$dir.tar.gz"
  tar -xzf "dl/$dir.tar.gz" -C dl
  check_glibc "dl/$dir/frps" "dl/$dir/frpc"
  install -Dm755 "dl/$dir/frps" frps
  install -Dm755 "dl/$dir/frpc" frpc
  mv "dl/$dir/LICENSE" LICENSE
  download "$raw/conf/frps_full_example.toml" frps_full_example.toml
  download "$raw/conf/frpc_full_example.toml" frpc_full_example.toml
}
