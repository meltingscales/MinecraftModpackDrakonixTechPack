server_dir := "/srv/minecraft/drakonixtechpack"
backup_dir := "/srv/minecraft/backups"
service := "minecraftserver-drakonixtechpack"
unit := "systemd/" + service + ".service"
rcon_port := "25577"
game_port := "25567"
installer_bootstrap_url := "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"
pack_version := `grep '^version' pack/pack.toml | sed -E 's/version = "(.*)"/\1/'`
neoforge_version := `grep '^neoforge' pack/pack.toml | sed -E 's/neoforge = "(.*)"/\1/'`

default:
    @just --list

# create the segregated `minecraft` user + /srv/minecraft
setup-user:
    sudo bash scripts/setup-user.sh

# fetch packwiz-installer-bootstrap.jar (once), used by packwiz-export. Deliberately
# kept outside pack/ - anything in there is fair game for `packwiz modrinth export`
# to sweep into the client .mrpack's overrides/.
fetch-installer:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f packwiz-installer-bootstrap.jar ] && exit 0
    curl -fsSL -o packwiz-installer-bootstrap.jar "{{installer_bootstrap_url}}"

# fetch the NeoForge server installer for the pack's pinned version (once per version -
# filename is version-specific so a pack.toml bump re-fetches automatically)
fetch-neoforge-installer:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "neoforge-{{neoforge_version}}-installer.jar" ] && exit 0
    curl -fsSL -o "neoforge-{{neoforge_version}}-installer.jar" \
        "https://maven.neoforged.net/releases/net/neoforged/neoforge/{{neoforge_version}}/neoforge-{{neoforge_version}}-installer.jar"

# materialize the server side into build/server (real NeoForge server install + mods)
# + zip it (for `just deploy`), and export the client side as a proper .mrpack (for
# Prism/other launchers to import - a plain folder-of-jars zip isn't a "recognized
# modpack type" to any launcher)
packwiz-export: fetch-installer fetch-neoforge-installer
    bash scripts/packwiz-export.sh {{pack_version}} {{neoforge_version}}

# deploy a server bundle (build/server, from packwiz-export) to /srv/minecraft/drakonixtechpack.
# --delete only mirrors the mod/config side of things - world/, logs, and
# other server-generated or operator-edited runtime state are excluded so a
# routine redeploy (to pick up a mod-list change) can't wipe the world or
# clobber RCON settings you added to the live server.properties by hand.
# Writes eula.txt=true - only run this if you (the operator) have accepted
# https://www.minecraft.net/eula. Written after the rsync so `--delete` on a
# future deploy can't wipe it and leave the server unable to start.
deploy src="build/server": packwiz-export
    sudo rsync -a --delete \
        --exclude=/world --exclude=/world_nether --exclude=/world_the_end \
        --exclude=/logs --exclude=/crash-reports \
        --exclude=/server.properties --exclude=/eula.txt \
        --exclude=/whitelist.json --exclude=/ops.json \
        --exclude=/banned-players.json --exclude=/banned-ips.json \
        --exclude=/usercache.json --exclude=/usernamecache.json \
        "{{src}}/" "{{server_dir}}/"
    sudo test -f "{{server_dir}}/server.properties" || sudo cp "{{src}}/server.properties" "{{server_dir}}/server.properties"
    sudo chown -R minecraft:minecraft "{{server_dir}}"
    sudo chmod +x "{{server_dir}}/run.sh"
    printf -- '-Xmx12G\n-Xms12G\n' | sudo tee "{{server_dir}}/user_jvm_args.txt" >/dev/null
    printf 'eula=true\n' | sudo tee "{{server_dir}}/eula.txt" >/dev/null
    sudo chown minecraft:minecraft "{{server_dir}}/user_jvm_args.txt" "{{server_dir}}/eula.txt"
    sudo install -m 644 "{{unit}}" /etc/systemd/system/{{service}}.service
    sudo systemctl daemon-reload

# install/update whitelist.json on the deployed server, then reload it live
install-whitelist:
    sudo install -m 644 whitelist.json "{{server_dir}}/whitelist.json"
    sudo chown minecraft:minecraft "{{server_dir}}/whitelist.json"
    python3 scripts/rcon.py --port {{rcon_port}} whitelist reload

