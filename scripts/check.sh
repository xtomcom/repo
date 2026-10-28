#!/usr/bin/env bash
# Usage: check.sh [NAME[@VERSION]...]
# Prints a JSON array of {package, version, arch} entries to build.
#
# Each package lists the upstream branches we carry in BRANCHES (e.g. Go's
# "1.27 1.26", Gitea's "28"). We publish the newest release of every listed
# branch and nothing else; publish.sh removes the older ones. A release newer
# than every listed branch only raises a warning, since moving to a new major
# version is a decision for a human.
#
# versions.json records VERSION-RELEASE, so bumping RELEASE in package.sh
# republishes the current release with the packaging fix. NAME@VERSION forces
# that exact version.

source "$(dirname "$0")/lib.sh"

names=("$@")
[[ ${#names[@]} -gt 0 ]] || mapfile -t names < <(list_packages)

for arg in "${names[@]}"; do
  name=${arg%@*}
  load_package "$name"
  todo=()
  if [[ $arg == *@* ]]; then
    todo=("${arg#*@}")
  else
    mapfile -t upstream < <(versions | sort -rV)
    [[ ${#upstream[@]} -gt 0 ]] || die "$name: no upstream versions found"
    mapfile -t published < <(published_versions "$name")
    branch_of "${upstream[0]}" >/dev/null ||
      warn "$name ${upstream[0]} is newer than BRANCHES (${BRANCHES[*]}); add its branch to packages/$name/package.sh"
    for branch in "${BRANCHES[@]}"; do
      latest=
      for v in "${upstream[@]}"; do
        [[ $(branch_of "$v") == "$branch" ]] && { latest=$v; break; }
      done
      if [[ -z $latest ]]; then
        warn "$name: no upstream release in branch $branch"
      elif [[ " ${published[*]} " != *" $latest-$RELEASE "* ]]; then
        # New upstream release, or a new RELEASE of the current one.
        todo+=("$latest")
      fi
    done
  fi

  for v in "${todo[@]}"; do
    for a in "${ARCHS[@]}"; do
      jq -nc --arg p "$name" --arg v "$v" --arg a "$a" '{package: $p, version: $v, arch: $a}'
    done
  done
done | jq -sc .
