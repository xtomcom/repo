# shellcheck shell=bash
UPSTREAM=xtomcom/vaultwarden
BRANCHES=(1)
TEST_CMD='vaultwarden --version | grep "^Vaultwarden 1\."
test -f /usr/share/vaultwarden/web-vault/index.html
test -f /usr/lib/systemd/system/vaultwarden.service
grep -q "^EnvironmentFile=/etc/vaultwarden/vaultwarden.env$" /usr/lib/systemd/system/vaultwarden.service
grep -q "^WEB_VAULT_FOLDER=/usr/share/vaultwarden/web-vault$" /etc/vaultwarden/vaultwarden.env
getent passwd vaultwarden
test "$(stat -c %U:%G:%a /etc/vaultwarden/vaultwarden.env)" = root:vaultwarden:640
test "$(stat -c %U:%G:%a /var/lib/vaultwarden)" = vaultwarden:vaultwarden:700'
SERVICE_TEST='
env=/etc/vaultwarden/vaultwarden.env
cp -p $env /root/vaultwarden.env.orig
# What the install notice asks for; the defaults keep 127.0.0.1:8000 and /var/lib/vaultwarden.
printf "%s\n" DOMAIN=http://127.0.0.1:8000 ADMIN_TOKEN=xtom-test-admin-token >>$env
systemctl start vaultwarden
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:8000/alive | grep -qE "^\"[0-9]{4}-[0-9]{2}-[0-9]{2}T"
curl -fsS http://127.0.0.1:8000/ | grep -q "<title page-title>Vaultwarden Web</title>"
curl -fsS http://127.0.0.1:8000/api/config | grep -qF "\"server\":{\"name\":\"Vaultwarden\""
test "$(stat -c %U /proc/$(systemctl show -P MainPID vaultwarden))" = vaultwarden
test "$(stat -c %U /var/lib/vaultwarden/db.sqlite3)" = vaultwarden
# The admin page asks for the token (401 without it), and the token from the env file logs in.
curl -fsS http://127.0.0.1:8000/admin | grep -q "name=\"token\""
v=$(vaultwarden --version | head -n1 | cut -d" " -f2)
jar=$(mktemp)
curl -fsS -c $jar -o /dev/null -d token=xtom-test-admin-token http://127.0.0.1:8000/admin
test "$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/admin/diagnostics)" = 401
curl -fsS -b $jar http://127.0.0.1:8000/admin/diagnostics | grep -qF "<span id=\"server-installed\">$v</span>"
rm -f $jar
mv /root/vaultwarden.env.orig $env
# Left running on purpose: removing the package must stop and disable it.
'

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/$1 dir
  # The gnu build is Debian 13's (glibc 2.39, libssl3, libpq5, libmariadb3),
  # too new for Debian 12, Ubuntu 22.04 and EL9. The musl build is static,
  # still supports SQLite, MySQL and PostgreSQL, and is what upstream's own
  # .deb/.rpm ship. Its web-vault, unit and env file are the same files.
  dir=vaultwarden-$version-linux-$2-musl
  download "$base/SHA256SUMS" dl/SHA256SUMS
  download "$base/$dir.tar.gz" "dl/$dir.tar.gz"
  verify_sums dl/SHA256SUMS "dl/$dir.tar.gz"
  tar -xzf "dl/$dir.tar.gz" -C dl
  install -Dm755 "dl/$dir/vaultwarden" vaultwarden
  # Static, so no check_glibc (which needs at least one GLIBC_ symbol).
  # Not `objdump | grep -q`: grep exiting early fails objdump with SIGPIPE.
  [[ $(objdump -p vaultwarden | grep -c NEEDED) -eq 0 ]] || die "vaultwarden is not statically linked"
  mv "dl/$dir/web-vault" "dl/$dir/vaultwarden.service" "dl/$dir/vaultwarden.env" "dl/$dir/LICENSE.txt" .
  [[ -f web-vault/index.html ]] || die "no web-vault/index.html"
  grep -q '^ExecStart=/usr/bin/vaultwarden$' vaultwarden.service || die "unexpected ExecStart in vaultwarden.service"
  grep -q '^EnvironmentFile=/etc/vaultwarden/vaultwarden.env$' vaultwarden.service || die "unexpected EnvironmentFile in vaultwarden.service"
  grep -q '^User=vaultwarden$' vaultwarden.service || die "unexpected User in vaultwarden.service"
  grep -q '^WEB_VAULT_FOLDER=/usr/share/vaultwarden/web-vault$' vaultwarden.env || die "unexpected WEB_VAULT_FOLDER in vaultwarden.env"
  grep -q '^DATA_FOLDER=/var/lib/vaultwarden$' vaultwarden.env || die "unexpected DATA_FOLDER in vaultwarden.env"
}
