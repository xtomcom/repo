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

# A release goes out only when every architecture built and passed its tests;
# otherwise its files are dropped and the next run retries it.
shopt -s nullglob
for m in "$DIST"/manifest/*@*@*; do
  m=$(basename "$m")
  name=${m%%@*} rest=${m#*@}
  version=${rest%@*}
  load_package "$name"
  for a in "${ARCHS[@]}"; do
    [[ -e $DIST/manifest/$name@$version@$a ]] && continue
    log "skip $name $version: not every architecture passed"
    rm -f "$DIST/manifest/$m" "$DIST/${name}_${version}-${RELEASE}_"*.deb "$DIST/${name}-${version}-${RELEASE}".xtom.*.rpm
    break
  done
done
debs=("$DIST"/*.deb)
rpms=("$DIST"/*.rpm)
shopt -u nullglob
[[ ${#debs[@]} -gt 0 || ${#rpms[@]} -gt 0 ]] || die "nothing to publish in $DIST"

repo=$WORK/repo
rm -rf "$repo" "$WORK/rpm-build" "$WORK/empty"
mkdir -p "$repo" "$WORK/empty"

gpg_args=(--batch --yes --local-user "$GPG_KEY_ID")
[[ -z ${GPG_PASSPHRASE:-} ]] || gpg_args+=(--pinentry-mode loopback --passphrase "$GPG_PASSPHRASE")

log "pull metadata from $REPO_DEST"
rsync -a --checksum --prune-empty-dirs \
  --include='*/' --include='/deb/dists/***' --include='/rpm/*/repodata/***' --exclude='*' \
  "$REPO_DEST/" "$repo/"
rsync -r --list-only --include='/rpm/' --include='/rpm/*/' --include='/rpm/*/Packages/' \
  --include='/rpm/*/Packages/*.rpm' --exclude='*' "$REPO_DEST/" |
  awk '$NF ~ /\.rpm$/ { print $NF }' > "$WORK/remote-rpms"

# Pool files are cached by the CDN and by clients forever, so a file name must
# never get new content. Rebuilds need a new RELEASE.
for f in "${debs[@]}" "${rpms[@]}"; do
  ! grep -qsF "/$(basename "$f")" "$WORK/remote-rpms" "$repo"/deb/dists/stable/main/binary-*/Packages ||
    die "$(basename "$f") is already published; bump RELEASE in its package.sh to rebuild it"
done

# Packages in versions.json whose directory is gone from packages/ have been
# retired (e.g. an upstream branch reached end of life): drop all their builds.
RETIRED=$(jq -r 'keys[]' "$VERSIONS_FILE" 2>/dev/null | while read -r name; do
  [[ -f $ROOT/packages/$name/package.sh ]] || echo "$name"
done | xargs)
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

rm -f "$dists/Release" "$dists/Release.gpg" "$dists/InRelease"
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
gpg "${gpg_args[@]}" --armor --detach-sign --output "$dists/Release.gpg" "$dists/Release"
gpg "${gpg_args[@]}" --clearsign --output "$dists/InRelease" "$dists/Release"

# --- rpm -------------------------------------------------------------------

if [[ ${#rpms[@]} -gt 0 ]]; then
  sign=(rpmsign --addsign --define "_gpg_name $GPG_KEY_ID")
  [[ -z ${GPG_PASSPHRASE:-} ]] ||
    sign+=(--define "_gpg_sign_cmd_extra_args --pinentry-mode loopback --passphrase $GPG_PASSPHRASE")
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
  mkdir -p "$dir/Packages" "$build/Packages"
  [[ -d $dir/repodata ]] && cp -r "$dir/repodata" "$build/"

  # NAME-VERSION-RELEASE.ARCH.rpm; names may contain dashes, versions don't.
  mapfile -t drop < <({
    sed -n "s|^rpm/$arch/Packages/||p" "$WORK/remote-rpms"
    ls "$dir/Packages"
  } | awk '{ b = $0; sub(/\.[^.]+\.rpm$/, "", b); n = split(b, p, "-")
      name = p[1]; for (i = 2; i < n - 1; i++) name = name "-" p[i]
      print name, p[n - 1] "-" p[n], $0 }' | stale rpm)
  printf '%s\n' "${drop[@]}" > "$WORK/drop"

  while read -r f; do
    grep -qxF "$f" "$WORK/drop" || touch "$build/Packages/$f"
  done < <(sed -n "s|^rpm/$arch/Packages/||p" "$WORK/remote-rpms")
  for f in "$dir"/Packages/*.rpm; do
    [[ -e $f ]] || continue
    if grep -qxF "$(basename "$f")" "$WORK/drop"; then rm "$f"; else cp "$f" "$build/Packages/"; fi
  done

  if [[ -f $build/repodata/repomd.xml ]]; then
    createrepo_c --quiet --update --skip-stat "$build"
  else
    createrepo_c --quiet "$build"
  fi
  rm -rf "$dir/repodata"
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

declare -A by_dir=()
for f in "${drop_debs[@]}"; do by_dir[deb/$(dirname "$f")]+=" $(basename "$f")"; done
for d in "${!by_dir[@]}"; do
  # shellcheck disable=SC2086 # space-separated file names
  remote_delete "$d" ${by_dir[$d]}
done
for arch in "${!drop_rpms[@]}"; do
  # shellcheck disable=SC2086
  remote_delete "rpm/$arch/Packages" ${drop_rpms[$arch]}
done

# --- cache -----------------------------------------------------------------

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
  # The API takes at most 30 URLs per call.
  for ((i = 0; i < ${#urls[@]}; i += 30)); do
    log "purge Cloudflare cache ($i)"
    printf "$PUBLIC_URL/%s\n" "${urls[@]:i:30}" | jq -Rn '{files: [inputs]}' |
      curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
        -H "Authorization: Bearer $CF_API_TOKEN" -H 'Content-Type: application/json' --data @- |
      jq -e .success >/dev/null || die "Cloudflare purge failed"
  done
else
  log "CF_ZONE_ID/CF_API_TOKEN not set, skipping cache purge"
fi

log "published"
