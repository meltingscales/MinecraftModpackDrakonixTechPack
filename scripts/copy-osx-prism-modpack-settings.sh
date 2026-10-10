#!/usr/bin/env bash
# macOS port of copy-mcclient-settings.sh (see that file for the full
# rationale - keep both in sync). Only two differences: Prism's instances
# dir lives under ~/Library/Application Support on macOS, and this avoids
# `mapfile`, which isn't available in the bash 3.2 macOS ships by default.
#
# Each `just test-client` / Prism import of a new pack version lands in a
# freshly named instance dir (drakonixtechpack-<version>-client), so your
# personal client settings - Xaero waypoints, options.txt (keybinds, video,
# resource pack selection), shader options, mod configs, server list,
# screenshots, saved hotbars, and any manually-added resourcepacks/
# shaderpacks - get left behind in the old instance and Prism starts you
# fresh each time.
#
# This carries them forward: OLD's settings win over NEW's (freshly-imported
# pack defaults) for config/options-type files, so run it right after
# importing a new version, before you've customized anything in it.
# resourcepacks/ and shaderpacks/ are merged the other way (never overwrite
# what's already in NEW) since the pack ships its own copies there
# (Whimscape, Complementary Shaders) that should stay whatever version the
# new pack pinned - only files you added yourself get carried over.
#
# It never touches mods/ or world saves (saves/) - those are pack content
# and per-world data respectively, not client settings, and mod-list changes
# between versions can make an old save incompatible in ways this script
# has no business papering over.
#
# Usage: scripts/copy-osx-prism-modpack-settings.sh [old-instance-name] [new-instance-name]
# With no args, auto-detects the two most recent drakonixtechpack-*-client
# instances under Prism's instances dir and copies old -> new.
set -euo pipefail

INSTANCES_DIR="${PRISM_INSTANCES_DIR:-$HOME/Library/Application Support/PrismLauncher/instances}"

if [ $# -eq 2 ]; then
    OLD="$1"
    NEW="$2"
else
    MATCHES=()
    while IFS= read -r line; do
        [ -n "$line" ] && MATCHES+=("$line")
    done < <(cd "$INSTANCES_DIR" && ls -d drakonixtechpack-*-client 2>/dev/null | sort -V)
    if [ "${#MATCHES[@]}" -lt 2 ]; then
        echo "Need at least 2 drakonixtechpack-*-client instances under $INSTANCES_DIR to auto-detect old/new; found: ${MATCHES[*]:-none}" >&2
        echo "Pass them explicitly: scripts/copy-osx-prism-modpack-settings.sh <old-instance> <new-instance>" >&2
        exit 1
    fi
    OLD="${MATCHES[${#MATCHES[@]}-2]}"
    NEW="${MATCHES[${#MATCHES[@]}-1]}"
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

# Saved hotbar loadouts (creative-mode hotbar presets).
[ -f "$OLD_MC/hotbar.nbt" ] && cp "$OLD_MC/hotbar.nbt" "$NEW_MC/hotbar.nbt"

# All per-mod configs. Note: if a mod's config format changed between the
# versions pinned in the two instances, that mod may need to regenerate its
# config on next launch - most mods handle this gracefully, but it's worth
# knowing if something looks reset after running this.
[ -d "$OLD_MC/config" ] && rsync -a "$OLD_MC/config/" "$NEW_MC/config/"

# Screenshots - no conflict risk (filenames are timestamped), straight merge.
[ -d "$OLD_MC/screenshots" ] && rsync -a "$OLD_MC/screenshots/" "$NEW_MC/screenshots/"

# Any resourcepacks/shaderpacks you added yourself beyond what the pack
# ships. --ignore-existing so this never clobbers the pack's own current
# Whimscape/Complementary Shaders files with an older carried-over copy.
mkdir -p "$NEW_MC/resourcepacks" "$NEW_MC/shaderpacks"
[ -d "$OLD_MC/resourcepacks" ] && rsync -a --ignore-existing "$OLD_MC/resourcepacks/" "$NEW_MC/resourcepacks/"
[ -d "$OLD_MC/shaderpacks" ] && rsync -a --ignore-existing "$OLD_MC/shaderpacks/" "$NEW_MC/shaderpacks/"

echo "Done."
