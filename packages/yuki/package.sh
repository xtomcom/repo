# shellcheck shell=bash
UPSTREAM=ustclug/Yuki
BRANCHES=(0)
# 2: state and log directories, working example config, no podman-docker.
RELEASE=2
ARCHS=(amd64)
TEST_CMD='
yukid --version | grep -q "\"Version\""
yukictl --version | grep -q "\"Version\""
yuki --help | grep -q yukictl
test -f /usr/lib/systemd/system/yukid.service
test -f /etc/yuki/daemon.example.toml
test -f /usr/share/bash-completion/completions/yukictl
getent passwd mirror
! getent group docker || id -nG mirror | grep -qw docker
'
# yukid.service requires docker.service. Debian and Ubuntu pull in docker.io;
# Rocky has no Docker in its repositories (docker-ce is only recommended), so
# there the unit cannot start and the test ends once that is confirmed.
SERVICE_TEST='
cp /etc/yuki/daemon.example.toml /etc/yuki/daemon.toml
if ! systemctl cat docker.service >/dev/null 2>&1; then
  out=$(systemctl start yukid 2>&1) && exit 1
  echo "$out" | grep -q "docker.service not found"
  exit 0
fi
mkdir -p /srv/mirror/test
printf "name: test\ncron: \"0 0 1 1 *\"\nstorageDir: /srv/mirror/test\nimage: ustcmirror/rsync:latest\nenvs:\n  RSYNC_HOST: rsync.example.org\n  RSYNC_PATH: test/\n" \
  > /etc/yuki/repos/test.yaml
systemctl start yukid
# The unit pulled in Docker, which the mirror user can use.
systemctl is-active docker
id -nG mirror | grep -qw docker
runuser -u mirror -- docker ps
for _ in 1 2 3 4 5; do [ -S /run/yuki/yukid.sock ] && break; sleep 1; done
# Repository configs are read on reload (ExecReload: yukictl reload, as mirror).
systemctl reload yukid
yukictl repo ls | grep -q "^test .*/srv/mirror/test"
curl -fsS --retry 5 --retry-connrefused http://127.0.0.1:9999/api/v1/metas | grep -q "\"name\":\"test\""
rm /etc/yuki/repos/test.yaml && rm -r /srv/mirror
systemctl reload yukid
[ -z "$(yukictl repo ls | grep "^test ")" ]
systemctl is-active yukid
grep -q "Running HTTP server" /var/log/yuki/yukid.log
'

prepare() {
  local version=$1 rel=https://github.com/$UPSTREAM/releases/download/v$1
  local raw=https://raw.githubusercontent.com/$UPSTREAM/v$1 b
  download "$rel/checksums.txt" dl/checksums.txt
  for b in yukid yukictl; do
    download "$rel/${b}_linux_amd64" "dl/${b}_linux_amd64"
    verify_sums dl/checksums.txt "dl/${b}_linux_amd64"
    install -Dm755 "dl/${b}_linux_amd64" "$b"
  done
  # Upstream's goreleaser generates the completion the same way.
  ./yukictl completion bash >yukictl.bash
  # Unit and example config as shipped in upstream's own deb.
  download "$raw/etc/yukid.service" yukid.service
  download "$raw/etc/daemon.example.toml" daemon.example.toml
  # Point the example at the directories this package provides. yukid opens
  # log_file itself, and the default /dev/stderr fails under systemd (ENXIO:
  # stderr is the journal's socket), so the example logs to a file.
  sed -i -e 's|^db_url = .*|db_url = "/var/lib/yuki/yukid.db"|' \
    -e 's|^repo_config_dir = .*|repo_config_dir = ["/etc/yuki/repos"]|' \
    -e 's|^#log_file = .*|## /dev/stderr does not work under systemd: it is a socket there\nlog_file = "/var/log/yuki/yukid.log"|' \
    daemon.example.toml
  local key
  for key in '^db_url = "/var/lib/yuki/' '^repo_config_dir = \["/etc/yuki/repos"\]' '^log_file = "/var/log/yuki/'; do
    grep -q "$key" daemon.example.toml || die "daemon.example.toml: no line matching $key"
  done
  download "$raw/README.md" README.md
  download "$raw/LICENSE" LICENSE
}
