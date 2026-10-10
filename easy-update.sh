#!/usr/bin/env bash
# One-command operator update: deploy the current pack to the live server,
# restart it, then carry Prism client settings forward. See README.md's
# "One-command update" section for the full caveat (import the new client
# .mrpack into Prism *before* running this, or the last step is a no-op).
set -euo pipefail

echo "WARNING: this deploys the current pack to the live server, restarts it"
echo "(disconnecting any connected players), and carries your Prism client"
echo "settings forward from the previous instance."
read -rp "Continue? [y/N] " reply
case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
esac

just deploy
just restart
just copy-mcclient-settings
