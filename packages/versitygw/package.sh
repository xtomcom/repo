# shellcheck shell=bash
UPSTREAM=versity/versitygw
BRANCHES=(1)
TEST_CMD='versitygw --version | grep -q "^Version"
test -f /usr/lib/systemd/system/versitygw@.service
grep -q "^EnvironmentFile=/etc/versitygw.d/%i.conf$" /usr/lib/systemd/system/versitygw@.service
test "$(stat -c %a /etc/versitygw.d)" = 700
grep -q "^VGW_BACKEND=posix$" /etc/versitygw.d/example.conf
test -f /etc/versitygw.d/example-iam.conf
test -f /usr/share/bash-completion/completions/versitygw
test -f /usr/share/zsh/site-functions/_versitygw
test -f /usr/share/fish/vendor_completions.d/versitygw.fish
mkdir -p /tmp/gw
ROOT_ACCESS_KEY_ID=test ROOT_SECRET_ACCESS_KEY=testsecret versitygw --port 127.0.0.1:7070 posix /tmp/gw &
for i in $(seq 20); do (exec 3<>/dev/tcp/127.0.0.1/7070) 2>/dev/null && break; sleep 0.5; done
(exec 3<>/dev/tcp/127.0.0.1/7070)
kill %1'

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/v$1 raw dir f
  # The tarballs have a "v" in the name and use x86_64 / arm64.
  dir=versitygw_v${version}_Linux_$(case $2 in amd64) echo x86_64 ;; arm64) echo arm64 ;; esac)
  download "$base/checksums.txt" dl/checksums.txt
  download "$base/$dir.tar.gz" "dl/$dir.tar.gz"
  verify_sums dl/checksums.txt "dl/$dir.tar.gz"
  tar -xzf "dl/$dir.tar.gz" -C dl
  install -Dm755 "dl/$dir/versitygw" versitygw
  mv "dl/$dir/LICENSE" "dl/$dir/NOTICE" "dl/$dir/README.md" .
  # The unit, example configs and completions that upstream's own .deb/.rpm
  # ship (see nfpms in .goreleaser.yaml), from the same tag.
  raw=https://raw.githubusercontent.com/$UPSTREAM/v$version/extra
  for f in versitygw@.service example.conf example-iam.conf versitygw.sh versitygw.zsh versitygw.fish; do
    download "$raw/$f" "$f"
  done
  grep -q '^EnvironmentFile=/etc/versitygw.d/%i.conf$' versitygw@.service || die "unexpected EnvironmentFile in versitygw@.service"
  grep -q '^ExecStart=.*exec /usr/bin/versitygw ' versitygw@.service || die "unexpected ExecStart in versitygw@.service"
}
