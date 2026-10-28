# shellcheck shell=bash
UPSTREAM=ustclug/Yuki
BRANCHES=(0)
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
  download "$raw/README.md" README.md
  download "$raw/LICENSE" LICENSE
}
