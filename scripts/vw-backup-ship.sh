#!/bin/sh
# Ships the latest Vaultwarden snapshot from the router (USB pendrive) to:
#   1. the RAID SMB share (/mnt/storage-smb, backing host may change — only
#      the local mountpoint matters here)
#   2. the server's local SSD (/srv/backups/vaultwarden) as a second copy
# Runs hourly via root cron. Requires the server's ~/.ssh/id_ed25519_openwrt
# to be authorized on the router.
set -e

ROUTER_KEY="$HOME/.ssh/id_ed25519_openwrt"
ROUTER="root@10.0.30.1"
DEST_SMB="/mnt/storage-smb/backups/vaultwarden"
DEST_LOCAL="/srv/backups/vaultwarden"
KEEP=72

latest=$(ssh -i "$ROUTER_KEY" -o BatchMode=yes "$ROUTER" "ls -1t /opt/docker-usb/backups/vw-*.tar.gz 2>/dev/null | head -1")
[ -z "$latest" ] && exit 0
name=$(basename "$latest")

[ -f "$DEST_SMB/$name" ] && exit 0

mkdir -p "$DEST_SMB" "$DEST_LOCAL"
ssh -i "$ROUTER_KEY" -o BatchMode=yes "$ROUTER" "cat $latest" > "$DEST_SMB/$name"
gzip -t "$DEST_SMB/$name"
cp "$DEST_SMB/$name" "$DEST_LOCAL/$name"

# retention on both destinations: keep newest $KEEP
for dir in "$DEST_SMB" "$DEST_LOCAL"; do
  ls -1t "$dir"/vw-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do rm -f "$f"; done
done
