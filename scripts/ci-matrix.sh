#!/usr/bin/env bash
# Usage: ci-matrix.sh BASE_COMMIT
# Decides what CI has to test for the changes since BASE_COMMIT and prints
# GitHub step outputs:
#   matrix=[...]  latest release of each branch of the packages to build
#   all=true|false  whether shared code changed, so every package (and the
#                   repository end-to-end test) has to run
# A change limited to packages/NAME/ only rebuilds NAME; docs, the site README
# and versions.json rebuild nothing. Without a usable base, test everything.

source "$(dirname "$0")/lib.sh"

base=${1:-}
all=true
names=()
if [[ -n $base ]] && changed=$(git -C "$ROOT" diff --name-only "$base" HEAD 2>/dev/null); then
  # packages/_shared/ is linked into several packages, so it counts as shared.
  shared=$(grep -vE '^(packages/[^_]|site/|\.github/ISSUE_TEMPLATE/|versions\.json$)|\.md$' <<< "$changed" || true)
  if [[ -z $shared ]]; then
    all=false
    while read -r name; do
      [[ -f $ROOT/packages/$name/package.sh ]] && names+=("$name")
    done < <(sed -n 's#^packages/\([^/]*\)/.*#\1#p' <<< "$changed" | sort -u)
  fi
fi

if $all; then
  matrix=$(VERSIONS_FILE=/dev/null "$ROOT/scripts/check.sh")
elif [[ ${#names[@]} -gt 0 ]]; then
  matrix=$(VERSIONS_FILE=/dev/null "$ROOT/scripts/check.sh" "${names[@]}")
else
  matrix='[]'
fi

echo "all=$all"
echo "matrix=$matrix"
