# shellcheck shell=bash
# Shared by forgejo, which follows the newest stable release, and forgejo-lts,
# which follows a long-term support release. Both install the same server
# (/usr/bin/forgejo, forgejo.service, /etc/forgejo, /var/lib/forgejo), so
# they conflict with each other. See README.md.
UPSTREAM=forgejo/forgejo
# Forgejo's release signing key, given on https://forgejo.org/download/.
FORGEJO_KEY=EB114F5E6C0DC2BCDD183550A4B61A2DC5923710

# forgejo_get PATH: fetch PATH from code.forgejo.org or, when that fails (it
# sometimes answers 504), from its mirror on codeberg.org.
forgejo_get() {
  local host
  for host in code.forgejo.org codeberg.org; do
    curl -fsL --retry 2 "https://$host/$1" && return 0
  done
  return 1
}

forgejo_versions() {
  forgejo_get "api/v1/repos/$UPSTREAM/releases?limit=50" |
    jq -r '.[] | select(.draft or .prerelease | not) | .tag_name | sub("^v"; "")'
}

versions() { forgejo_versions; }

# forgejo_tracks: set FORGEJO_STABLE to the newest released major, and
# FORGEJO_LTS to the oldest released LTS major that has not reached its end of
# life, so forgejo-lts moves to the next LTS (15 -> 19) only when the current
# one ends. Both empty when upstream cannot be reached.
# The release schedule (behind https://forgejo.org/releases/) gives each
# major's release date, end of life and whether it is an LTS.
# publish.sh loads the packages in subshells, one per index, so the result is
# kept in a file for the run ($$ is the script's PID in its subshells too).
forgejo_tracks() {
  local cache=$WORK/.forgejo-tracks.$$ released schedule
  if [[ -f $cache ]]; then
    # shellcheck source=/dev/null
    source "$cache"
    return 0
  fi
  FORGEJO_STABLE='' FORGEJO_LTS=''
  if released=$(forgejo_versions | cut -d. -f1 | sort -un) && [[ -n $released ]] &&
    schedule=$(forgejo_get forgejo/docs/raw/branch/next/release-schedule.json); then
    FORGEJO_STABLE=$(tail -n1 <<<"$released")
    FORGEJO_LTS=$(jq -r --arg today "$(date -u +%F)" \
      '.[] | select(.lts and .eol > $today) | .major' <<<"$schedule" |
      grep -Fx -f - <(echo "$released") | head -n1) || true
  fi
  mkdir -p "$WORK"
  find "$WORK" -maxdepth 1 -name '.forgejo-tracks.*' -mmin +60 -delete
  printf 'FORGEJO_STABLE=%q FORGEJO_LTS=%q\n' "$FORGEJO_STABLE" "$FORGEJO_LTS" >"$cache"
}

# forgejo_branches MAJOR: set BRANCHES to MAJOR or, when the lookup failed, to
# the major already published, so publish.sh still knows what to keep.
forgejo_branches() {
  local major=$1
  if [[ -z $major ]]; then
    warn "$PKG_NAME: could not look up the Forgejo release schedule"
    major=$(published_versions "$PKG_NAME" | cut -d. -f1 | sort -n | tail -n1)
  fi
  BRANCHES=()
  [[ -z $major ]] || BRANCHES=("$major")
}

TEST_CMD='
forgejo --version
/usr/lib/forgejo/forgejo --version
test -f /usr/lib/systemd/system/forgejo.service
getent passwd git
test -d /home/git
test "$(stat -c %U:%G:%a /etc/forgejo)" = root:git:770
test "$(stat -c %U:%G:%a /var/lib/forgejo/data)" = git:git:750
git --version
runuser -u git -- forgejo doctor check --list >/dev/null
'
SERVICE_TEST='
systemctl enable --now forgejo
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:3000/ | grep -qi install
# A headless install: the app.ini the web installer would write, minus the
# defaults. /etc/forgejo stays root:git 0770 so Forgejo can save generated secrets.
systemctl stop forgejo
cat >/etc/forgejo/app.ini <<INI
RUN_USER = git
WORK_PATH = /var/lib/forgejo
[server]
HTTP_PORT = 3000
ROOT_URL = http://127.0.0.1:3000/
[database]
DB_TYPE = sqlite3
PATH = /var/lib/forgejo/data/forgejo.db
[security]
INSTALL_LOCK = true
SECRET_KEY = $(forgejo generate secret SECRET_KEY)
INTERNAL_TOKEN = $(forgejo generate secret INTERNAL_TOKEN)
INI
chown root:git /etc/forgejo/app.ini && chmod 660 /etc/forgejo/app.ini
systemctl start forgejo
v=$(forgejo --version | awk "{print \$3}")
curl -fsS --retry 10 --retry-connrefused http://127.0.0.1:3000/api/v1/version | grep -qF "\"version\":\"$v"
# The wrapper finds /etc/forgejo/app.ini on its own.
runuser -u git -- forgejo admin user create --admin --username tester --password Secret-pass-123 \
  --email tester@example.com --must-change-password=false
curl -fsS -u tester:Secret-pass-123 http://127.0.0.1:3000/api/v1/user | grep -q "\"login\":\"tester\""
'

prepare() {
  local version=$1 base=https://code.forgejo.org/$UPSTREAM/releases/download/v$1
  local raw=https://code.forgejo.org/$UPSTREAM/raw/tag/v$1 file gnupg fpr other
  [[ ${1%%.*} == "${BRANCHES[0]}" ]] || die "$PKG_NAME follows Forgejo ${BRANCHES[0]}, not $1"
  file=forgejo-$version-linux-$2
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
  install -Dm755 "dl/$file" forgejo
  # Upstream's packaging helpers: the FHS wrapper (still named and written for
  # Gitea, so renamed here: real binary in /usr/lib/forgejo, defaults to
  # /etc/forgejo/app.ini and /var/lib/forgejo) and the systemd unit, adjusted
  # for /usr/bin.
  download "$raw/contrib/fhs-compliant-script/gitea" dl/wrapper
  sed -e 's/gitea/forgejo/g' -e 's/GITEA/FORGEJO/g' dl/wrapper >forgejo-wrapper
  grep -q '^FORGEJO="/usr/lib/forgejo/forgejo"$' forgejo-wrapper || die "unexpected binary path in fhs wrapper"
  grep -q '^APP_INI="/etc/forgejo/app.ini"$' forgejo-wrapper || die "unexpected app.ini path in fhs wrapper"
  download "$raw/contrib/systemd/forgejo.service" dl/forgejo.service
  # Type=notify (16 and later) never becomes ready while the web installer
  # runs: Forgejo then sends READY=1 only once all its servers are up, and the
  # installer starts one. "systemctl enable --now forgejo" on a fresh install
  # would time out, so keep 15's Type=simple.
  sed -e 's|^ExecStart=/usr/local/bin/forgejo |ExecStart=/usr/bin/forgejo |' \
    -e 's/^Type=notify$/Type=simple/' dl/forgejo.service >forgejo.service
  grep -q '^Type=simple$' forgejo.service || die "unexpected Type in forgejo.service"
  grep -q '^ExecStart=/usr/bin/forgejo web --config /etc/forgejo/app.ini$' forgejo.service || die "unexpected ExecStart in forgejo.service"
  download "$raw/LICENSE" LICENSE
  case $PKG_NAME in forgejo) other=forgejo-lts ;; *) other=forgejo ;; esac
  sed -i -e "s/@NAME@/$PKG_NAME/g" -e "s/@OTHER@/$other/g" -e "s/@MAJOR@/${BRANCHES[0]}/g" nfpm.yaml
}
