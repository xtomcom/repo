# shellcheck shell=bash
UPSTREAM=forgejo/runner
BRANCHES=(13)
# Forgejo's release signing key, given on https://forgejo.org/download/.
FORGEJO_KEY=EB114F5E6C0DC2BCDD183550A4B61A2DC5923710
TEST_CMD='
forgejo-runner --version | grep -q "^forgejo-runner version v"
test -f /usr/lib/systemd/system/forgejo-runner.service
getent passwd runner
test "$(stat -c "%U %G" /home/runner)" = "runner runner"
git --version
'
# Against a real Forgejo: the official binary of its newest release (the
# packages here cannot be installed in the same test), set up without the web
# installer, with the runner registered offline as in
# https://forgejo.org/docs/latest/admin/actions/registration/. The runner is
# configured as the installation notice says and must connect.
SERVICE_TEST='
a=$(uname -m | sed "s/x86_64/amd64/;s/aarch64/arm64/")
v=$(curl -fsSL https://code.forgejo.org/api/v1/repos/forgejo/forgejo/releases/latest | grep -o "\"tag_name\":\"v[^\"]*" | cut -d"\"" -f4 | cut -c2-)
f=https://code.forgejo.org/forgejo/forgejo/releases/download/v$v/forgejo-$v-linux-$a
curl -fsSLo /usr/local/bin/forgejo "$f"
echo "$(curl -fsSL "$f.sha256" | cut -d" " -f1)  /usr/local/bin/forgejo" | sha256sum -c -
chmod 755 /usr/local/bin/forgejo
useradd -m fj
cat >/home/fj/app.ini <<INI
WORK_PATH = /home/fj
[server]
HTTP_PORT = 3000
ROOT_URL = http://127.0.0.1:3000/
[database]
DB_TYPE = sqlite3
PATH = /home/fj/forgejo.db
[security]
INSTALL_LOCK = true
INI
chown fj: /home/fj/app.ini
secret=7c31591e8b67225a116d4a4519ea8e507e08f71f
runuser -u fj -- forgejo --config /home/fj/app.ini migrate
uuid=$(runuser -u fj -- forgejo --config /home/fj/app.ini forgejo-cli actions register --name test --secret $secret | tail -n1)
systemd-run --unit fj --uid fj -p WorkingDirectory=/home/fj /usr/local/bin/forgejo web --config /home/fj/app.ini
curl -fsS --retry 20 --retry-connrefused http://127.0.0.1:3000/api/v1/version
runuser -u runner -- sh -c "cd /home/runner && forgejo-runner generate-config > runner-config.yml"
# The generated file ends with an empty server section; fill it in.
sed -i "/^server:/d" /home/runner/runner-config.yml
cat >>/home/runner/runner-config.yml <<YML
server:
  connections:
    forgejo:
      url: http://127.0.0.1:3000/
      uuid: $uuid
      token: $secret
YML
systemctl start forgejo-runner
for i in $(seq 30); do journalctl -u forgejo-runner | grep -q "declared successfully" && break; sleep 1; done
journalctl -u forgejo-runner --no-pager | tail -n 5
journalctl -u forgejo-runner | grep -q "declared successfully"
systemctl is-active forgejo-runner
test "$(stat -c %U "/proc/$(systemctl show -p MainPID --value forgejo-runner)")" = runner
'

# Releases live on code.forgejo.org.
versions() {
  curl -fsSL --retry 3 "https://code.forgejo.org/api/v1/repos/$UPSTREAM/releases?limit=50" |
    jq -r '.[] | select(.draft or .prerelease | not) | .tag_name | sub("^v"; "")'
}

prepare() {
  local version=$1 base=https://code.forgejo.org/$UPSTREAM/releases/download/v$1
  local raw=https://code.forgejo.org/$UPSTREAM/raw/tag/v$1 file gnupg fpr
  file=forgejo-runner-$version-linux-$2
  download "$base/$file" "dl/$file"
  download "$base/$file.sha256" "dl/$file.sha256"
  download "$base/$file.asc" "dl/$file.asc"
  verify_sums "dl/$file.sha256" "dl/$file"
  download "https://keys.openpgp.org/vks/v1/by-fingerprint/$FORGEJO_KEY" dl/key.asc
  gnupg=$(mktemp -d)
  gpg --homedir "$gnupg" -q --import dl/key.asc 2>/dev/null
  fpr=$(gpg --homedir "$gnupg" --status-fd 1 -q --verify "dl/$file.asc" "dl/$file" 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }')
  rm -rf "${gnupg:?}"
  [[ $fpr == "$FORGEJO_KEY" ]] || die "bad signature on $file"
  install -Dm755 "dl/$file" forgejo-runner
  # Upstream's unit, adjusted for /usr/bin. It runs as runner in /home/runner
  # with /home/runner/runner-config.yml, as the installation docs set it up.
  download "$raw/contrib/forgejo-runner.service" dl/forgejo-runner.service
  sed 's|^ExecStart=/usr/local/bin/forgejo-runner |ExecStart=/usr/bin/forgejo-runner |' \
    dl/forgejo-runner.service >forgejo-runner.service
  grep -q '^ExecStart=/usr/bin/forgejo-runner daemon -c /home/runner/runner-config.yml$' forgejo-runner.service ||
    die "unexpected ExecStart in forgejo-runner.service"
  download "$raw/LICENSE" LICENSE
}
