#!/usr/bin/env bash
# Copy build/runix.2mg to diskserver.local if that host is on the LAN.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE="$ROOT/build/runix.2mg"
DISKSERVER="${DISKSERVER:-diskserver.local}"
DEPLOY_TARGET="${DEPLOY_TARGET:-${DISKSERVER}:/srv/apple2_share/Runix.2mg}"

if [[ ! -f "$IMAGE" ]]; then
	echo "Building disk image..."
	(cd "$ROOT" && rotoskop build)
fi

if ! python3 "$ROOT/mdns_chk.py" "$DISKSERVER" >/dev/null 2>&1; then
	echo "Note: Disk server $DISKSERVER not found on network"
	exit 0
fi

echo "Deploying to $DEPLOY_TARGET..."
rsync -a --inplace --progress --compress "$IMAGE" "$DEPLOY_TARGET"
echo "Deployed successfully"
