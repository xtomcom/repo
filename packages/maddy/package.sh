# shellcheck shell=bash
UPSTREAM=foxcpp/maddy
BRANCHES=(0)
# Release signing key named in upstream's .github/releases.md (Max Mazurov);
# artifacts are signed by its subkey CD76A6BB1D86CE4BC9C65BE5E943A49EE71E6169.
# Upstream publishes no checksums, only these detached signatures.
MADDY_KEY=3197BBD95137E682A59717B434BB2007081396F4
TEST_CMD='maddy version
maddyctl version
test -f /usr/lib/systemd/system/maddy.service
test -f /usr/lib/systemd/system/maddy@.service
grep -q "^ExecStart=/usr/bin/maddy run" /usr/lib/systemd/system/maddy.service
getent passwd maddy
test "$(stat -c %U:%G /var/lib/maddy)" = maddy:maddy
test -f /etc/maddy/maddy.conf'

prepare() {
  local version=$1 name gnupg fpr unit
  name=maddy-$version-$(rpm_arch "$2")-linux-musl
  download "https://github.com/$UPSTREAM/releases/download/v$version/$name.tar.zst" "dl/$name.tar.zst"
  download "https://github.com/$UPSTREAM/releases/download/v$version/$name.tar.zst.sig" "dl/$name.tar.zst.sig"
  download "https://keys.openpgp.org/vks/v1/by-fingerprint/$MADDY_KEY" dl/key.asc
  gnupg=$(mktemp -d)
  gpg --homedir "$gnupg" -q --import dl/key.asc 2>/dev/null
  fpr=$(gpg --homedir "$gnupg" --status-fd 1 -q --verify "dl/$name.tar.zst.sig" "dl/$name.tar.zst" 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }')
  rm -rf "$gnupg"
  [[ $fpr == "$MADDY_KEY" ]] || die "bad signature on $name.tar.zst"
  tar -C dl --zstd -xf "dl/$name.tar.zst"
  install -Dm755 "dl/$name/maddy" maddy
  cp "dl/$name/maddy.conf" maddy.conf
  # The shipped units assume a /usr/local install.
  for unit in maddy.service maddy@.service; do
    sed 's|/usr/local/bin/maddy|/usr/bin/maddy|' "dl/$name/systemd/$unit" >"$unit"
    grep -q '^ExecStart=/usr/bin/maddy ' "$unit" || die "unexpected ExecStart in $unit"
  done
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/COPYING" COPYING
}
