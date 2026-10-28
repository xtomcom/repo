# shellcheck shell=bash
UPSTREAM=rustfs/rustfs
BRANCHES=(1)
TEST_CMD='rustfs --version | grep "^rustfs 1\."
test -f /usr/lib/systemd/system/rustfs.service
grep -q "^ExecStart=/usr/bin/rustfs server$" /usr/lib/systemd/system/rustfs.service
getent passwd rustfs
test "$(stat -c %U:%G /data/rustfs)" = rustfs:rustfs
test "$(stat -c %a /etc/default/rustfs)" = 600
cd /opt/rustfs
runuser -u rustfs -- env RUSTFS_ADDRESS=127.0.0.1:9000 RUSTFS_CONSOLE_ENABLE=false \
  RUSTFS_ACCESS_KEY=xtomtest RUSTFS_SECRET_KEY=xtomtestsecret rustfs server /data/rustfs &
pid=$!
for i in $(seq 60); do (exec 3<>/dev/tcp/127.0.0.1/9000) 2>/dev/null && break; sleep 1; done
(exec 3<>/dev/tcp/127.0.0.1/9000)
kill $pid'
SERVICE_TEST='
# The untouched /etc/default/rustfs sets no volume, so the unit must not come up.
! systemctl start rustfs
journalctl -u rustfs | grep -q "<VOLUMES>"
systemctl stop rustfs
# The minimal settings the install notice asks for.
cat >>/etc/default/rustfs <<EOF
RUSTFS_VOLUMES="/data/rustfs"
RUSTFS_ACCESS_KEY=xtomtest
RUSTFS_SECRET_KEY=xtomtestsecret
EOF
systemctl start rustfs
curl -sS --retry 5 --retry-connrefused http://127.0.0.1:9000/ | grep -q "<Code>AccessDenied</Code>"
test "$(stat -c %U /proc/$(systemctl show -P MainPID rustfs))" = rustfs
# Signed S3 requests with the configured keys land in the configured volume.
s3() { curl -fsS --aws-sigv4 aws:amz:us-east-1:s3 --user xtomtest:xtomtestsecret "$@"; }
s3 -X PUT http://127.0.0.1:9000/xtom-test
s3 -X PUT --data-binary hello http://127.0.0.1:9000/xtom-test/hello.txt
test "$(s3 http://127.0.0.1:9000/xtom-test/hello.txt)" = hello
test "$(stat -c %U /data/rustfs/xtom-test/hello.txt/xl.meta)" = rustfs
'

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/$1 raw=https://raw.githubusercontent.com/$UPSTREAM/$1 file
  file=rustfs-linux-$(rpm_arch "$2")-gnu-v$version.zip
  download "$base/SHA256SUMS" dl/SHA256SUMS
  download "$base/$file" "dl/$file"
  verify_sums dl/SHA256SUMS "dl/$file"
  # The zip also holds rustfs.cpu-symbol-catalog.{json,sha256}: release tooling
  # for the hosted RustFS Connect CPU profiler, never read by rustfs itself and
  # left out of upstream's own deb/rpm. We leave it out too.
  unzip -q "dl/$file" rustfs -d dl
  install -Dm755 dl/rustfs rustfs
  check_glibc rustfs
  # The unit upstream's deb/rpm install; it reads /etc/default/rustfs.
  download "$raw/deploy/build/rustfs.service" rustfs.service
  grep -q '^ExecStart=/usr/bin/rustfs server$' rustfs.service || die "unexpected ExecStart in rustfs.service"
  grep -q '^EnvironmentFile=/etc/default/rustfs$' rustfs.service || die "unexpected EnvironmentFile in rustfs.service"
  grep -q '^User=rustfs$' rustfs.service || die "unexpected User in rustfs.service"
  download "$raw/LICENSE" LICENSE
  download "$raw/README.md" README.md
}
