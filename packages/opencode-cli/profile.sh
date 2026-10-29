# shellcheck shell=sh
# Installed by the opencode-cli package. opencode is updated by apt/dnf, so
# skip its own update check unless you have set OPENCODE_DISABLE_AUTOUPDATE
# yourself. To get the check back, set OPENCODE_DISABLE_AUTOUPDATE=0 in your
# shell startup file, or delete this file (package upgrades keep it deleted).
export OPENCODE_DISABLE_AUTOUPDATE="${OPENCODE_DISABLE_AUTOUPDATE:-1}"
