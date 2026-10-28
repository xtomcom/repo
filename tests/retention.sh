#!/usr/bin/env bash
# Usage: tests/retention.sh
# Checks which builds stale() drops: everything but the newest build of each
# branch in BRANCHES, while packages we don't manage are left alone. Needs dpkg.

source "$(dirname "$0")/../scripts/lib.sh"

# nodejs-20 stands for a package removed from packages/ after its last release.
got=$(RETIRED="nodejs-20" stale deb <<'EOF2'
golang 2:1.27.3-1 a/golang_1.27.3-1_amd64.deb
golang 2:1.27.4-1 a/golang_1.27.4-1_amd64.deb
golang 2:1.26.10-1 a/golang_1.26.10-1_amd64.deb
golang 2:1.25.9-1 a/golang_1.25.9-1_amd64.deb
rdap 1.0.9 a/rdap_1.0.9_amd64.deb
rdap 1:1.0.9-1 a/rdap_1.0.9-1_amd64.deb
gitea 28.2.0-2 a/gitea_28.2.0-2_amd64.deb
gitea 28.2.0-1 a/gitea_28.2.0-1_amd64.deb
unrelated 9.9 a/unrelated_9.9_amd64.deb
nodejs-20 20.20.2-1 a/nodejs-20_20.20.2-1_amd64.deb
EOF2
)
want='a/golang_1.27.3-1_amd64.deb
a/golang_1.25.9-1_amd64.deb
a/rdap_1.0.9_amd64.deb
a/gitea_28.2.0-1_amd64.deb
a/nodejs-20_20.20.2-1_amd64.deb'
[[ $got == "$want" ]] || die "deb: got:"$'\n'"$got"

got=$(stale rpm <<'EOF2'
golang 1.27.3-1.xtom golang-1.27.3-1.xtom.x86_64.rpm
golang 1.27.4-1.xtom golang-1.27.4-1.xtom.x86_64.rpm
golang 1.26.10-1.xtom golang-1.26.10-1.xtom.x86_64.rpm
see 1.4.0-1.xtom see-1.4.0-1.xtom.x86_64.rpm
see 1.3.9-1.xtom see-1.3.9-1.xtom.x86_64.rpm
EOF2
)
want='golang-1.27.3-1.xtom.x86_64.rpm
see-1.3.9-1.xtom.x86_64.rpm'
[[ $got == "$want" ]] || die "rpm: got:"$'\n'"$got"

log "retention test passed"
