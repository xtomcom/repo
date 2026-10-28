# shellcheck shell=bash
UPSTREAM=ustclug/yadex
BRANCHES=(0)
RELEASE=2
ARCHS=(amd64)
TEST_CMD='
yadex --help | grep -q -- --config
test -f /usr/lib/systemd/system/yadex.service
test -f /etc/yadex/index.html
grep -q "^\[service\]" /etc/yadex/config.toml
'
SERVICE_TEST='
mkdir -p /srv/repo && echo hi > /srv/repo/hello.txt
systemctl start yadex
curl -fsS --retry 5 --retry-connrefused http://127.0.0.1:8880/ | grep -q hello.txt
# The /home override documented in README.md.
mkdir -p /home/mirror /etc/systemd/system/yadex.service.d && echo hi > /home/mirror/home.txt
sed -i "s|^root = .*|root = \"/home/mirror/\"|" /etc/yadex/config.toml
printf "[Service]\nProtectHome=read-only\nReadOnlyPaths=\nReadOnlyPaths=/etc/yadex /home/mirror\n" \
  > /etc/systemd/system/yadex.service.d/override.conf
systemctl daemon-reload && systemctl restart yadex
curl -fsS --retry 5 --retry-connrefused http://127.0.0.1:8880/ | grep -q home.txt
rm -r /etc/systemd/system/yadex.service.d && systemctl daemon-reload
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
