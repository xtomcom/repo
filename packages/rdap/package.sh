# shellcheck shell=bash
UPSTREAM=xtomcom/rdap
BRANCHES=(1)
TEST_CMD='
rdap --version
test -f /usr/lib/systemd/system/rdap.service
test "$(stat -c %a /etc/default/rdap)" = 600
'
SERVICE_TEST='
systemctl start rdap
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:8888/healthz | grep -q "\"ok\""
curl -fsS http://127.0.0.1:8888/version | grep -q "1\."
# With a token in /etc/default/rdap, queries need it; /healthz stays open.
echo RDAP_API_TOKEN=secret >> /etc/default/rdap
systemctl restart rdap
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:8888/healthz >/dev/null
test "$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8888/version)" = 401
curl -fsS -H "Authorization: Bearer secret" http://127.0.0.1:8888/version >/dev/null
'

prepare() {
  local version=$1 file raw=https://raw.githubusercontent.com/$UPSTREAM/v$1
  file=rdap-$version-linux-$(rpm_arch "$2")
  download "https://github.com/$UPSTREAM/releases/download/v$version/SHA256SUMS" dl/SHA256SUMS
  download "https://github.com/$UPSTREAM/releases/download/v$version/$file" "dl/$file"
  verify_sums dl/SHA256SUMS "dl/$file"
  check_glibc "dl/$file"
  install -Dm755 "dl/$file" rdap
  download "$raw/LICENSE" LICENSE
  # Unit and settings as in upstream's own deb and rpm (Cargo.toml metadata).
  download "$raw/packaging/rdap.service" rdap.service
  download "$raw/packaging/rdap.env" rdap.env
}
