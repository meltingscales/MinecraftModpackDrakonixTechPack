# Windows port of copy-mcclient-settings.sh - see that file for the full
# rationale (per-recipe comments kept in sync here; update both together).
#
# Usage: scripts/copy-mcclient-settings.ps1 [-Old <instance>] [-New <instance>]
# With no args, auto-detects the two most recent drakonixtechpack-*-client
# instances under Prism's instances dir and copies Old -> New.
param(
    [string]$Old,
    [string]$New
)

$ErrorActionPreference = "Stop"

$InstancesDir = if ($env:PRISM_INSTANCES_DIR) { $env:PRISM_INSTANCES_DIR } else { Join-Path $env:APPDATA "PrismLauncher\instances" }

if (-not $Old -or -not $New) {
    $matches = Get-ChildItem -Path $InstancesDir -Directory -Filter "drakonixtechpack-*-client" -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^drakonixtechpack-(.+)-client$', '$1') }
    if ($matches.Count -lt 2) {
        Write-Error "Need at least 2 drakonixtechpack-*-client instances under $InstancesDir to auto-detect old/new; found: $($matches.Name -join ', ')`nPass them explicitly: scripts/copy-mcclient-settings.ps1 -Old <old-instance> -New <new-instance>"
        exit 1
    }
    $Old = $matches[-2].Name
    $New = $matches[-1].Name
}

$OldMc = Join-Path $InstancesDir "$Old\minecraft"
$NewMc = Join-Path $InstancesDir "$New\minecraft"

if (-not (Test-Path $OldMc)) {
    Write-Error "No instance at $OldMc - nothing to copy."
    exit 1
}

Write-Host "Copying client settings: $Old -> $New"
New-Item -ItemType Directory -Force -Path $NewMc | Out-Null

function Copy-FileIfExists($relPath) {
    $src = Join-Path $OldMc $relPath
    if (Test-Path $src -PathType Leaf) {
        Copy-Item -Path $src -Destination (Join-Path $NewMc $relPath) -Force
    }
}

function Merge-DirOverwrite($relPath) {
    $src = Join-Path $OldMc $relPath
    if (Test-Path $src -PathType Container) {
        $dst = Join-Path $NewMc $relPath
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        robocopy $src $dst /E /NFL /NDL /NJH /NJS | Out-Null
    }
}

function Merge-DirNoOverwrite($relPath) {
    $src = Join-Path $OldMc $relPath
    if (Test-Path $src -PathType Container) {
        $dst = Join-Path $NewMc $relPath
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        robocopy $src $dst /E /XC /XN /XO /NFL /NDL /NJH /NJS | Out-Null
    }
}

# Per-world/per-server waypoints and minimap state.
Merge-DirOverwrite "xaero"

# Keybinds, video settings, resource pack selection, and anything else
# options.txt tracks.
Copy-FileIfExists "options.txt"

# Iris per-shaderpack option overrides (only exists once you've tweaked a
# shader's settings away from its defaults).
Copy-FileIfExists "optionsshaders.txt"

# Multiplayer server list, so your playit.gg entry etc. don't need re-adding.
Copy-FileIfExists "servers.dat"

# Saved hotbar loadouts (creative-mode hotbar presets).
Copy-FileIfExists "hotbar.nbt"

# All per-mod configs. Note: if a mod's config format changed between the
# versions pinned in the two instances, that mod may need to regenerate its
# config on next launch - most mods handle this gracefully, but it's worth
# knowing if something looks reset after running this.
Merge-DirOverwrite "config"

# Screenshots - no conflict risk (filenames are timestamped), straight merge.
Merge-DirOverwrite "screenshots"

# Any resourcepacks/shaderpacks you added yourself beyond what the pack
# ships. Never clobbers the pack's own current Whimscape/Complementary
# Shaders files with an older carried-over copy.
Merge-DirNoOverwrite "resourcepacks"
Merge-DirNoOverwrite "shaderpacks"

Write-Host "Done."
