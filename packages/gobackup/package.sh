# shellcheck shell=bash
UPSTREAM=gobackup/gobackup
BRANCHES=(3)
TEST_CMD='
gobackup --version
test -f /usr/lib/systemd/system/gobackup.service
test "$(stat -c %U:%G:%a /etc/gobackup/gobackup.yml)" = root:root:600
'
# Without a model the service exits. With one, the web API on 127.0.0.1 runs a
# backup of a file into local storage.
SERVICE_TEST='
systemctl start gobackup
for _ in $(seq 10); do systemctl is-active -q gobackup || break; sleep 1; done
! systemctl is-active -q gobackup
journalctl -u gobackup --no-pager | grep -q "no model found"
cat >>/etc/gobackup/gobackup.yml <<YAML
  test:
    storages:
      local:
        type: local
        path: /var/backups/gobackup
    archive:
      includes:
        - /etc/hostname
YAML
systemctl reset-failed gobackup
systemctl start gobackup
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:2703/status
curl -fsS -X POST -H "Content-Type: application/json" -d "{\"model\":\"test\"}" http://127.0.0.1:2703/api/perform
f=
for _ in $(seq 20); do
  f=$(find /var/backups/gobackup -name "*.tar*" | head -n1)
  [ -n "$f" ] && break
  sleep 1
done
journalctl -u gobackup --no-pager | tail -n 20
# The backup holds the archive of the included files.
tar -xOf "$f" test/archive.tar | tar -t | grep -qx /etc/hostname
test "$(stat -c %a "$f")" = 600
grep -q "Store succeeded" /var/lib/gobackup/gobackup.log
'

prepare() {
  local version=$1 tarball=gobackup-linux-$2.tar.gz
  download "https://github.com/$UPSTREAM/releases/download/v$version/gobackup_${version}_checksums.txt" dl/sums.txt
  download "https://github.com/$UPSTREAM/releases/download/v$version/$tarball" "dl/$tarball"
  verify_sums dl/sums.txt "dl/$tarball"
  mkdir dl/x
  tar -xzf "dl/$tarball" -C dl/x
  check_glibc dl/x/gobackup
  install -Dm755 dl/x/gobackup gobackup
  mv dl/x/LICENSE LICENSE
}
