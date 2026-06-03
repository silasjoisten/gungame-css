# Counter-Strike: Source GunGame Deathmatch - headless dedicated server
# Base: cm2network/steamcmd (Debian + SteamCMD + the 32/64-bit libs srcds needs).
# Runs as the unprivileged 'steam' user - SteamCMD refuses to write depot files
# as root ("Missing file permissions").
FROM cm2network/steamcmd:latest

ENV APPID=232330 \
    CSSDIR=/home/steam/css
ENV CSTRIKE=${CSSDIR}/cstrike

# wget/ca-certificates for downloading Metamod/SourceMod (needs root)
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*
USER steam

# 1) Install the Counter-Strike: Source dedicated server (anonymous login).
#    SteamCMD frequently fails the FIRST app_update with "Missing configuration"
#    because it self-updates on first run -> retry a few times, then verify.
RUN set -eux; \
    for i in 1 2 3 4 5; do \
        /home/steam/steamcmd/steamcmd.sh \
            +force_install_dir ${CSSDIR} \
            +login anonymous \
            +app_update ${APPID} validate \
            +quit && break || { echo "steamcmd attempt $i failed; retrying in 10s..."; sleep 10; }; \
    done; \
    test -f ${CSSDIR}/srcds_run

# 2) Install the LATEST stable 1.12 Metamod:Source + SourceMod for Linux
RUN set -eux; \
    cd ${CSTRIKE}; \
    MM="$(wget -qO- https://mms.alliedmods.net/mmsdrop/1.12/mmsource-latest-linux)"; \
    wget -q "https://mms.alliedmods.net/mmsdrop/1.12/${MM}" -O /tmp/mm.tgz; \
    tar xzf /tmp/mm.tgz; rm /tmp/mm.tgz; \
    SM="$(wget -qO- https://sm.alliedmods.net/smdrop/1.12/sourcemod-latest-linux)"; \
    wget -q "https://sm.alliedmods.net/smdrop/1.12/${SM}" -O /tmp/sm.tgz; \
    tar xzf /tmp/sm.tgz; rm /tmp/sm.tgz

# 3) Overlay YOUR GunGame mod (compiled .smx plugins, cfg, maps, sounds, translations).
#    These files are platform-independent and sit on top of the Linux MM:S/SM cores.
#    Populate ./css-mod first by running docker/gather-mod.ps1 on the Windows machine.
COPY --chown=steam:steam css-mod/ ${CSTRIKE}/

# entrypoint (needs root to chmod, then drop back to steam)
USER root
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh
USER steam

WORKDIR ${CSSDIR}
ENTRYPOINT ["/entrypoint.sh"]
