#!/usr/bin/env bash
# Usage: publish.sh
# Adds every .deb/.rpm in dist/ to the repository at $REPO_DEST, keeps only the
# newest build of each package's BRANCHES, signs the indexes, uploads, deletes
# the superseded files, purges the Cloudflare cache and rewrites versions.json.
#
# Only metadata is pulled from the server; existing packages are never
# downloaded. The deb index is merged as text. For rpm, createrepo_c --update
# --skip-stat reuses the old metadata of every package we keep, so those only
# need an empty placeholder file of the same name.
#
# Environment:
#   REPO_DEST       rsync destination, e.g. user@rsync.repo.xtom.com:/home/xtom/repo.xtom.com
#                   (a local directory works too, which is what the tests use)
#   GPG_KEY_ID      signing key, already imported into the gpg keyring
#   GPG_PASSPHRASE  optional
#   PUBLIC_URL      default https://repo.xtom.com
#   CF_ZONE_ID, CF_API_TOKEN   optional; the cache purge is skipped without them
#   RSYNC_RSH       ssh command for rsync, set by the workflow

source "$(dirname "$0")/lib.sh"

: "${REPO_DEST:?}" "${GPG_KEY_ID:?}"
PUBLIC_URL=${PUBLIC_URL:-https://repo.xtom.com}
DEB_ARCHS=(amd64 arm64)
RPM_ARCHS=(x86_64 aarch64)
EL_LINKS=(el9 el10) # old per-release rpm paths, kept as symlinks for existing configs
EL_DROPPED=(el8)    # unsupported releases, removed from the server

# remote_delete DIR FILE...: delete these files in $REPO_DEST/DIR, nothing else.
remote_delete() {
  local dir=$1 f
  shift
  local -a filters=()
  for f in "$@"; do filters+=("--include=/$f"); done
  log "delete from $dir: $*"
  rsync -r --delete "${filters[@]}" --exclude='*' "$WORK/empty/" "$REPO_DEST/$dir/"
}

# drop_release NAME VERSION: leave this release out of the publish, all
# architectures; the next run retries it.
drop_release() {
  load_package "$1"
  rm -f "${DIST:?}/manifest/${1:?}@${2:?}@"* "${DIST:?}/${1:?}_${2:?}-${RELEASE:?}_"*.deb \
    "${DIST:?}/${1:?}-${2:?}-${RELEASE:?}".xtom.*.rpm
}

# A release goes out only when every architecture built and passed its tests.
shopt -s nullglob
for m in "$DIST"/manifest/*@*@*; do
  m=$(basename "$m")
  name=${m%%@*} rest=${m#*@}
  version=${rest%@*}
  load_package "$name"
  for a in "${ARCHS[@]}"; do
    [[ -e $DIST/manifest/$name@$version@$a ]] && continue
    warn "skip $name $version: not every architecture passed"
    drop_release "$name" "$version"
    break
  done
done
shopt -u nullglob
[[ -n $(find "$DIST" -maxdepth 1 \( -name '*.deb' -o -name '*.rpm' \)) ]] || die "nothing to publish in $DIST"

repo=$WORK/repo
rm -rf "${repo:?}" "${WORK:?}/rpm-build" "${WORK:?}/empty"
mkdir -p "$repo" "$WORK/empty"

gpg_args=(--batch --yes --local-user "$GPG_KEY_ID")
if [[ -n ${GPG_PASSPHRASE:-} ]]; then
  # A file, so spaces or % in the passphrase survive rpmsign's macro expansion.
  install -m600 /dev/null "$WORK/passphrase"
  printf '%s' "$GPG_PASSPHRASE" > "$WORK/passphrase"
  gpg_args+=(--pinentry-mode loopback --passphrase-file "$WORK/passphrase")
fi

log "pull metadata from $REPO_DEST"
rsync -a --checksum --prune-empty-dirs \
  --include='*/' --include='/deb/dists/***' --include='/rpm/*/repodata/***' --exclude='*' \
  "$REPO_DEST/" "$repo/"
# Every package file on the server, indexed or not: a publish that failed
# before its indexes went up leaves files that no index lists.
rsync -r --list-only --include='/rpm/' --include='/rpm/*/' --include='/rpm/*/Packages/' \
  --include='/rpm/*/Packages/*.rpm' --include='/deb/' --include='/deb/pool/***' --exclude='*' "$REPO_DEST/" |
  awk '$NF ~ /\.(rpm|deb)$/ { print $NF }' > "$WORK/remote-files"
sed -n 's|^rpm/||p' "$WORK/remote-files" > "$WORK/remote-rpms"

# indexed_rpms ARCH: Packages/X.rpm for every file in that arch's metadata.
indexed_rpms() {
  local dir=$repo/rpm/$1 primary
  [[ -f $dir/repodata/repomd.xml ]] || return 0
  primary=$(grep -o 'href="repodata/[^"]*-primary\.xml[^"]*"' "$dir/repodata/repomd.xml" | cut -d'"' -f2)
  case $primary in
    *.zst) zstd -dcq "$dir/$primary" ;;
    *.xz) xz -dc "$dir/$primary" ;;
    *.gz) gzip -dc "$dir/$primary" ;;
    *) die "unknown primary metadata '$primary' for $1" ;;
  esac | { grep -o '<location href="Packages/[^"]*"' || true; } | cut -d'"' -f2
}
for arch in "${RPM_ARCHS[@]}"; do indexed_rpms "$arch" | sed "s|^|$arch/|"; done > "$WORK/indexed-rpms"
find "$repo/deb/dists" -path '*/binary-*/Packages' -exec sed -n 's/^Filename: //p' {} + 2>/dev/null |
  sort -u > "$WORK/indexed-debs" || true

# Pool files are cached by the CDN and by clients forever, so a file name must
# never get new content. A file that is already indexed (a rerun after a
# publish whose last steps failed) keeps the server's copy; rebuilding a
# release on purpose needs a new RELEASE.
shopt -s nullglob
for f in "$DIST"/*.deb "$DIST"/*.rpm; do
  if grep -qF "/$(basename "$f")" "$WORK/indexed-debs" "$WORK/indexed-rpms"; then
    warn "$(basename "$f") is already published, keeping the server's copy (bump RELEASE to rebuild it)"
    rm "$f"
  fi
done

# A package that depends on one of ours (golang on golang-1.27, nodejs on
# nodejs-26) goes out only with that version in the repository or in this
# publish, else it waits for the next run. Checked on the deb fields, applied
# to both formats; repeated, since leaving one out can break another.
# avail ARCH: "NAME VERSION" of everything the deb index and this publish offer.
avail() {
  local f
  if [[ -f $repo/deb/dists/stable/main/binary-$1/Packages ]]; then
    awk -v RS= '{
        for (i = 1; i <= split($0, l, "\n"); i++) { split(l[i], kv, ": "); f[kv[1]] = kv[2] }
        print f["Package"], f["Version"]
      }' "$repo/deb/dists/stable/main/binary-$1/Packages"
  fi
  for f in "$DIST"/*_"$1".deb "$DIST"/*_all.deb; do
    echo "$(dpkg-deb -f "$f" Package) $(dpkg-deb -f "$f" Version)"
  done
}
# satisfied DEPENDS ARCH: whether every dependency on a package of ours is met.
satisfied() {
  local list clause alt dep op ver ok n v
  list=$(avail "$2")
  while read -r clause; do
    [[ -n $clause ]] || continue
    ok=false
    while read -r alt; do
      read -r dep op ver <<< "${alt//[()]/ }"
      dep=${dep%%:*}
      # Not one of ours: the distribution provides it.
      [[ -f $ROOT/packages/$dep/package.sh ]] || { ok=true; break; }
      while read -r n v; do
        [[ $n == "$dep" ]] || continue
        if [[ -z $op ]] || dpkg --compare-versions "$v" "$op" "$ver"; then ok=true; break 2; fi
      done <<< "$list"
    done < <(tr '|' '\n' <<< "$clause")
    $ok || return 1
  done < <(tr ',' '\n' <<< "$1")
}
while :; do
  changed=false
  for f in "$DIST"/*.deb; do
    [[ -e $f ]] || continue
    arch=$(dpkg-deb -f "$f" Architecture)
    [[ $arch != all ]] || arch=${DEB_ARCHS[0]}
    satisfied "$(dpkg-deb -f "$f" Depends)" "$arch" && continue
    name=$(dpkg-deb -f "$f" Package)
    version=$(dpkg-deb -f "$f" Version)
    version=${version#*:}
    warn "skip $name ${version%-*}: a package of ours it depends on is neither published nor in this run"
    drop_release "$name" "${version%-*}"
    changed=true
  done
  $changed || break
done

debs=("$DIST"/*.deb)
rpms=("$DIST"/*.rpm)
shopt -u nullglob
# Nothing new still refreshes the indexes, so a rerun finishes the retention
# and cleanup of a publish that failed midway.
[[ ${#debs[@]} -gt 0 || ${#rpms[@]} -gt 0 ]] || log "no new packages, refreshing the indexes"

# Packages in versions.json whose directory is gone from packages/ have been
# retired (e.g. an upstream branch reached end of life): drop all their builds.
RETIRED=
if [[ -f $VERSIONS_FILE ]]; then
  RETIRED=$(jq -r 'keys[]' "$VERSIONS_FILE" | while read -r name; do
    [[ -f $ROOT/packages/$name/package.sh ]] || echo "$name"
  done | xargs)
fi
[[ -z $RETIRED ]] || log "retire $RETIRED"

# --- deb -------------------------------------------------------------------

for f in "${debs[@]}"; do
  name=$(dpkg-deb -f "$f" Package)
  case $name in lib?*) prefix=${name:0:4} ;; *) prefix=${name:0:1} ;; esac
  install -Dm644 "$f" "$repo/deb/pool/main/$prefix/$name/$(basename "$f")"
done

dists=$repo/deb/dists/stable
drop_debs=()
for arch in "${DEB_ARCHS[@]}"; do
  dir=$dists/main/binary-$arch
  mkdir -p "$dir"
  touch "$dir/Packages"
  if [[ -d $repo/deb/pool ]]; then
    (cd "$repo/deb" && apt-ftparchive --arch "$arch" packages pool) >> "$dir/Packages"
  fi
  mapfile -t drop < <(awk -v RS= '{
      for (i = 1; i <= split($0, l, "\n"); i++) { split(l[i], kv, ": "); f[kv[1]] = kv[2] }
      print f["Package"], f["Version"], f["Filename"]
    }' "$dir/Packages" | stale deb)
  printf '%s\n' "${drop[@]}" > "$WORK/drop"
  awk -v RS= -v ORS='\n\n' 'NR == FNR { if ($0 != "") drop["Filename: " $0] = 1; next }
    { for (i = 1; i <= split($0, l, "\n"); i++) if (l[i] in drop) next; print }' \
    RS='\n' "$WORK/drop" RS= "$dir/Packages" > "$dir/Packages.tmp"
  mv "$dir/Packages.tmp" "$dir/Packages"
  gzip -9nkf "$dir/Packages"
  xz -kf "$dir/Packages"
  drop_debs+=("${drop[@]}")
done

# by-hash keeps the files of this Release and the previous one, which caches
# may still serve; older ones are dropped instead of piling up.
touch "$dists/Release"
mv "$dists/Release" "$WORK/Release.old"
rm -f "$dists/Release.gpg" "$dists/InRelease"
apt-ftparchive \
  -o APT::FTPArchive::DoByHash=true \
  -o APT::FTPArchive::Release::Origin=xTom \
  -o APT::FTPArchive::Release::Label="xTom Repository" \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Architectures="${DEB_ARCHS[*]}" \
  -o APT::FTPArchive::Release::Components=main \
  -o APT::FTPArchive::Release::Description="xTom Package Repository" \
  release "$dists" > "$WORK/Release"
mv "$WORK/Release" "$dists/Release"
awk '/^ / { print $1 }' "$WORK/Release.old" "$dists/Release" | sort -u > "$WORK/hashes"
find "$dists" -path '*/by-hash/*' -type f | while read -r f; do
  grep -qxF "$(basename "$f")" "$WORK/hashes" || rm "$f"
done
gpg "${gpg_args[@]}" --armor --detach-sign --output "$dists/Release.gpg" "$dists/Release"
gpg "${gpg_args[@]}" --clearsign --output "$dists/InRelease" "$dists/Release"

# --- rpm -------------------------------------------------------------------

if [[ ${#rpms[@]} -gt 0 ]]; then
  sign=(rpmsign --addsign --define "_gpg_name $GPG_KEY_ID")
  [[ -z ${GPG_PASSPHRASE:-} ]] ||
    sign+=(--define "_gpg_sign_cmd_extra_args --pinentry-mode loopback --passphrase-file $WORK/passphrase")
  for f in "${rpms[@]}"; do
    arch=$(rpm -qp --qf '%{ARCH}' "$f" 2>/dev/null)
    install -Dm644 "$f" "$repo/rpm/$arch/Packages/$(basename "$f")"
    "${sign[@]}" "$repo/rpm/$arch/Packages/$(basename "$f")" >/dev/null
  done
fi

declare -A drop_rpms=()
for arch in "${RPM_ARCHS[@]}"; do
  dir=$repo/rpm/$arch
  build=$WORK/rpm-build/$arch
  mkdir -p "$dir/Packages" "$build/Packages" "$build/repodata"
  # Start from the current metadata only: repomd.xml and the files it names.
  old_md=()
  if [[ -f $dir/repodata/repomd.xml ]]; then
    mapfile -t old_md < <(grep -o 'href="repodata/[^"]*"' "$dir/repodata/repomd.xml" | cut -d'"' -f2 | xargs -rn1 basename)
    for f in repomd.xml "${old_md[@]}"; do cp "$dir/repodata/$f" "$build/repodata/"; done
  fi
  sed -n "s|^$arch/Packages/||p" "$WORK/indexed-rpms" > "$WORK/indexed"

  # NAME-VERSION-RELEASE.ARCH.rpm; names may contain dashes, versions don't.
  mapfile -t drop < <({
    cat "$WORK/indexed"
    ls "$dir/Packages"
  } | awk '{ b = $0; sub(/\.[^.]+\.rpm$/, "", b); n = split(b, p, "-")
      name = p[1]; for (i = 2; i < n - 1; i++) name = name "-" p[i]
      print name, p[n - 1] "-" p[n], $0 }' | stale rpm)
  # Server files that no index lists and this publish doesn't replace are
  # left over from a failed publish.
  while read -r f; do
    grep -qxF "$f" "$WORK/indexed" || [[ -e $dir/Packages/$f ]] || drop+=("$f")
  done < <(sed -n "s|^$arch/Packages/||p" "$WORK/remote-rpms")
  printf '%s\n' "${drop[@]}" > "$WORK/drop"

  # Indexed packages we keep get an empty placeholder; --skip-stat reuses
  # their metadata.
  while read -r f; do
    grep -qxF "$f" "$WORK/drop" || touch "$build/Packages/$f"
  done < "$WORK/indexed"
  for f in "$dir"/Packages/*.rpm; do
    [[ -e $f ]] || continue
    if grep -qxF "$(basename "$f")" "$WORK/drop"; then rm "$f"; else cp "$f" "$build/Packages/"; fi
  done

  if [[ -f $build/repodata/repomd.xml ]]; then
    createrepo_c --quiet --update --skip-stat "$build"
  else
    createrepo_c --quiet "$build"
  fi
  # Keep the previous metadata files next to the new ones: a cached old
  # repomd.xml still names them until the purge reaches every edge.
  for f in "${old_md[@]}"; do
    [[ -e $build/repodata/$f ]] || cp "$dir/repodata/$f" "$build/repodata/"
  done
  rm -rf "${dir:?}/repodata"
  mv "$build/repodata" "$dir/repodata"
  gpg "${gpg_args[@]}" --armor --detach-sign --output "$dir/repodata/repomd.xml.asc" "$dir/repodata/repomd.xml"
  [[ ${#drop[@]} -eq 0 ]] || drop_rpms[$arch]="${drop[*]}"
done

for el in "${EL_LINKS[@]}"; do ln -sfn . "$repo/rpm/$el"; done

cat > "$repo/rpm/xtom.repo" <<EOF
[xtom]
name=xTom Repository
baseurl=$PUBLIC_URL/rpm/\$basearch/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$PUBLIC_URL/xtom.key
EOF
# --- state and README ------------------------------------------------------

# versions.json mirrors what the deb indexes now hold for our packages, as
# VERSION-RELEASE without the epoch.
awk -v RS= '{
    for (i = 1; i <= split($0, l, "\n"); i++) { split(l[i], kv, ": "); f[kv[1]] = kv[2] }
    v = f["Version"]; sub(/^[0-9]+:/, "", v)
    print f["Package"], v
  }' "$dists"/main/binary-*/Packages | sort -u | while read -r name version; do
  if [[ -f $ROOT/packages/$name/package.sh ]]; then echo "$name $version"; fi
done | jq -Rn '[inputs | split(" ") | {key: .[0], value: .[1]}] | group_by(.key)
  | map({key: .[0].key, value: map(.value) | sort_by([splits("[.-]")] | map(tonumber? // .)) | reverse})
  | from_entries' > "$VERSIONS_FILE"

# The README on the site is site/README.md with the package table filled in.
# xtom.key on the server is maintained by hand and never touched here.
{
  echo '| Package | Version | Architectures | Description |'
  echo '|---|---|---|---|'
  for name in $(jq -r 'keys[]' "$VERSIONS_FILE"); do
    load_package "$name"
    printf '| [%s](%s) | %s | %s | %s |\n' "$name" \
      "$(sed -n 's/^homepage: //p' "$PKG_DIR/nfpm.yaml")" \
      "$(jq -r --arg n "$name" '.[$n] | map(sub("-[^-]*$"; "")) | join(", ")' "$VERSIONS_FILE")" \
      "${ARCHS[*]}" "$(sed -n '/^description:/{n;s/^ *//p}' "$PKG_DIR/nfpm.yaml")"
  done
} > "$WORK/packages.md"
sed -e "/<!-- packages -->/{r $WORK/packages.md" -e 'd}' "$ROOT/site/README.md" > "$repo/README.md"

# --- upload ----------------------------------------------------------------

# Packages first, indexes last, superseded files after that: clients never see
# an index entry whose file is missing.
# Metadata uses --checksum: a Release regenerated within the same second can
# have the same size and mtime, which rsync's quick check would skip.
log "upload packages"
rsync -a --include='/deb/' --include='/deb/pool/***' --include='/rpm/' --include='/rpm/*/' \
  --include='/rpm/*/Packages/***' --exclude='*' "$repo/" "$REPO_DEST/"

log "upload indexes"
rsync -a --checksum --delay-updates --exclude='/deb/' --exclude='repodata/' --exclude='/rpm/*/Packages/' \
  --exclude='/rpm/el*' "$repo/" "$REPO_DEST/"
rsync -a --checksum --delay-updates --delete-after "$repo/deb/dists/" "$REPO_DEST/deb/dists/"
for arch in "${RPM_ARCHS[@]}"; do
  rsync -a --checksum --delay-updates --delete-after "$repo/rpm/$arch/repodata/" "$REPO_DEST/rpm/$arch/repodata/"
done
# Point the old per-release paths at the shared tree, replacing the real
# directories of the old layout, and remove those of unsupported releases.
# --delete is limited to these paths.
filters=()
for el in "${EL_LINKS[@]}" "${EL_DROPPED[@]}"; do filters+=("--include=/$el" "--include=/$el/***"); done
rsync -a --force --delete "${filters[@]}" --exclude='*' "$repo/rpm/" "$REPO_DEST/rpm/"

# Pool files no index lists any more: superseded ones and leftovers of a
# failed publish.
sed -n 's/^Filename: //p' "$dists"/main/binary-*/Packages | sort -u > "$WORK/final-debs"
while read -r f; do
  grep -qxF "$f" "$WORK/final-debs" || drop_debs+=("$f")
done < <(sed -n 's|^deb/||p' "$WORK/remote-files")

# --- cache -----------------------------------------------------------------

# purge PATH...: purge these URLs, at most 30 per API call.
purge() {
  local i
  for ((i = 1; i <= $#; i += 30)); do
    log "purge Cloudflare cache ($((i - 1)))"
    printf "$PUBLIC_URL/%s\n" "${@:i:30}" | jq -Rn '{files: [inputs]}' |
      curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
        -H "Authorization: Bearer $CF_API_TOKEN" -H 'Content-Type: application/json' --data @- |
      jq -e .success >/dev/null || die "Cloudflare purge failed"
  done
}

# Directory listings are cached too: purge every directory whose contents
# change (new and removed packages, the indexes) and all its parents, and the
# same directories under the el9/el10 links for rpm.
declare -A dirs=()
# add_dirs DIR/: DIR and its parents, as URL paths ("." stands for the root,
# since bash can't use an empty key).
add_dirs() {
  local d=$1 el
  while [[ -n $d ]]; do
    dirs[$d]=1
    if [[ $d == rpm/* && $d != rpm/el* ]]; then
      for el in "${EL_LINKS[@]}"; do dirs[rpm/$el/${d#rpm/}]=1; done
    fi
    d=${d%/}
    if [[ $d == */* ]]; then d=${d%/*}/; else d=; fi
  done
  dirs[.]=1
}
dir_urls() { local d; for d in "${!dirs[@]}"; do echo "${d#.}"; done; }

# The cache is purged before anything is deleted, so no cached index still
# lists a file that is gone.
if [[ -n ${CF_ZONE_ID:-} && -n ${CF_API_TOKEN:-} ]]; then
  urls=(README.md rpm/xtom.repo deb/dists/stable/InRelease deb/dists/stable/Release deb/dists/stable/Release.gpg)
  for arch in "${DEB_ARCHS[@]}"; do
    urls+=("deb/dists/stable/main/binary-$arch/Packages"{,.gz,.xz})
  done
  for arch in "${RPM_ARCHS[@]}"; do
    for prefix in "" "${EL_LINKS[@]/%//}"; do
      urls+=("rpm/$prefix$arch/repodata/repomd.xml"{,.asc})
    done
  done

  while read -r f; do add_dirs "$(dirname "$f")/"; done < <(
    cd "$repo" && find deb rpm/*/Packages -type f 2>/dev/null
    cd "$repo" && find deb/dists rpm/*/repodata -type d 2>/dev/null | sed 's|$|/x|'
  )
  mapfile -t -O "${#urls[@]}" urls < <(dir_urls)
  purge "${urls[@]}"
else
  log "CF_ZONE_ID/CF_API_TOKEN not set, skipping cache purge"
fi

# --- delete ----------------------------------------------------------------

dirs=()
declare -A by_dir=()
while read -r f; do
  if [[ -n $f ]]; then by_dir[deb/$(dirname "$f")]+=" $(basename "$f")"; fi
done < <(printf '%s\n' "${drop_debs[@]}" | sort -u)
for d in "${!by_dir[@]}"; do
  # shellcheck disable=SC2086 # space-separated file names
  remote_delete "$d" ${by_dir[$d]}
  add_dirs "$d/"
done
for arch in "${!drop_rpms[@]}"; do
  # shellcheck disable=SC2086
  remote_delete "rpm/$arch/Packages" ${drop_rpms[$arch]}
  add_dirs "rpm/$arch/Packages/"
done
# The listings of those directories changed once more.
if [[ ${#by_dir[@]} -gt 0 || ${#drop_rpms[@]} -gt 0 ]] && [[ -n ${CF_ZONE_ID:-} && -n ${CF_API_TOKEN:-} ]]; then
  mapfile -t urls < <(dir_urls)
  purge "${urls[@]}"
fi

log "published"
