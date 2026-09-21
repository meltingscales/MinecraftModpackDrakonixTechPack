#!/usr/bin/env bash
# Each `just test-client` / Prism import of a new pack version lands in a
# freshly named instance dir (drakonixtechpack-<version>-client), so Xaero's
# per-world waypoints (stored at the instance root, not under config/ - see
# README's Dimensions/config-overrides notes on why that's never bundled in
# the pack) get left behind in the old instance. This copies them forward.
#
# Usage: scripts/copy-waypoints.sh [old-instance-name] [new-instance-name]
# With no args, auto-detects the two most recent drakonixtechpack-*-client
# instances under Prism's instances dir and copies old -> new.
set -euo pipefail

INSTANCES_DIR="${PRISM_INSTANCES_DIR:-$HOME/.local/share/PrismLauncher/instances}"

if [ $# -eq 2 ]; then
    OLD="$1"
    NEW="$2"
else
    mapfile -t MATCHES < <(cd "$INSTANCES_DIR" && ls -d drakonixtechpack-*-client 2>/dev/null | sort -V)
    if [ "${#MATCHES[@]}" -lt 2 ]; then
        echo "Need at least 2 drakonixtechpack-*-client instances under $INSTANCES_DIR to auto-detect old/new; found: ${MATCHES[*]:-none}" >&2
        echo "Pass them explicitly: scripts/copy-waypoints.sh <old-instance> <new-instance>" >&2
        exit 1
    fi
    OLD="${MATCHES[-2]}"
    NEW="${MATCHES[-1]}"
fi

OLD_XAERO="$INSTANCES_DIR/$OLD/minecraft/xaero"
NEW_XAERO="$INSTANCES_DIR/$NEW/minecraft/xaero"

if [ ! -d "$OLD_XAERO" ]; then
    echo "No waypoint data at $OLD_XAERO - nothing to copy." >&2
    exit 1
fi

echo "Copying waypoints: $OLD -> $NEW"
mkdir -p "$NEW_XAERO"
# --ignore-existing: never overwrite anything the new instance already has
# (e.g. if you've already played it a bit before running this).
rsync -a --ignore-existing "$OLD_XAERO/" "$NEW_XAERO/"
echo "Done."
