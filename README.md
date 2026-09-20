# Drakonix Tech Pack

[**Releases**](https://github.com/meltingscales/MinecraftModpackDrakonixTechPack/releases) — grab the latest server zip / client `.mrpack` here.

Modded Minecraft server: **NeoForge 1.21.1**. Hosting setup is a clone of the sibling
`MinecraftServerLiminalIndustries` repo (same justfile/systemd/scripts pattern), with
the mod bundle sourced from a tracked [Packwiz](https://packwiz.infra.link/) pack
instead of a hand-dropped CurseForge zip.

## Server URL

- drakonixtechpack.playit.plus:23387

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
just packwiz-export                 # installs the real NeoForge server + mods into build/server, zips it, exports build/*.mrpack
just setup-user                     # creates the minecraft system user + /srv/minecraft
just deploy                         # rsyncs build/server -> /srv/minecraft/drakonixtechpack, writes eula.txt=true, installs the unit
just enable                         # systemctl enable minecraftserver-drakonixtechpack
just start                          # systemctl start minecraftserver-drakonixtechpack
just status                         # confirm it's running
just setup-backups                  # install + enable the daily backup timer (keeps last 10)
```

`just deploy` writes `eula.txt=true` on your behalf — only run it once you've accepted
[Mojang's EULA](https://www.minecraft.net/eula) yourself, since that's the operator's
agreement to make, not something to accept silently.

`pack/server.properties` (tracked in the pack, so it ships pre-set — no manual edit
needed) pins the port:

```
server-port=25567
query.port=25567
```

(offset from the defaults so this can coexist with other Minecraft servers already
running on this host — `buiz` uses 25565/25575, `liminalindustries` uses
25566/25576).

RCON isn't pre-configured (no secret gets committed to the repo). After the first
`just deploy` + `just start`, edit the live `/srv/minecraft/drakonixtechpack/
server.properties` and add:

```
enable-rcon=true
rcon.port=25577
rcon.password=<a-generated-secret>
```

then `just restart` to pick it up — RCON settings are only read at startup. `just rcon`
connects with `scripts/rcon.py`, prompting for the password interactively.

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
| ProjectE | ports, but PE1.1.0 has an unfixed upstream crash on 1.21.1 - `IEMCProxy` fails to init on the first item tooltip render, then every tooltip after crashes the client (permanent, since Java caches the failed static init); see [ProjectE#2460](https://github.com/sinkillerj/ProjectE/issues/2460), no response/fix as of writing | **Replication** (+ **Replication AE2 Bridge**, since AE2 is already in the pack) - the other EMC-alike from the original wishlist, unaffected by ProjectE's bug |

Everything else in the original wishlist ported natively: Applied Energistics 2,
Mekanism, Create (+ Create Big Cannons), The Aether, The Twilight Forest,
Waystones, Corail Tombstone (gravestone mod), JEI, Iris (native NeoForge shaders, no
Oculus needed). Several dimension mods were added to answer the "not sure what
other cool dimensions mods" TODO — see [Dimensions](#dimensions) below for the full
list and how to reach each one. (**Aquamirae** and **Deeper and Darker** were also
added around the same time but don't add new dimensions — they add overworld
structures/biomes instead.) All of these are easy to drop via `packwiz remove <slug>`
in `pack/` if they don't fit actual play.

## Mods

Full, current mod list lives in `pack/` (packwiz pack — `pack/pack.toml` +
`pack/mods/*.pw.toml`), not hardcoded here. To see it:

```
cd pack && packwiz list
```

To add/remove a mod: `packwiz modrinth add <slug>` / `packwiz curseforge add <slug>` /
`packwiz remove <slug>` from inside `pack/`, then `just packwiz-export` regenerates
the zips.

## Dimensions

8 mods add real new dimensions (not counting Aquamirae or Deeper and Darker, which
add overworld structures/biomes rather than a new dimension):

| Dimension | How to get there | Docs |
|---|---|---|
| **The Aether** | Build a rectangular glowstone frame (min 4×5), then fill the inside with water (bucket, or melt ice in it). | [Aether Wiki](https://aether.wiki.gg/wiki/The_Aether/The_Aether) |
| **The Twilight Forest** | Dig a 2×2 (up to 8×8) pool, fill with water source blocks, ring it with ≥12 flowers/mushrooms/saplings, then throw a diamond into the water. | [Twilight Forest Wiki](https://twilightforest.fandom.com/wiki/Twilight_Forest_Portal) |
| **Ad Astra** (space: Moon, Mars, etc.) | Craft a Tier 1 Rocket at a NASA Workbench, fuel it (3 buckets), put it on a Launch Pad, suit up in a full Space Suit + oxygen tanks, then launch. Carry a spare Launch Pad — the one under the rocket can't be reclaimed after landing. | [Ad Astra Wiki](https://ad-astra-mod.fandom.com/wiki/Ad_Astra_Mod_Wiki) |
| **The Undergarden** | Craft a Catalyst (gold + iron ingots + a diamond). Build a Nether-portal-shaped frame (4×5 to 23×23) out of Stone/Deepslate/Depthrock/Shiverstone Bricks, in the **Overworld** (frames built elsewhere don't work). Right-click the inner bottom face with the Catalyst. | [Undergarden Wiki](https://the-undergarden-mod.fandom.com/wiki/Undergarden_portal) |
| **Dimensional Doors** (pocket dimensions) | Craft a Dimensional Door (Iron = new empty pocket, Gold = dungeon, Quartz = your personal pocket, Unstable = random) and place/open it, or right-click a naturally-spawned Rift with a Rift Blade. Careful: dying or void-falling in a pocket can drop you into Limbo. | [Dimensional Doors Wiki](https://dimensional-doors-mod.fandom.com/wiki/Rift) |
| **Tropicraft** | Craft a Beach Chair (bamboo + wool) and a Piña Colada, place the chair on a beach, sit, and drink before sunrise. A Tropics Portal back in the Overworld (built once you've been there) is the permanent way in afterward. | [Tropicraft Wiki](https://tropicraft.fandom.com/wiki/Tropics_Portal_Enchanter) |
| **Arda's Sculks** (Ancient World) | Find a vanilla Ancient City, get an Ancient World Portal Igniter, and use it on the Ancient Portal there. | [CurseForge page](https://www.curseforge.com/minecraft/mc-mods/ardas-sculks) |
| **Create: Dimension, Steamworks Realm** | Build a portal frame out of Andesite blocks, then activate it with a Steamworks Realm Portal Igniter. | [GitHub README](https://github.com/Reggarfgod/Create-Dimension) |

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
and attaches `drakonixtechpack-<version>-server.zip`/`drakonixtechpack-<version>-client.mrpack`
to a GitHub
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
- `pack/options.txt`, `pack/config/` — client default-config overrides (packwiz treats
  any non-metadata file placed in `pack/` as a plain file to install at that path, no
  `packwiz` subcommand needed - just drop it in and `packwiz refresh`). Currently:
  `options.txt` (just the `resourcePacks`/`incompatibleResourcePacks` lines - not a
  full options.txt, so it doesn't clobber anyone's keybinds/video settings on
  update) to pre-select Whimscape, `config/iris.properties` to pre-select
  Complementary Shaders, and `config/xaero/` + `config/xaerohud.txt` for Xaero's
  minimap/world map default layout (global mod settings only - per-world waypoint
  data lives outside `config/` and is never bundled)
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
