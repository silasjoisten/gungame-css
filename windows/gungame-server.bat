@echo off
REM ==========================================================================
REM  Start a local GunGame Deathmatch dedicated server (64-bit).
REM
REM  The server runs on its OWN port 27066 so the game client (27015/27016)
REM  can never steal it - start order no longer matters.
REM
REM  Open CS:S and join yourself with:   connect 127.0.0.1:27066
REM  Friends (internet) join with:       connect 83.168.45.20:27066
REM  -> The router must forward UDP 27066 to 192.168.10.8
REM ==========================================================================
cd /d "%~dp0"

REM Pick a RANDOM start map from the map list (cstrike\mapcycle.txt).
set "MAP=gg_simpsons_dust2"
for /f "delims=" %%M in ('powershell -NoProfile -Command "Get-Random -InputObject (Get-Content 'cstrike\mapcycle.txt')"') do set "MAP=%%M"
echo Starting on random map: %MAP%

start "GunGame Server" srcds_win64.exe -game cstrike -console -insecure -port 27066 +maxplayers 16 +map %MAP% +exec server.cfg
exit
