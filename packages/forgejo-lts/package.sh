# shellcheck shell=bash
# The Forgejo long-term support release; forgejo is the newest stable one. See
# _shared/forgejo/common.sh.
# shellcheck source=../_shared/forgejo/common.sh
source "$PKG_DIR/../_shared/forgejo/common.sh"
forgejo_tracks
forgejo_branches "$FORGEJO_LTS"
# Newer majors are forgejo's; the next LTS is taken up once this one ends.
versions() { forgejo_versions | awk -F. -v major="${BRANCHES[0]}" '$1 <= major'; }