# install + enable the daily world backup timer (midnight, keeps last 10).
# Re-run this any time scripts/backup.sh, the backup service/timer unit, or
# the backup sudoers rule change - it's the one recipe that (re)installs all
# of them, so it's always safe to just re-run after editing any of those.
setup-backups:
    sudo install -m 755 scripts/backup.sh /usr/local/bin/minecraftserverbackup-drakonixtechpack.sh
    sudo install -m 644 scripts/rcon.py /usr/local/bin/rcon.py
    sudo install -m 644 systemd/minecraftserverbackup-drakonixtechpack.service /etc/systemd/system/minecraftserverbackup-drakonixtechpack.service
    sudo install -m 644 systemd/minecraftserverbackup-drakonixtechpack.timer /etc/systemd/system/minecraftserverbackup-drakonixtechpack.timer
    sudo install -m 440 systemd/minecraft-backup-sudoers /etc/sudoers.d/minecraft-backup-drakonixtechpack
    sudo visudo -c
    sudo systemctl daemon-reload
    sudo systemctl enable --now minecraftserverbackup-drakonixtechpack.timer

enable:
    sudo systemctl enable {{service}}

start:
    sudo systemctl start {{service}}

stop:
    sudo systemctl stop {{service}}

restart:
    sudo systemctl restart {{service}}

status:
    systemctl status {{service}}

# interactive RCON console (prompts for rcon.password from server.properties)
rcon:
    python3 scripts/rcon.py --port {{rcon_port}}

# check the game port is actually up and accepting connections (Server List Ping)
ping host="127.0.0.1" port=game_port:
    python3 scripts/mcping.py --host {{host}} --port {{port}}

# DESTRUCTIVE: force a chunk to regenerate (wipes it). Stop the server first, take a backup.
# region_dir defaults to the overworld; pass world/DIM-1/region (nether) or world/DIM1/region (the end) for other dimensions.
delete-chunk chunk_x chunk_z region_dir=(server_dir + "/world/region"):
    sudo python3 scripts/delete-chunk.py --region-dir "{{region_dir}}" {{chunk_x}} {{chunk_z}}

# restore world/ from a backup tar.gz - renames the current world/ aside first (doesn't delete it). Stop the server first.
restore-world backup_file:
    sudo bash -c '[ -d "{{server_dir}}/world" ] && mv "{{server_dir}}/world" "{{server_dir}}/world.pre-restore-$(date +%Y%m%d-%H%M%S)"' || true
    sudo tar -C "{{server_dir}}" -xzf "{{backup_file}}" world
    sudo chown -R minecraft:minecraft "{{server_dir}}/world"

logs:
    journalctl -u {{service}} -f

# list world backups on disk, newest first, with sizes
list-backups:
    ls -lht "{{backup_dir}}"

# bump pack.toml's version, commit, tag it, and push - the push triggers
# .github/workflows/release.yml, which builds the zips and publishes a
# GitHub Release from the tag.
tag version:
    #!/usr/bin/env bash
    set -euo pipefail
    sed -i "s/^version = .*/version = \"{{version}}\"/" pack/pack.toml
    (cd pack && packwiz refresh)
    git add pack/pack.toml pack/index.toml
    git commit -m "Bump pack version to {{version}}"
    git tag -a "v{{version}}" -m "v{{version}}"
    git push origin HEAD "v{{version}}"

# build the zips locally and publish a GitHub Release from the current tag
# (fallback to the CI workflow - needs `gh` authenticated)
release: packwiz-export
    gh release create "$(git describe --tags --abbrev=0)" \
        build/drakonixtechpack-{{pack_version}}-server.zip build/drakonixtechpack-{{pack_version}}-client.mrpack \
        --generate-notes

# serve pack.toml locally for a real Prism Launcher singleplayer test.
# One-time: in Prism, Add Instance -> Import -> http://localhost:8080/pack.toml,
# confirm, then Play (real Mojang account, real singleplayer). Re-run this and
# hit "Update" on that instance later to pull mod-list changes. Ctrl+C when done.
test-client:
    cd pack && packwiz serve

# copy Xaero minimap/worldmap waypoints from an older drakonixtechpack Prism
# instance into a newer one (each version import lands in a differently-named
# instance dir, so waypoints don't carry over automatically). With no args,
# auto-detects the two most recent drakonixtechpack-*-client instances.
copy-waypoints old="" new="":
    bash scripts/copy-waypoints.sh {{old}} {{new}}
