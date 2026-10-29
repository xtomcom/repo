# shellcheck shell=bash
UPSTREAM=openai/codex
BRANCHES=(0)
TEST_CMD='v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
test "$(readlink /usr/bin/codex)" = ../lib/codex/bin/codex
test "$(codex --version)" = "codex-cli $v"
grep -q "\"version\": \"$v\"" /usr/lib/codex/codex-package.json
for f in bin/codex bin/codex-code-mode-host codex-path/rg codex-resources/bwrap; do
  test -x "/usr/lib/codex/$f"
done
/usr/lib/codex/codex-path/rg --version | grep -q "^ripgrep "
/usr/lib/codex/codex-resources/bwrap --version | grep -q "^bubblewrap "
codex --help | grep -q "^Usage: codex"
codex completion bash | grep -q _codex
test -f /usr/share/bash-completion/completions/codex
test -f /usr/share/zsh/site-functions/_codex
test -f /usr/share/fish/vendor_completions.d/codex.fish
# Run as a normal user, through the /usr/bin symlink.
useradd -m codextest
u() { su codextest -s /bin/bash -c "$*" </dev/null; }
# The package layout is found through the symlink: doctor reports the bundled
# rg, and our /etc/codex/config.toml applies. (doctor also probes the network
# and fails without credentials; neither matters here.)
d=$(u codex doctor --json 2>/dev/null || true)
echo "$d" | grep -qF "\"install context\": \"other (package /usr/lib/codex, bin /usr/lib/codex/bin, resources /usr/lib/codex/codex-resources, path /usr/lib/codex/codex-path)\""
echo "$d" | grep -qF "\"search command\": \"/usr/lib/codex/codex-path/rg\""
echo "$d" | grep -qF "\"check for update on startup\": \"false\""
u codex features list | grep -E "^daemon_auto_start +.* false$"
# codex update knows no way to update this install and changes nothing, as
# root or as a user.
for c in codex "u codex"; do
  if out=$($c update 2>&1); then echo "codex update succeeded: $out"; exit 1; fi
  echo "$out" | grep -q "Could not detect the Codex installation method"
done
test ! -e /root/.local/bin/codex
test ! -e /home/codextest/.local/bin/codex
test ! -e /home/codextest/.codex/packages
# A user config still wins over ours.
u "mkdir -p ~/.codex && printf \"[features]\ndaemon_auto_start = true\n\" >~/.codex/config.toml"
u codex features list | grep -E "^daemon_auto_start +.* true$"
userdel -r codextest 2>/dev/null || true'

# Tags are "rust-vX.Y.Z", with many "-alpha.N" prereleases in between. Pages
# of 100 releases time out on GitHub's side, so ask for 30 (still several
# stable releases).
versions() {
  gh api "repos/$UPSTREAM/releases?per_page=30" \
    --jq '.[] | select(.draft | not) | select(.prerelease | not) | .tag_name
      | select(test("^rust-v[0-9]+\\.[0-9]+\\.[0-9]+$")) | sub("^rust-v"; "")'
}

# The package tarballs use x86_64 / aarch64 musl targets.
codex_target() { echo "$(rpm_arch "$1")-unknown-linux-musl"; }

# fetch BASE TARGET: download, verify and unpack codex-package-TARGET.tar.gz
# into dl/TARGET. These are the archives the official installer
# (chatgpt.com/codex/install.sh) installs; there are -bazel builds of the same
# too, which it doesn't use. Each asset also has a .sigstore bundle, which
# would need cosign; we rely on the SHA256SUMS file like the installer does.
fetch() {
  [[ -d dl/$2 ]] && return 0
  download "$1/codex-package-$2.tar.gz" "dl/codex-package-$2.tar.gz"
  verify_sums dl/codex-package_SHA256SUMS "dl/codex-package-$2.tar.gz"
  mkdir "dl/$2"
  tar -xzf "dl/codex-package-$2.tar.gz" -C "dl/$2"
}

prepare() {
  local version=$1 base=https://github.com/$UPSTREAM/releases/download/rust-v$1 target host f s
  target=$(codex_target "$2")
  download "$base/codex-package_SHA256SUMS" dl/codex-package_SHA256SUMS
  fetch "$base" "$target"
  jq -e --arg v "$version" --arg t "$target" \
    '.layoutVersion == 1 and .version == $v and .target == $t and .entrypoint == "bin/codex"' \
    "dl/$target/codex-package.json" >/dev/null || die "unexpected codex-package.json for $version $target"
  for f in bin/codex bin/codex-code-mode-host codex-path/rg codex-resources/bwrap; do
    [[ -f dl/$target/$f ]] || die "codex-package-$target.tar.gz has no $f"
  done
  # codex, the code-mode host and bwrap are static musl binaries. rg is too on
  # x86_64, but on aarch64 it's ripgrep's glibc build. The voice host under
  # codex-resources/voice is a glibc build with its own GStreamer libraries
  # next to it. (check_glibc only gets the dynamic ones: objdump -T fails on
  # a non-PIE static binary, as the aarch64 ones are.)
  for f in bin/codex bin/codex-code-mode-host codex-resources/bwrap; do
    ! objdump -p "dl/$target/$f" | grep NEEDED >/dev/null || die "$f is not statically linked"
  done
  while IFS= read -r -d '' f; do
    if [[ $(head -c4 "$f" | od -An -tx1 | tr -d ' ') == 7f454c46 ]] && objdump -p "$f" | grep NEEDED >/dev/null; then
      check_glibc "$f"
    fi
  done < <(find "dl/$target" -type f -print0)
  # The whole tree goes to /usr/lib/codex unchanged: codex finds its helpers
  # relative to its own (resolved) path through codex-package.json.
  mv "dl/$target" codex
  download "https://raw.githubusercontent.com/$UPSTREAM/rust-v$version/LICENSE" LICENSE
  download "https://raw.githubusercontent.com/$UPSTREAM/rust-v$version/NOTICE" NOTICE

  # Shell completions come from the binary itself; use one the build host can
  # run. codex wants a writable CODEX_HOME even for this.
  host=$(codex_target "$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')")
  if [[ $host == "$target" ]]; then
    f=codex/bin/codex
  else
    fetch "$base" "$host"
    f=dl/$host/bin/codex
  fi
  mkdir -p dl/home
  for s in bash zsh fish; do
    HOME=$PWD/dl/home CODEX_HOME=$PWD/dl/home "$f" completion "$s" >"codex.$s" 2>/dev/null
    [[ -s codex.$s ]] || die "codex completion printed nothing for $s"
  done
}
