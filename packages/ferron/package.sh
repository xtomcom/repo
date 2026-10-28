# shellcheck shell=bash
UPSTREAM=ferronweb/ferron
BRANCHES=(2)
# 2: deb depends on procps for the unit's ExecReload (kill).
RELEASE=2
TEST_CMD='ferron --version | grep "^Ferron 2\."
ferron-passwd --version
ferron-precompress --version
ferron-yaml2kdl --version
test -f /usr/lib/systemd/system/ferron.service
getent passwd ferron
test "$(stat -c %U:%G /var/log/ferron)" = ferron:ferron
test -f /var/www/ferron/index.html
ferron -c /etc/ferron.kdl &
pid=$!
for i in $(seq 30); do (exec 3<>/dev/tcp/127.0.0.1/80) 2>/dev/null && break; sleep 1; done
exec 3<>/dev/tcp/127.0.0.1/80
printf "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3
grep -q "Ferron is installed successfully" <&3
kill $pid'
SERVICE_TEST='
# The stock /etc/ferron.kdl serves /var/www/ferron on :80 as the unprivileged
# ferron user (CAP_NET_BIND_SERVICE) and logs to /var/log/ferron.
systemctl start ferron
curl -fsS --retry 5 --retry-connrefused http://127.0.0.1/ | grep -q "Ferron is installed successfully"
test "$(stat -c %U /proc/$(systemctl show -P MainPID ferron))" = ferron
for i in $(seq 10); do grep -q "\"GET / HTTP/1.1\" 200" /var/log/ferron/access.log && break; sleep 1; done
grep -q "\"GET / HTTP/1.1\" 200" /var/log/ferron/access.log
test "$(stat -c %U /var/log/ferron/access.log)" = ferron
systemctl reload ferron
curl -fsS --retry 5 --retry-connrefused http://127.0.0.1/ | grep -q "Ferron is installed successfully"
systemctl is-active ferron
'

prepare() {
  local version=$1 raw=https://raw.githubusercontent.com/$UPSTREAM/$1 file b
  file=ferron-$version-$(rpm_arch "$2")-unknown-linux-gnu.zip
  # Upstream publishes no checksums or signatures for release assets.
  download "https://github.com/$UPSTREAM/releases/download/$version/$file" "dl/$file"
  unzip -q "dl/$file" -d dl/ferron
  for b in ferron ferron-passwd ferron-precompress ferron-yaml2kdl; do
    install -Dm755 "dl/ferron/$b" "$b"
  done
  check_glibc ferron ferron-passwd ferron-precompress ferron-yaml2kdl
  mv dl/ferron/wwwroot wwwroot
  # Config and unit of upstream's own deb/rpm (packaging/, configs/).
  download "$raw/configs/ferron.packages.kdl" ferron.kdl
  download "$raw/packaging/deb/ferron.service" ferron.service
  grep -q '^ExecStart=/usr/sbin/ferron -c /etc/ferron.kdl$' ferron.service || die "unexpected ExecStart in ferron.service"
  grep -q '^User=ferron$' ferron.service || die "unexpected User in ferron.service"
  download "$raw/LICENSE" LICENSE
  download "$raw/README.md" README.md
}
