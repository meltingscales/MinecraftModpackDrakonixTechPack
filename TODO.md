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

- ~~AE2 crafting terminals have no JEI "Move Items" (+) button~~ FIXED via
  **AE2 Utility** (added). It adds its own `+` "fill from ME network"
  button to ME/crafting/wireless-crafting terminals, independent of JEI's
  own broken hook - the underlying JEI<->AE2 gap is still unfixed upstream
  and closed "not planned" (https://github.com/mezz/JustEnoughItems/issues/3508,
  https://github.com/AppliedEnergistics/Applied-Energistics-2/issues/7857),
  but AE2 Utility routes around it rather than depending on a fix. Also
  adds JEI/EMI pattern encoding, a recipe finder, and a couple of AE2
  automation cards (NBT Tear, Redstone Signal). Tom's Simple Storage needed
  no equivalent fix - it has native JEI/EMI/REI recipe-transfer support
  built in already.
