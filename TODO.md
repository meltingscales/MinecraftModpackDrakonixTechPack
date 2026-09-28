- Waylandcraft (https://modrinth.com/mod/waylandcraft) - runs a full Wayland
  compositor inside Minecraft, lets you open real Linux apps as in-game
  windows. Upstream is Fabric-only on MC 26.1.2, so we made our own NeoForge
  1.21.1 port and released it (pre-release, Linux x86_64 only):
  https://github.com/meltingscales/waylandcraft-neoforge-1.21.1/releases/tag/v2.1.0-neoforge-1.21.1
  Jar: https://github.com/meltingscales/waylandcraft-neoforge-1.21.1/releases/download/v2.1.0-neoforge-1.21.1/waylandcraft-2.1.0-neoforge-1.21.1.jar
  Not added to the pack yet. To add: `packwiz url add waylandcraft <jar URL>`
  from `pack/`, and ship `earlyWindowControl = false` in `config/fml.toml`
  (needed for GPU/dmabuf windows). Upstream draft PR:
  https://github.com/EVV1E/waylandcraft/pull/220

- AE2 crafting terminals have no JEI "Move Items" (+) button - known,
  permanently unfixed upstream compat gap between AE2 and JEI, not
  something a mod we're missing would solve:
  https://github.com/mezz/JustEnoughItems/issues/3508
  https://github.com/AppliedEnergistics/Applied-Energistics-2/issues/7857
  (AE2 closed theirs "not planned"). Only known workaround is AE2 UEL
  (Unofficial Extended Life), an unofficial fork that replaces AE2 entirely
  rather than a compat addon - not worth the risk to Extended AE/Replication
  AE2 Bridge just for this button. Shift-click/drag still work fine in the
  terminal. Revisit only if AE2 ever reverses the "not planned" call.
