# The Intel OpenCL mod is baked in instead of run through DOCKER_MODS, which
# does `dpkg -i` of these debs on every container start: ~8 minutes. The flaky
# USB NIC force-recreates this container on every flap, so that became a
# recurring outage. Cold start is ~30s now.
#
# Rolling tag with no published versions, so there is nothing to pin: the Intel
# drivers can change under a rebuild, which makes rebuilding a deliberate act.
FROM linuxserver/mods:jellyfin-opencl-intel AS mod

# Pinned to the version this image was built from. A version jump is what left
# the server stuck on an Intro Skipper migration lock for a whole startup.
FROM lscr.io/linuxserver/jellyfin:10.11.11ubu2404-ls41

COPY --from=mod /opencl-intel-legacy1 /tmp/opencl-intel-legacy1
COPY --from=mod /opencl-intel /tmp/opencl-intel
RUN set -e; \
    dpkg -i /tmp/opencl-intel-legacy1/*.deb || true; \
    dpkg -i /tmp/opencl-intel/*.deb || true; \
    apt-get update; \
    apt-get install -f -y --no-install-recommends; \
    apt-get install -y --no-install-recommends clinfo; \
    rm -rf /tmp/opencl-intel-legacy1 /tmp/opencl-intel /var/lib/apt/lists/*
