# shellcheck shell=bash
# Shared helpers. Sourced by the other scripts and by packages/*/package.sh.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DIST=${DIST:-$ROOT/dist}
WORK=${WORK:-$ROOT/work}
VERSIONS_FILE=${VERSIONS_FILE:-$ROOT/versions.json}

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
# A GitHub Actions annotation when running there, a plain line otherwise.
warn() { if [[ -n ${GITHUB_ACTIONS:-} ]]; then printf '::warning::%s\n' "$*" >&2; else printf 'warning: %s\n' "$*" >&2; fi; }

# Map a Debian arch (what nfpm and our matrix use) to other spellings.
rpm_arch() { case $1 in amd64) echo x86_64 ;; arm64) echo aarch64 ;; *) die "unknown arch $1" ;; esac; }

# download URL DEST
download() {
  log "download $1"
  curl -fsSL --retry 3 --retry-delay 5 -o "$2" "$1"
}

# verify_sha256 FILE SHA256
verify_sha256() {
  echo "$2  $1" | sha256sum -c --quiet - || die "sha256 mismatch for $1"
}

# verify_sums SUMS_FILE FILE: check FILE against a sha256sum- or
# sha512sum-style list; the length of the hash tells which.
verify_sums() {
  local name sum
  name=$(basename "$2")
  sum=$(awk -v f="$name" '$2 == f || $2 == "*" f || $2 == "./" f { print $1; exit }' "$1")
  [[ -n $sum ]] || die "no checksum for $name in $(basename "$1")"
  case ${#sum} in
    64) verify_sha256 "$2" "$sum" ;;
    128) echo "$sum  $2" | sha512sum -c --quiet - || die "sha512 mismatch for $2" ;;
    *) die "unrecognised checksum for $name in $(basename "$1")" ;;
  esac
}

# Oldest glibc among the supported releases (EL9: 2.34, Ubuntu 22.04: 2.35,
# Debian 12: 2.36). Upstream glibc builds must not need anything newer.
MAX_GLIBC=2.34

# check_glibc FILE...: fail if a dynamically linked binary needs a glibc newer
# than MAX_GLIBC. Use it in prepare() for every gnu (non-musl) build.
check_glibc() {
  local f need
  for f in "$@"; do
    need=$(objdump -T "$f" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | cut -d_ -f2 | sort -uV | tail -n1)
    [[ -z $need ]] && continue
    [[ $(printf '%s\n%s\n' "$need" "$MAX_GLIBC" | sort -V | tail -n1) == "$MAX_GLIBC" ]] ||
      die "$(basename "$f") needs glibc $need, newer than the supported $MAX_GLIBC; use the musl build"
  done
}

# gh_versions OWNER/REPO [COUNT]: recent stable release versions, newest first, "v" stripped.
gh_versions() {
  gh api "repos/$1/releases?per_page=${2:-100}" \
    --jq '.[] | select(.draft | not) | select(.prerelease | not) | .tag_name | sub("^v"; "")'
}

# load_package NAME: source packages/NAME/package.sh with defaults applied.
load_package() {
  local dir=$ROOT/packages/$1
  [[ -f $dir/package.sh ]] || die "unknown package $1"
  PKG_NAME=$1
  PKG_DIR=$dir
  UPSTREAM=
  ARCHS=(amd64 arm64)
  RELEASE=1
  BRANCHES=()
  TEST_CMD=
  unset -f versions prepare
  # Default: stable GitHub releases of $UPSTREAM.
  versions() { gh_versions "$UPSTREAM"; }
  # shellcheck source=/dev/null
  source "$dir/package.sh"
  declare -F prepare >/dev/null || die "$1: package.sh must define prepare()"
  [[ ${#BRANCHES[@]} -gt 0 ]] || die "$1: package.sh must set BRANCHES"
}

# branch_of VERSION: the entry of BRANCHES (of the loaded package) that
# VERSION belongs to. "1.27" matches 1.27.x, "28" matches 28.x.y.
branch_of() {
  local b
  for b in "${BRANCHES[@]}"; do
    [[ $1 == "$b" || $1 == "$b".* ]] && { echo "$b"; return 0; }
  done
  return 1
}

# version_gt FORMAT A B: whether package version A is newer than B.
version_gt() {
  if [[ $1 == deb ]]; then
    dpkg --compare-versions "$2" gt "$3"
  else
    [[ $2 != "$3" && $(printf '%s\n%s\n' "$2" "$3" | sort -V | tail -n1) == "$2" ]]
  fi
}

# stale FORMAT: reads "NAME VERSION FILE" lines of one index and prints the
# FILEs to drop: every build of a package in packages/ that is not the newest
# one of a branch in its BRANCHES. Anything else in the index is left alone.
stale() {
  local fmt=$1 name version file upstream branch key
  local -A best=() best_file=()
  local -a entries=()
  while read -r name version file; do
    entries+=("$name $version $file")
    [[ -f $ROOT/packages/$name/package.sh ]] || continue
    load_package "$name"
    upstream=${version#*:}
    upstream=${upstream%-*}
    branch=$(branch_of "$upstream") || continue
    key=$name@$branch
    if [[ -z ${best[$key]:-} ]] || version_gt "$fmt" "$version" "${best[$key]}"; then
      best[$key]=$version best_file[$key]=$file
    fi
  done
  local -A keep=()
  for file in "${best_file[@]}"; do keep[$file]=1; done
  for entry in "${entries[@]}"; do
    read -r name version file <<< "$entry"
    [[ -f $ROOT/packages/$name/package.sh && -z ${keep[$file]:-} ]] && echo "$file"
  done
  return 0
}

list_packages() {
  local d
  for d in "$ROOT"/packages/*/package.sh; do basename "$(dirname "$d")"; done
}

# published_versions NAME: versions already in the repository, one per line.
published_versions() {
  [[ -f $VERSIONS_FILE ]] || return 0
  jq -r --arg p "$1" '.[$p] // [] | .[]' "$VERSIONS_FILE"
}
