# shellcheck shell=bash
UPSTREAM=rclone/rclone
BRANCHES=(1)
# Release signing keys listed in https://rclone.org/KEYS (Nick Craig-Wood).
RCLONE_KEYS=(FBF737ECE9F8AB18604BD2AC93935E02FF3B54FA E3B358DC858FB307F48170B9CB0DBEBC5F32C81D)
TEST_CMD='rclone version
test "$(readlink -f /usr/sbin/mount.rclone)" = /usr/bin/rclone
test "$(readlink -f /usr/bin/rclonefs)" = /usr/bin/rclone
# Minimal Ubuntu images drop /usr/share/man at unpack, so check the file list.
files=$(dpkg -L rclone 2>/dev/null || rpm -ql rclone)
grep -qx /usr/share/man/man1/rclone.1.gz <<<"$files"
grep -qx /usr/share/man/man1/mount.rclone.1.gz <<<"$files"
test -f /usr/share/bash-completion/completions/rclone
test -f /usr/share/zsh/site-functions/_rclone
test -f /usr/share/fish/vendor_completions.d/rclone.fish'

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/v$1 name gnupg fpr host
  name=rclone-v$version-linux-$2
  # SHA256SUMS is clearsigned: check the signature against the pinned keys and
  # only trust the checksums inside the signed body.
  download "$base/SHA256SUMS" dl/SHA256SUMS.asc
  download https://rclone.org/KEYS dl/KEYS
  gnupg=$(mktemp -d)
  gpg --homedir "$gnupg" -q --import dl/KEYS 2>/dev/null
  fpr=$(gpg --homedir "$gnupg" --status-fd 1 -q -o dl/SHA256SUMS --decrypt dl/SHA256SUMS.asc 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }')
  rm -rf "$gnupg"
  [[ -n $fpr && " ${RCLONE_KEYS[*]} " == *" $fpr "* ]] || die "bad signature on SHA256SUMS"

  download "$base/$name.zip" "dl/$name.zip"
  verify_sums dl/SHA256SUMS "dl/$name.zip"
  unzip -q "dl/$name.zip" -d dl
  install -Dm755 "dl/$name/rclone" rclone
  gzip -9n <"dl/$name/rclone.1" >rclone.1.gz
  cp "dl/$name/README.html" "dl/$name/README.txt" .
  download "https://raw.githubusercontent.com/$UPSTREAM/v$version/COPYING" COPYING

  # Shell completions come from the binary itself; use one the build host can run.
  host=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
  if [[ $host != "$2" ]]; then
    download "$base/rclone-v$version-linux-$host.zip" "dl/rclone-v$version-linux-$host.zip"
    verify_sums dl/SHA256SUMS "dl/rclone-v$version-linux-$host.zip"
    unzip -q "dl/rclone-v$version-linux-$host.zip" -d dl
  fi
  local bin=dl/rclone-v$version-linux-$host/rclone
  "$bin" completion bash - >rclone.bash
  "$bin" completion zsh - >rclone.zsh
  "$bin" completion fish - >rclone.fish
}
