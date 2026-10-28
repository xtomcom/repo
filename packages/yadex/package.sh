# shellcheck shell=bash
UPSTREAM=ustclug/yadex
BRANCHES=(0)
ARCHS=(amd64)
TEST_CMD='
yadex --help | grep -q -- --config
test -f /usr/lib/systemd/system/yadex.service
test -f /etc/yadex/index.html
grep -q "^\[service\]" /etc/yadex/config.toml
'

prepare() {
  local version=$1 raw=https://raw.githubusercontent.com/$UPSTREAM/v$1 f
  # Upstream publishes a bare static x86_64 binary with no checksums or signatures.
  download "https://github.com/$UPSTREAM/releases/download/v$version/yadex" dl/yadex
  install -Dm755 dl/yadex yadex
  # Unit, config and docs as shipped in upstream's own deb (cargo-deb metadata).
  download "$raw/debian/service" yadex.service
  for f in etc/config.toml etc/index.html contrib/nginx.index.example.conf \
    contrib/nginx.try_files.example.conf LICENSE README.md; do
    download "$raw/$f" "$(basename "$f")"
  done
}
