# shellcheck shell=bash
# Shared by packages/nodejs-NN (one per Node.js LTS line) and the nodejs
# metapackage. A package.sh sets NODE_MAJOR and sources this file.
#
# nodejs-NN installs the official build from nodejs.org, unchanged, under
# /usr/lib/nodejs-NN, plus /usr/bin/{node,npm,npx,corepack}-NN. Several lines
# can be installed at once: /usr/bin/node and friends belong to the
# alternatives group "node", where the newest major has the highest priority.
# Epoch 1 on every package (RHEL's nodejs has epoch 1, Debian and NodeSource
# none) so we sort above the distributions' builds of the same version.

# The newest LTS line: what the nodejs metapackage depends on, and the bound
# below which the RHEL "nodejs" package is replaced (see nfpm.yaml).
NODE_LTS=26

BRANCHES=("${NODE_MAJOR:-$NODE_LTS}")

# Node.js release keys from https://github.com/nodejs/release-keys, pinned to
# a commit. gpg/pubring.kbx holds every key that ever signed a release, so
# older lines verify too. A release signed by a newly added releaser fails
# with "bad signature"; then move the pin to a commit that has the new key.
NODE_KEYS_COMMIT=481637f813e912c4aa3622d7964ab426c97b8e8d
NODE_KEYS_SHA256=610b8d249da3d5733f5a128def2dd0294dbbf5b5713e6ca2529db8db419dee00

TEST_CMD='
v=$(basename "${PKG%% *}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
m=${v%%.*}
test "$(node -v)" = "v$v"
test "$(nodejs -v)" = "v$v"
test "$(node-$m -v)" = "v$v"
test "$(readlink -f /usr/bin/node)" = /usr/lib/nodejs-$m/bin/node
node -e "require(\"assert\").strictEqual(new Intl.DateTimeFormat(\"de\", {month: \"long\"}).format(new Date(2026, 2)), \"März\")"
# npm, npx and corepack always run under their own node, also for the
# commands they start.
npm -v
test "$(npm-$m -v)" = "$(npm -v)"
npx -v
cd /tmp
test "$(npm exec -c "node -v")" = "v$v"
test "$(npm-$m exec -c "node -v")" = "v$v"
if [ -d /usr/lib/nodejs-$m/lib/node_modules/corepack ]; then
  corepack -v
  test "$(corepack-$m -v)" = "$(corepack -v)"
else
  test ! -e /usr/bin/corepack && test ! -e /usr/bin/corepack-$m
fi
# Global installs go to /usr/local, never into the package.
test "$(npm config get prefix)" = /usr/local
test "$(npm config get globalconfig)" = /etc/npmrc
npm install -g --no-audit --no-fund semver@7.7.2
test "$(semver 1.2.3)" = 1.2.3
test -f /usr/local/lib/node_modules/semver/package.json
test "$(readlink -f /usr/local/bin/semver)" = /usr/local/lib/node_modules/semver/bin/semver.js
npm uninstall -g semver
test ! -e /usr/local/bin/semver
# Headers for node-gyp; the man page through alternatives.
test -f /usr/lib/nodejs-$m/include/node/node.h
test -f /usr/lib/nodejs-$m/include/node/node_api.h
{ dpkg -L nodejs-$m 2>/dev/null || rpm -ql nodejs-$m; } | grep -qx /usr/lib/nodejs-$m/share/man/man1/node.1.gz
test "$(readlink -f /usr/share/man/man1/node.1.gz)" = /usr/lib/nodejs-$m/share/man/man1/node.1.gz
update-alternatives --display node | grep -q "/usr/lib/nodejs-$m/bin/node - priority ${m}0"
'

node_index() { curl -fsSL --retry 3 https://nodejs.org/dist/index.json; }

# LTS releases of NODE_MAJOR (of every line for the metapackage), newest first.
versions() {
  node_index | jq -r --arg m "${NODE_MAJOR:-}" '.[] | select(.lts) | .version | ltrimstr("v")
    | select($m == "" or startswith($m + "."))'
}

# node_arch ARCH: the architecture in nodejs.org file names.
node_arch() { case $1 in amd64) echo x64 ;; arm64) echo arm64 ;; *) die "unknown arch $1" ;; esac; }

