# shellcheck shell=bash
UPSTREAM=caddyserver/caddy
BRANCHES=(2)
RELEASE=2
TEST_CMD='
v=$(basename "$PKG" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
caddy version | grep "^v$v "
test -f /usr/lib/systemd/system/caddy.service
test -f /usr/lib/systemd/system/caddy-api.service
getent passwd caddy | grep -q ":/var/lib/caddy:"
test "$(stat -c %U:%G /var/lib/caddy)" = caddy:caddy
caddy validate --config /etc/caddy/Caddyfile
grep -q "Caddy works" /usr/share/caddy/index.html
if command -v dpkg >/dev/null; then dpkg -L caddy; else rpm -ql caddy; fi | grep -q /usr/share/man/man8/caddy-run.8.gz
test -f /usr/share/bash-completion/completions/caddy
test -f /usr/share/fish/vendor_completions.d/caddy.fish
caddy start --config /etc/caddy/Caddyfile
exec 3<>/dev/tcp/127.0.0.1/80
printf "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3
grep -q "Caddy works" <&3
caddy stop
'
SERVICE_TEST='
# The stock Caddyfile serves the welcome page on :80 as the unprivileged
# caddy user (CAP_NET_BIND_SERVICE).
systemctl start caddy
curl -fsS --retry 5 --retry-connrefused http://127.0.0.1/ | grep -q "Caddy works"
pid=$(systemctl show -P MainPID caddy)
test "$(stat -c %U /proc/$pid)" = caddy
# ExecReload (caddy reload) applies an edited Caddyfile in place.
printf ":8080 {\n\trespond \"ok\"\n}\n" >/etc/caddy/Caddyfile
systemctl reload caddy
test "$(curl -fsS --retry 5 --retry-connrefused http://127.0.0.1:8080/)" = ok
! curl -fsS http://127.0.0.1/
test "$(systemctl show -P MainPID caddy)" = "$pid"
# caddy-api.service resumes the config caddy autosaved in its state directory
# and takes new config through the admin API.
test -f /var/lib/caddy/.config/caddy/autosave.json
systemctl stop caddy
systemctl start caddy-api
curl -fsS --retry 5 --retry-connrefused http://localhost:2019/config/ | grep -q :8080
test "$(stat -c %U /proc/$(systemctl show -P MainPID caddy-api))" = caddy
curl -fsS -H "Content-Type: text/caddyfile" --data-binary ":81 {
	respond \"api\"
}" http://localhost:2019/load
test "$(curl -fsS --retry 5 --retry-connrefused http://127.0.0.1:81/)" = api
systemctl stop caddy-api
'

# checksums.txt lists SHA-512 sums. The release also carries cosign (sigstore)
# .sig/.pem for checksums.txt; the checksum check is what we rely on.
prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/v$1 a file host
  local dist=https://raw.githubusercontent.com/caddyserver/dist/v$1
  download "$base/caddy_${version}_checksums.txt" dl/checksums.txt
  for a in "$2" "$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"; do
    file=caddy_${version}_linux_$a.tar.gz
    [[ -f dl/$file ]] && continue
    download "$base/$file" "dl/$file"
    verify_sums dl/checksums.txt "dl/$file"
    mkdir -p "dl/$a"
    tar -xzf "dl/$file" -C "dl/$a"
  done
  install -Dm755 "dl/$2/caddy" caddy
  cp "dl/$2/LICENSE" "dl/$2/README.md" .

  # Units, config, sysusers and welcome page from caddyserver/dist, which is
  # tagged for every caddy release; Debian ships the same files.
  download "$dist/init/caddy.service" caddy.service
  download "$dist/init/caddy-api.service" caddy-api.service
  download "$dist/init/caddy.sysusers" sysusers.conf
  download "$dist/config/Caddyfile" Caddyfile
  download "$dist/welcome/index.html" index.html
  grep -q '^ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile$' caddy.service ||
    die "unexpected ExecStart in caddy.service"
  grep -q '^AmbientCapabilities=.*CAP_NET_BIND_SERVICE' caddy.service || die "caddy.service lacks CAP_NET_BIND_SERVICE"
  grep -q '^u caddy .* /var/lib/caddy ' sysusers.conf || die "unexpected caddy.sysusers"

  # Man pages and completions come from the binary, as in Debian and Fedora;
  # use one the build host can run.
  host=dl/$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')/caddy
  mkdir -p man
  "$host" manpage --directory man >/dev/null
  gzip -9n man/*.8
  for a in bash zsh fish; do
    "$host" completion "$a" >"caddy.$a"
  done
}
