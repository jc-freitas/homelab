# Custom Jellyfin image that BAKES IN the linuxserver "jellyfin-opencl-intel"
# mod (Intel compute-runtime OpenCL .deb packages + clinfo) at build time
# instead of installing them on every container start via DOCKER_MODS.
#
# Why: the LSIO mod runs `dpkg -i` of the Intel OpenCL debs on EVERY start,
# which takes ~8 minutes. The flaky USB NIC force-recreates this container on
# every flap (see /etc/network/interfaces), so that 8 min became a recurring
# outage. Baking the debs in cuts cold-start to ~30 s. Functionally identical
# to the mod (same debs, same clinfo) — QSV/VAAPI + OpenCL tone-mapping intact.
#
# Rebuild when bumping the base image or to pick up newer Intel drivers:
#   docker compose build --pull && docker compose up -d
FROM linuxserver/mods:jellyfin-opencl-intel AS mod

FROM lscr.io/linuxserver/jellyfin:latest

# The mod image carries the pre-downloaded Intel compute-runtime debs at these
# paths (see the mod's Dockerfile). Install them once, here, at build time.
COPY --from=mod /opencl-intel-legacy1 /tmp/opencl-intel-legacy1
COPY --from=mod /opencl-intel /tmp/opencl-intel
RUN set -e; \
    dpkg -i /tmp/opencl-intel-legacy1/*.deb || true; \
    dpkg -i /tmp/opencl-intel/*.deb || true; \
    apt-get update; \
    apt-get install -f -y --no-install-recommends; \
    apt-get install -y --no-install-recommends clinfo; \
    rm -rf /tmp/opencl-intel-legacy1 /tmp/opencl-intel /var/lib/apt/lists/*