prepare() {
  local version=$1 major=${1%%.*} base=https://nodejs.org/dist/v$1 file gnupg fpr npm abi c
  [[ $major == "$NODE_MAJOR" ]] || die "$version is not a Node.js $NODE_MAJOR release"
  file=node-v$version-linux-$(node_arch "$2").tar.xz

  # SHASUMS256.txt.asc is clearsigned by a releaser: check it against the
  # pinned keyring and only trust the checksums inside the signed body.
  download "https://raw.githubusercontent.com/nodejs/release-keys/$NODE_KEYS_COMMIT/gpg/pubring.kbx" dl/pubring.kbx
  verify_sha256 dl/pubring.kbx "$NODE_KEYS_SHA256"
  download "$base/SHASUMS256.txt.asc" dl/SHASUMS256.txt.asc
  gnupg=$(mktemp -d)
  cp dl/pubring.kbx "$gnupg/"
  fpr=$(gpg --homedir "$gnupg" --status-fd 1 -q -o dl/SHASUMS256.txt --decrypt dl/SHASUMS256.txt.asc 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }')
  rm -rf "$gnupg"
  [[ -n $fpr ]] || die "bad signature on SHASUMS256.txt (a new release key? see NODE_KEYS_COMMIT)"

  download "$base/$file" "dl/$file"
  verify_sums dl/SHASUMS256.txt "dl/$file"
  mkdir node
  tar -xJf "dl/$file" -C node --strip-components=1 --no-same-owner
  check_glibc node/bin/node
  [[ $(sed -n 's/^#define NODE_MAJOR_VERSION \([0-9]*\)$/\1/p' node/include/node/node_version.h) == "$major" ]] ||
    die "unexpected node_version.h in $file"
  npm=$(jq -r .version node/lib/node_modules/npm/package.json)
  abi=$(sed -n 's/^#define NODE_MODULE_VERSION \([0-9]*\)$/\1/p' node/include/node/node_version.h)
  [[ -n $npm && -n $abi ]] || die "cannot tell the npm version or module ABI of $file"
  cp node/LICENSE LICENSE

  # npm's builtin config (<npm>/npmrc, below the user's and /etc/npmrc): global
  # installs go to /usr/local like with Debian's and Fedora's npm, never into
  # the package's own files; npm cannot update itself here anyway.
  cat >node/lib/node_modules/npm/npmrc <<'EOF'
# Configuration for npm from the nodejs-NN packages. Do not edit: settings in
# /etc/npmrc and ~/.npmrc override these.
globalconfig=/etc/npmrc
prefix=/usr/local
update-notifier=false
EOF
  gzip -9n node/share/man/man1/node.1

  # npm-NN & co. run their script with node-NN, and put node-NN first on PATH
  # so the scripts and tools they start get the same node, not the default
  # one. The upstream bin/npm etc. are "#!/usr/bin/env node" symlinks.
  for c in npm:npm/bin/npm-cli.js npx:npm/bin/npx-cli.js corepack:corepack/dist/corepack.js; do
    [[ -f node/lib/node_modules/${c#*:} ]] || continue
    cat >"${c%%:*}-$major" <<EOF
#!/bin/sh
# ${c%%:*} from Node.js $major, run by Node.js $major.
PATH=/usr/lib/nodejs-$major/bin:\$PATH
export PATH
exec /usr/lib/nodejs-$major/bin/node /usr/lib/nodejs-$major/lib/node_modules/${c#*:} "\$@"
EOF
    chmod 755 "${c%%:*}-$major"
  done
  # Node.js 25 and later no longer ship corepack.
  [[ -f corepack-$major ]] || sed -i '/#corepack$/d' nfpm.yaml

  sed -i -e "s/@MAJOR@/$major/g" -e "s/@LTS@/$NODE_LTS/g" -e "s/@NPM@/$npm/g" -e "s/@ABI@/$abi/g" \
    -e "s/@RPMISA@/$(case $2 in amd64) echo x86-64 ;; *) echo aarch-64 ;; esac)/g" \
    -e "s/@PRIORITY@/${major}0/g" nfpm.yaml alternatives.sh preremove.sh
}
