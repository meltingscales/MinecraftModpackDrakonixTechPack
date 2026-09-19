server_dir := "/srv/minecraft/drakonixtechpack"
backup_dir := "/srv/minecraft/backups"
service := "minecraftserver-drakonixtechpack"
unit := "systemd/" + service + ".service"
rcon_port := "25577"
game_port := "25567"
installer_bootstrap_url := "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"

default:
    @just --list

# create the segregated `minecraft` user + /srv/minecraft
setup-user:
    sudo bash scripts/setup-user.sh

# fetch packwiz-installer-bootstrap.jar (once) into pack/, used by packwiz-export
fetch-installer:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f pack/packwiz-installer-bootstrap.jar ] && exit 0
    curl -fsSL -o pack/packwiz-installer-bootstrap.jar "{{installer_bootstrap_url}}"

# materialize the packwiz pack into build/server and build/client, then zip both
packwiz-export: fetch-installer
    #!/usr/bin/env bash
    set -euo pipefail
    cd pack
    packwiz serve &
    SERVE_PID=$!
    trap 'kill "$SERVE_PID" 2>/dev/null || true' EXIT
    sleep 1
    rm -rf ../build
    mkdir -p ../build/server ../build/client
    (cd ../build/server && java -jar ../../pack/packwiz-installer-bootstrap.jar -g -s server http://localhost:8080/pack.toml)
    (cd ../build/client && java -jar ../../pack/packwiz-installer-bootstrap.jar -g -s client http://localhost:8080/pack.toml)
    cd ../build
    rm -f drakonixtechpack-server.zip drakonixtechpack-client.zip
    (cd server && zip -qr ../drakonixtechpack-server.zip .)
    (cd client && zip -qr ../drakonixtechpack-client.zip .)

# deploy a server bundle (build/server, from packwiz-export) to /srv/minecraft/drakonixtechpack
deploy src="build/server": packwiz-export
    sudo rsync -a --delete "{{src}}/" "{{server_dir}}/"
    sudo chown -R minecraft:minecraft "{{server_dir}}"
    sudo chmod +x "{{server_dir}}/run.sh"
    printf -- '-Xmx6G\n-Xms6G\n' | sudo tee "{{server_dir}}/user_jvm_args.txt" >/dev/null
    sudo chown minecraft:minecraft "{{server_dir}}/user_jvm_args.txt"
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
        build/drakonixtechpack-server.zip build/drakonixtechpack-client.zip \
        --generate-notes

# serve pack.toml locally for a real Prism Launcher singleplayer test.
# One-time: in Prism, Add Instance -> Import -> http://localhost:8080/pack.toml,
# confirm, then Play (real Mojang account, real singleplayer). Re-run this and
# hit "Update" on that instance later to pull mod-list changes. Ctrl+C when done.
test-client:
    cd pack && packwiz serve
