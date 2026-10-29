# shellcheck shell=bash
# The newest stable Forgejo release; forgejo-lts is the LTS one. See
# _shared/forgejo/common.sh.
# shellcheck source=../_shared/forgejo/common.sh
source "$PKG_DIR/../_shared/forgejo/common.sh"
forgejo_tracks
forgejo_branches "$FORGEJO_STABLE"
