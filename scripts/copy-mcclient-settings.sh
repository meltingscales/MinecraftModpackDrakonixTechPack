#!/usr/bin/env bash
# Each `just test-client` / Prism import of a new pack version lands in a
# freshly named instance dir (drakonixtechpack-<version>-client), so your
# personal client settings - Xaero waypoints, options.txt (keybinds, video,
# resource pack selection), shader options, mod configs, server list - get
# left behind in the old instance and Prism starts you fresh each time.
#
# This carries them forward: OLD's settings win over NEW's (freshly-imported
# pack defaults), so run it right after importing a new version, before you've
# customized anything in it. It never touches mods/, world saves, logs/, or
# resourcepacks/shaderpacks/ - those come from the pack itself.
#
# Usage: scripts/copy-mcclient-settings.sh [old-instance-name] [new-instance-name]
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
        echo "Pass them explicitly: scripts/copy-mcclient-settings.sh <old-instance> <new-instance>" >&2
        exit 1
    fi
    OLD="${MATCHES[-2]}"
    NEW="${MATCHES[-1]}"
fi

OLD_MC="$INSTANCES_DIR/$OLD/minecraft"
NEW_MC="$INSTANCES_DIR/$NEW/minecraft"

if [ ! -d "$OLD_MC" ]; then
    echo "No instance at $OLD_MC - nothing to copy." >&2
    exit 1
fi

echo "Copying client settings: $OLD -> $NEW"
mkdir -p "$NEW_MC"

# Per-world/per-server waypoints and minimap state.
[ -d "$OLD_MC/xaero" ] && rsync -a "$OLD_MC/xaero/" "$NEW_MC/xaero/"

# Keybinds, video settings, resource pack selection, and anything else
# options.txt tracks.
[ -f "$OLD_MC/options.txt" ] && cp "$OLD_MC/options.txt" "$NEW_MC/options.txt"

# Iris per-shaderpack option overrides (only exists once you've tweaked a
# shader's settings away from its defaults).
[ -f "$OLD_MC/optionsshaders.txt" ] && cp "$OLD_MC/optionsshaders.txt" "$NEW_MC/optionsshaders.txt"

# Multiplayer server list, so your playit.gg entry etc. don't need re-adding.
[ -f "$OLD_MC/servers.dat" ] && cp "$OLD_MC/servers.dat" "$NEW_MC/servers.dat"

# All per-mod configs. Note: if a mod's config format changed between the
# versions pinned in the two instances, that mod may need to regenerate its
# config on next launch - most mods handle this gracefully, but it's worth
# knowing if something looks reset after running this.
[ -d "$OLD_MC/config" ] && rsync -a "$OLD_MC/config/" "$NEW_MC/config/"

echo "Done."
