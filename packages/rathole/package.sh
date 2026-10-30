# shellcheck shell=bash
UPSTREAM=rathole-org/rathole
BRANCHES=(0)
TEST_CMD='
rathole --help | head -n1 | grep -q "^rathole v"
test -f /usr/lib/systemd/system/rathole-server.service
test -f /usr/lib/systemd/system/rathole-client.service
getent passwd rathole
test "$(stat -c %U:%G:%a /etc/rathole/server.toml)" = root:rathole:640
test "$(stat -c %U:%G:%a /etc/rathole/client.toml)" = root:rathole:640
'
# A server and a client on the same machine, as the configuration files'
# comments describe, tunnelling an echo service.
SERVICE_TEST='
cat >/etc/rathole/server.toml <<TOML
[server]
bind_addr = "127.0.0.1:2333"
default_token = "test-token"
[server.services.echo]
bind_addr = "127.0.0.1:5202"
TOML
cat >/etc/rathole/client.toml <<TOML
[client]
remote_addr = "127.0.0.1:2333"
default_token = "test-token"
[client.services.echo]
local_addr = "127.0.0.1:8080"
TOML
systemd-run --unit echo systemd-socket-activate -l 127.0.0.1:8080 --inetd -a cat
systemctl start rathole-server rathole-client
r=
for _ in $(seq 20); do
  r=$(exec 3<>/dev/tcp/127.0.0.1/5202 && echo hello >&3 && timeout 2 head -n1 <&3) && [ "$r" = hello ] && break
  sleep 1
done
journalctl -u rathole-server -u rathole-client --no-pager | tail -n 10
[ "$r" = hello ]
for u in rathole-server rathole-client; do
  test "$(stat -c %U "/proc/$(systemctl show -p MainPID --value $u)")" = rathole
done
'

prepare() {
  local version=$1 target sum
  # glibc build on amd64 (statically linked anyway); upstream has only musl for arm64.
  case $2 in amd64) target=x86_64-unknown-linux-gnu ;; arm64) target=aarch64-unknown-linux-musl ;; esac
  # Upstream publishes no checksums, and GitHub recorded no digests for these
  # 2023 assets, so the hashes are pinned here; a new release needs new ones.
  case $version/$target in
    0.5.0/x86_64-unknown-linux-gnu) sum=3e7d0d0f365120cd3cd351d147d1a12ee960c8068b464d4dd533a3821873b80e ;;
    0.5.0/aarch64-unknown-linux-musl) sum=fa4a6fc63d86f8f1faa7c103a845e4715ce79a048455c0eec897b27237576564 ;;
    *) die "no pinned sha256 for rathole-$target.zip $version; add it to packages/rathole/package.sh" ;;
  esac
  download "https://github.com/$UPSTREAM/releases/download/v$version/rathole-$target.zip" "dl/rathole-$target.zip"
  verify_sha256 "dl/rathole-$target.zip" "$sum"
  unzip -q "dl/rathole-$target.zip" -d dl
  check_glibc dl/rathole
  install -Dm755 dl/rathole rathole
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE" LICENSE
}
