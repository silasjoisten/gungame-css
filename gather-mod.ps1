<#
  Collects the platform-INDEPENDENT GunGame mod files from a Counter-Strike:
  Source install into  ./css-mod/  so the Dockerfile can overlay them onto the
  fresh Linux Metamod/SourceMod inside the container.

  It deliberately SKIPS the Windows MM:S / SourceMod core binaries - those are
  reinstalled as Linux .so in the image. Only .smx plugins, configs, cfg, maps,
  sounds and translations are copied (all cross-platform).

  Usage (from the repo root):
    powershell -ExecutionPolicy Bypass -File gather-mod.ps1 -CsRoot "D:\SteamLibrary\steamapps\common\Counter-Strike Source"
#>
param(
    [string]$CsRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $CsRoot) {
    foreach ($t in @((Join-Path $PSScriptRoot "cstrike"), (Join-Path (Split-Path $PSScriptRoot -Parent) "cstrike"))) {
        if (Test-Path $t) { $CsRoot = Split-Path $t -Parent; break }
    }
}
if (-not $CsRoot -or -not (Test-Path (Join-Path $CsRoot "cstrike"))) {
    throw "CS:S install not found. Pass -CsRoot '<path to ...\Counter-Strike Source>'."
}

$cstrike = Join-Path $CsRoot "cstrike"
$dest    = Join-Path $PSScriptRoot "css-mod"
if (Test-Path $dest) { Get-ChildItem $dest | Remove-Item -Recurse -Force }
New-Item -ItemType Directory -Path $dest -Force | Out-Null

function Copy-Into($relSource, $relDestDir, $filter = $null) {
    $src = Join-Path $cstrike $relSource
    if (-not (Test-Path $src)) { Write-Host "  (skip, not found) $relSource"; return }
    $dst = Join-Path $dest $relDestDir
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    if ($filter) { Get-ChildItem $src -Filter $filter -File | ForEach-Object { Copy-Item $_.FullName $dst -Force } }
    else { Copy-Item (Join-Path $src '*') $dst -Recurse -Force }
}

Write-Host "Gathering GunGame mod overlay from: $cstrike`n  into: $dest`n"

# --- SourceMod plugins (GunGame + our custom + the vote plugins we enabled) --
$plugins = @(
    "gungame.smx","gungame_afk.smx","gungame_bot.smx","gungame_config.smx",
    "gungame_display_winner.smx","gungame_logging.smx","gungame_mapvoting.smx",
    "gungame_sdkhooks.smx","gungame_stats.smx","gungame_tk.smx",
    "gungame_warmup_configs.smx","gungame_winner_effects.smx",
    "dm_respawn.smx","bot_balance.smx","gg_winner_mapchange.smx",
    "rockthevote.smx","mapchooser.smx","nominations.smx","nextmap.smx"
)
$pdst = Join-Path $dest "addons\sourcemod\plugins"
New-Item -ItemType Directory -Path $pdst -Force | Out-Null
foreach ($p in $plugins) {
    $f = Join-Path $cstrike "addons\sourcemod\plugins\$p"
    if (Test-Path $f) { Copy-Item $f $pdst -Force } else { Write-Host "  (skip) plugin $p" }
}
Write-Host "  plugins"

Copy-Into "addons\sourcemod\translations" "addons\sourcemod\translations" "gungame*.txt"
Copy-Into "addons\sourcemod\configs"      "addons\sourcemod\configs"      "admins_simple.ini"
Copy-Into "addons\sourcemod\configs"      "addons\sourcemod\configs"      "maps.cfg"
Copy-Into "cfg" "cfg" "server.cfg"
Copy-Into "cfg\gungame" "cfg\gungame"
$smcfgDst = Join-Path $dest "cfg\sourcemod"
New-Item -ItemType Directory -Path $smcfgDst -Force | Out-Null
foreach ($c in "dm_respawn.cfg","bot_balance.cfg","gg_winner_mapchange.cfg") {
    $f = Join-Path $cstrike "cfg\sourcemod\$c"
    if (Test-Path $f) { Copy-Item $f $smcfgDst -Force }
}
$mc = Join-Path $cstrike "mapcycle.txt"
if (Test-Path $mc) { Copy-Item $mc $dest -Force }
Copy-Into "sound\gungame" "sound\gungame"
Write-Host "  translations, configs, cfg/gungame, cfg/sourcemod, mapcycle, sounds"

# --- Maps (gg_/aim_/fy_) -> the repo ./maps/ folder (NOT css-mod) -----------
$mapsDst = Join-Path $PSScriptRoot "maps"
New-Item -ItemType Directory -Path $mapsDst -Force | Out-Null
$maps = Get-ChildItem (Join-Path $cstrike "maps") -Filter "*.bsp" | Where-Object { $_.BaseName -match '^(gg|aim|fy)_' }
foreach ($m in $maps) { Copy-Item $m.FullName $mapsDst -Force }
$mb = [math]::Round((($maps | Measure-Object Length -Sum).Sum / 1MB), 0)
Write-Host ("  {0} maps (~{1} MB) -> ./maps/" -f $maps.Count, $mb)

Write-Host "`nDone -> $dest`nNow:  docker compose up -d --build"
