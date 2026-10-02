# immich-ml-remote

Immich's Smart Search and Face Detection, moved off the server. The i5-7200U
cannot afford the ~40% CPU and 3GB of RAM the local ML container costs, so it
runs on the PC and the server points at it.

## Setup on the PC

1. Docker Desktop with the WSL2 backend, set to start with Windows — with the
   engine down, Immich keeps answering while its ML does nothing.
2. `docker compose up -d`
3. In Immich: **Administration -> Settings -> Machine Learning Settings**, and
   set the URL to `http://10.0.30.135:3003`. The server also carries
   `IMMICH_MACHINE_LEARNING_URL`, but the admin setting is what the jobs use.
4. **Administration -> Jobs**, then run *Smart Search* and *Face Detection* with
   **All** (not *Missing*) the first time, so the backlog gets embeddings.

## Version

The tag here and `immich-server` have to be the same version. A mismatch does
not degrade anything — it stops the server from starting.

## Why CPU-only

This PC has an AMD GPU, and Immich's `-rocm` image needs native `/dev/kfd` and
`/dev/dri`, which Docker Desktop on WSL2 does not pass through. AMD's WSL2 ROCm
bridge is outside what the `-rocm` image supports.
<https://github.com/immich-app/immich/discussions/26459>

## Exposure

The ML container has no authentication. Port 3003 stays on the LAN.
