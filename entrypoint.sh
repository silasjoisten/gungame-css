#!/bin/bash
set -e

CSTRIKE=/home/steam/css/cstrike

# Pick a random start map from mapcycle.txt (same behaviour as the Windows .bat).
# Override by setting SRCDS_STARTMAP in docker-compose.yml.
MAP="${SRCDS_STARTMAP:-}"
if [ -z "$MAP" ] && [ -s "${CSTRIKE}/mapcycle.txt" ]; then
    MAP="$(shuf -n1 "${CSTRIKE}/mapcycle.txt" | tr -d '\r')"
fi
[ -z "$MAP" ] && MAP="gg_simpsons_dust2"

echo ">>> Starting GunGame Deathmatch  (map: ${MAP}, port: ${SRCDS_PORT:-27015})"

cd /home/steam/css
exec ./srcds_run \
    -game cstrike \
    -console \
    -usercon \
    -port "${SRCDS_PORT:-27015}" \
    +maxplayers "${SRCDS_MAXPLAYERS:-16}" \
    +map "${MAP}" \
    +exec server.cfg
