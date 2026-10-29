# shellcheck shell=bash
# Shared by packages/opencode-cli and packages/opencode-desktop, which are built
# from the same GitHub releases of anomalyco/opencode.
UPSTREAM=anomalyco/opencode
# v1 and v2 are released side by side; we follow v2, which opencode.ai/v2/install
# installs.
BRANCHES=(2)

# The repository also tags other components (process-daemon-v0.3.2, ...).
versions() {
  gh api "repos/$UPSTREAM/releases?per_page=100" \
    --jq '.[] | select(.draft | not) | select(.prerelease | not) | .tag_name
      | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | sub("^v"; "")'
}

# fetch_asset VERSION NAME: download release asset NAME to dl/ and verify it
# against the sha256 GitHub records for it. Upstream's installers check
# nothing, and not every release has a SHA256SUMS file.
fetch_asset() {
  [[ -f dl/$2 ]] && return 0
  download "https://github.com/$UPSTREAM/releases/download/v$1/$2" "dl/$2"
  verify_sha256 "dl/$2" "$(gh_asset_sha256 "$UPSTREAM" "v$1" "$2")"
}
