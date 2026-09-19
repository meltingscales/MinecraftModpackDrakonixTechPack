# Drakonix Tech Pack

Modded Minecraft server: **NeoForge 1.21.1**. Hosting setup is a clone of the sibling
`MinecraftServerLiminalIndustries` repo (same justfile/systemd/scripts pattern), with
the mod bundle sourced from a tracked [Packwiz](https://packwiz.infra.link/) pack
instead of a hand-dropped CurseForge zip.

## What is this

A tech-focused modpack + self-hosted server setup, in one repo:

- `pack/` is the actual modpack (a packwiz pack — mod list, versions, hashes), the
  source of truth for what's installed
- everything else (`justfile`, `systemd/`, `scripts/`) is the infra to build that pack
  into deployable zips and run it as a systemd-managed server with backups, RCON, and
  a whitelist
- pushing a `vX.Y.Z` tag (via `just tag <version>`) builds the pack and publishes
  server/client zips as a GitHub Release, so players and the server host always pull
  from the same tagged, reproducible mod list

## Quickstart

```
just packwiz-export                 # builds build/{server,client} + zips from pack/
just setup-user                     # creates the minecraft system user + /srv/minecraft
just deploy                         # rsyncs build/server -> /srv/minecraft/drakonixtechpack, installs the unit
just enable                         # systemctl enable minecraftserver-drakonixtechpack
just start                          # systemctl start minecraftserver-drakonixtechpack
just status                         # confirm it's running
just setup-backups                  # install + enable the daily backup timer (keeps last 10)
```

Before the first `just deploy`, edit `build/server/server.properties` (regenerated
each `packwiz-export`, so re-check after re-exporting) and set:

```
server-port=25567
query.port=25567
```

(offset from the defaults so this can coexist with other Minecraft servers already
running on this host — `buiz` uses 25565/25575, `liminalindustries` uses
25566/25576).

## Version / mod list decisions

The original TODO was "not sure what version of Minecraft/NeoForge to use" — resolved
to **1.21.1 / NeoForge**. The one mod that actually forked this choice was **Modular
Powersuits** (dead upstream since 1.20.1, no 1.21 port); going with 1.21.1 means using
a substitute instead of the real thing. Two other originally-wanted mods also lack
1.21.1 ports and were swapped:

| Wanted | Status on 1.21.1 | What's in the pack instead |
|---|---|---|
| Modular Powersuits | dead upstream, capped at 1.20.1 | **Power Armor: Renostalgized** (modular armor via an Armor Modification Table — closest available analog) |
| Thermal Expansion / Thermal Series | CoFH mods capped at 1.20.1 | **Immersive Engineering** (retro-futuristic industrial tech, actively maintained) |
| Backpacked | capped at 1.20.6, no 1.21.1 build | **Sophisticated Backpacks** |

Everything else in the original wishlist ported natively: Applied Energistics 2,
Mekanism, Create (+ Create Big Cannons), The Aether, The Twilight Forest, ProjectE,
Waystones, Corail Tombstone (gravestone mod), JEI, Iris (native NeoForge shaders, no
Oculus needed). **Ad Astra** (space/planets dimension) was added to answer the
"not sure what other cool dimensions mods" TODO, alongside **Aquamirae** (ocean
ship-graveyard dimension) — both are easy to drop via `packwiz remove <slug>` in
`pack/` if they don't fit actual play.

## Mods

Full, current mod list lives in `pack/` (packwiz pack — `pack/pack.toml` +
`pack/mods/*.pw.toml`), not hardcoded here. To see it:

```
cd pack && packwiz list
```

To add/remove a mod: `packwiz modrinth add <slug>` / `packwiz curseforge add <slug>` /
`packwiz remove <slug>` from inside `pack/`, then `just packwiz-export` regenerates
the zips.

## Testing in singleplayer

```
just test-client
```

Serves `pack/pack.toml` on `http://localhost:8080` (via `packwiz serve`). One-time
setup in [Prism Launcher](https://prismlauncher.org/): Add Instance → Import →
paste `http://localhost:8080/pack.toml` → confirm. From then on, Play launches a
real singleplayer session under your own Mojang account; re-run `just test-client`
and hit "Update" on the instance to pick up mod-list changes. `Ctrl+C` stops the
server once Prism's done downloading.

## Releasing

```
just tag 0.2.0    # bumps pack.toml, commits, tags v0.2.0, pushes - CI takes it from there
```

`.github/workflows/release.yml` picks up the tag push, runs `just packwiz-export`,
and attaches `drakonixtechpack-server.zip`/`drakonixtechpack-client.zip` to a GitHub
Release. `just release` does the same build+publish locally (needs `gh` authenticated)
as a fallback if CI is down.

## layout

- `justfile` — `packwiz-export`, `tag`, `release`, `test-client`, `setup-user`,
  `deploy`, `enable/start/stop/restart/status/logs/rcon/ping/list-backups/
  restore-world/delete-chunk`
- `.github/workflows/release.yml` — builds + publishes the release zips on `vX.Y.Z`
  tag push
- `pack/` — the packwiz pack: `pack.toml`, `index.toml`, `mods/*.pw.toml` (source of
  truth for the mod list — no separate sha256 manifest, packwiz hashes its own files)
- `systemd/minecraftserver-drakonixtechpack.service` — unit installed to
  `/etc/systemd/system/`, runs as the `minecraft` user, pins Java 21 (NeoForge 1.21.1
  requirement)
- `systemd/minecraftserverbackup-drakonixtechpack.{service,timer}` — daily cold-backup
  timer, keeps the last **10** backups
- `systemd/minecraft-backup-sudoers` — installed to
  `/etc/sudoers.d/minecraft-backup-drakonixtechpack`
- `scripts/setup-user.sh` — creates the `minecraft` system user + `/srv/minecraft`
  (idempotent, shared across any other Minecraft server repos set up the same way on
  this host)
- `scripts/backup.sh` — cold-backup: warns players over RCON, stops the service, tars
  `world`+`config`+small state files, restarts, prunes to the last 10
- `scripts/rcon.py` — interactive RCON console client, used by `just rcon`
- `scripts/mcping.py` — Server List Ping check, used by `just ping`
- `scripts/delete-chunk.py` — DESTRUCTIVE chunk-regeneration tool, used by `just
  delete-chunk`

`build/` (packwiz-export output) and the resulting zips are not committed to git —
run `just packwiz-export` to regenerate.
