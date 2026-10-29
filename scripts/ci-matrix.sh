#!/usr/bin/env bash
# Usage: ci-matrix.sh BASE_COMMIT
# Decides what CI has to test for the changes since BASE_COMMIT and prints
# GitHub step outputs:
#   matrix=[...]  latest release of each branch of the packages to build
#   all=true|false  whether shared code changed, so every package has to run
#   repo=true|false  whether to run the repository end-to-end test
#
# What a change rebuilds:
#   packages/NAME/            NAME
#   packages/_shared/X/       the packages that link to or source it
#   tests/NAME.sh             the packages it tests (tests/nodejs.sh: nodejs*)
#   tests/repo.sh, tests/retention.sh   no package; repo runs the e2e test
#   docs, site/, versions.json          nothing
#   anything else (scripts/, workflows)  everything
# Without a usable base, test everything.

source "$(dirname "$0")/lib.sh"

base=${1:-}
all=true repo=true
names=()
if [[ -n $base ]] && changed=$(git -C "$ROOT" diff --name-only "$base" HEAD 2>/dev/null); then
  all=false repo=false
  while read -r f; do
    case $f in
      *.md | site/* | .github/ISSUE_TEMPLATE/* | versions.json) ;;
      packages/_shared/*)
        shared=${f#packages/_shared/}
        shared=${shared%%/*}
        while read -r link; do
          names+=("$(basename "$(dirname "$link")")")
        done < <(
          find "$ROOT/packages" -mindepth 2 -maxdepth 2 -type l -lname "../_shared/$shared/*"
          grep -l "_shared/$shared/" "$ROOT"/packages/*/package.sh
        )
        ;;
      packages/*/*) names+=("$(cut -d/ -f2 <<< "$f")") ;;
      tests/repo.sh | tests/retention.sh) repo=true ;;
      tests/*.sh)
        prefix=$(basename "$f" .sh)
        for d in "$ROOT"/packages/"$prefix"*/; do names+=("$(basename "$d")"); done
        ;;
      *) all=true repo=true ;;
    esac
  done <<< "$changed"
fi

if $all; then
  matrix=$(VERSIONS_FILE=/dev/null "$ROOT/scripts/check.sh")
else
  # Only packages that still exist (a removed one has nothing to build).
  mapfile -t names < <(for n in "${names[@]}"; do [[ -f $ROOT/packages/$n/package.sh ]] && echo "$n"; done | sort -u)
  if [[ ${#names[@]} -gt 0 ]]; then
    matrix=$(VERSIONS_FILE=/dev/null "$ROOT/scripts/check.sh" "${names[@]}")
  else
    matrix='[]'
  fi
fi

echo "all=$all"
echo "repo=$repo"
echo "matrix=$matrix"
