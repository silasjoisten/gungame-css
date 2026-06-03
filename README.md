# GunGame Deathmatch — Counter-Strike: Source

A **GunGame team-deathmatch** setup for Counter-Strike: Source — instant respawn,
spawn protection, Rock The Vote, all weapons (no grenade level), bots only on the
enemy team, a winner UI + map change — runnable as a **headless Docker server**
on Linux or as a local Windows listen/dedicated server.

## What's in here

| Path | What |
|------|------|
| `Dockerfile`, `docker-compose.yml`, `entrypoint.sh` | Headless Linux server image: installs CS:S DS (SteamCMD app 232330) + Linux Metamod:Source & SourceMod, overlays the mod |
| `gather-mod.ps1` | Collects the platform-independent mod files (plugins, cfg, maps, sounds) from a CS:S install into `css-mod/` |
| `src/` | **Custom SourcePawn plugins** (the original work) |
| `config/` | Tuned configs (server.cfg, GunGame config + weapon ladder, plugin cvars) |
| `windows/` | Helper `.bat` scripts for running locally on Windows |
| `mapcycle.txt` | Sample map rotation (gg_/aim_/fy_) |

### Custom plugins (`src/`)
- **`dm_respawn.sp`** — instant respawn + reliable SDKHooks spawn protection; also
  spawns new joiners (rounds never restart) and waits for class/model selection.
- **`bot_balance.sp`** — keeps bots at `humans + N` (`sm_botbalance_extra`).
- **`gg_winner_mapchange.sp`** — on a GunGame win: shows a winner UI message,
  freezes everyone briefly, then changes to the voted next map (`sm_nextmap`).

Compile with the SourceMod compiler: `spcomp dm_respawn.sp` (needs the GunGame
includes from <https://github.com/altexdim/sourcemod-plugin-gungame>).

## Run it on Linux (Docker)

> Maps and compiled plugins are **not** in this repo (too large / build artifacts).
> Generate the `css-mod/` overlay from a real CS:S install first.

1. **Build the overlay** (on a machine with a CS:S install, e.g. Windows):
   ```powershell
   powershell -ExecutionPolicy Bypass -File gather-mod.ps1 -CsRoot "D:\SteamLibrary\steamapps\common\Counter-Strike Source"
   ```
   This fills `css-mod/` (incl. the gg_/aim_/fy_ maps).
2. Get the repo **and** the populated `css-mod/` onto the Linux host.
3. Build & run:
   ```bash
   docker compose up -d --build
   docker compose logs -f
   ```
4. Connect: `connect <linux-host-ip>:27015` (open UDP 27015 on the host).

## Run it locally on Windows
Install Metamod:Source + SourceMod + GunGame into your CS:S `cstrike/addons`,
drop the `config/` files and `src/*.smx` in place, then start with
`windows/gungame-server.bat` (and `windows/allow-server-firewall.bat` once, as admin).

## Stack
Metamod:Source 1.12 · SourceMod 1.12 · GunGame:SM (altexdim build) · custom plugins above.
