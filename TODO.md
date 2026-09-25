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
