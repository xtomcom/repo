# shellcheck shell=bash
UPSTREAM=go-gitea/gitea
BRANCHES=(28)
# Teabot <teabot@gitea.io>, the release signing key given in
# https://docs.gitea.com/installation/install-from-binary.
GITEA_KEY=7C9E68152594688862D62AF62D9AE806EC1592E2
TEST_CMD='gitea --version
/usr/lib/gitea/gitea --version
test -f /usr/lib/systemd/system/gitea.service
getent passwd git
test -d /home/git
test "$(stat -c %U:%G:%a /etc/gitea)" = root:git:770
test "$(stat -c %U:%G:%a /var/lib/gitea/data)" = git:git:750
git --version
runuser -u git -- gitea doctor check --list >/dev/null'
SERVICE_TEST='
systemctl enable --now gitea
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:3000/ | grep -qi install
# A headless install: the app.ini the web installer would write, minus the
# defaults. /etc/gitea stays root:git 0770 so Gitea can save generated secrets.
systemctl stop gitea
cat >/etc/gitea/app.ini <<INI
RUN_USER = git
WORK_PATH = /var/lib/gitea
[server]
HTTP_PORT = 3000
ROOT_URL = http://127.0.0.1:3000/
[database]
DB_TYPE = sqlite3
PATH = /var/lib/gitea/data/gitea.db
[security]
INSTALL_LOCK = true
SECRET_KEY = $(gitea generate secret SECRET_KEY)
INTERNAL_TOKEN = $(gitea generate secret INTERNAL_TOKEN)
INI
chown root:git /etc/gitea/app.ini && chmod 660 /etc/gitea/app.ini
systemctl start gitea
v=$(gitea --version | awk "{print \$3}")
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:3000/api/v1/version | grep -qF "\"version\":\"$v\""
# The wrapper finds /etc/gitea/app.ini on its own.
runuser -u git -- gitea admin user create --admin --username tester --password Secret-pass-123 \
  --email tester@example.com --must-change-password=false
curl -fsS -u tester:Secret-pass-123 http://127.0.0.1:3000/api/v1/user | grep -q "\"login\":\"tester\""
'

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/v$1 file gnupg fpr
  file=gitea-$version-linux-$2
  download "$base/$file" "dl/$file"
  download "$base/$file.sha256" "dl/$file.sha256"
  download "$base/$file.asc" "dl/$file.asc"
  verify_sums "dl/$file.sha256" "dl/$file"
  download "https://keys.openpgp.org/vks/v1/by-fingerprint/$GITEA_KEY" dl/key.asc
  gnupg=$(mktemp -d)
  gpg --homedir "$gnupg" -q --import dl/key.asc 2>/dev/null
  fpr=$(gpg --homedir "$gnupg" --status-fd 1 -q --verify "dl/$file.asc" "dl/$file" 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }')
  rm -rf "$gnupg"
  [[ $fpr == "$GITEA_KEY" ]] || die "bad signature on $file"
  install -Dm755 "dl/$file" gitea
  # Upstream's packaging helpers: the FHS wrapper (real binary in
  # /usr/lib/gitea, defaults to /etc/gitea/app.ini and /var/lib/gitea) and the
  # systemd unit, adjusted for /usr/bin.
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/contrib/fhs-compliant-script/gitea" gitea-wrapper
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/contrib/service/systemd/gitea.service" dl/gitea.service
  sed 's|^ExecStart=/usr/local/bin/gitea |ExecStart=/usr/bin/gitea |' dl/gitea.service >gitea.service
  grep -q '^ExecStart=/usr/bin/gitea web --config /etc/gitea/app.ini$' gitea.service || die "unexpected ExecStart in gitea.service"
  grep -q '^GITEA="/usr/lib/gitea/gitea"$' gitea-wrapper || die "unexpected binary path in fhs wrapper"
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/LICENSE" LICENSE
}
