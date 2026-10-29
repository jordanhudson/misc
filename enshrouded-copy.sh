#!/usr/bin/env bash
#
# Copy files into the Enshrouded server folder (/home/steam/enshrouded) inside
# the enshrouded container on the Beelink, overwriting any existing copies.
#
# Usage: enshrouded-copy.sh [--restart] FILE...
#
# Files are streamed in as the steam user, so overwritten files keep their
# steam ownership. Pass --restart to restart the container afterwards.

set -euo pipefail

HOST=jordan@192.168.1.80
CONTAINER=enshrouded-enshrouded-1
DEST=/home/steam/enshrouded

die() { echo "Error: $*" >&2; exit 1; }

restart=0
if [ "${1:-}" = "--restart" ]; then
    restart=1
    shift
fi

[ $# -gt 0 ] || die "usage: $(basename "$0") [--restart] FILE..."

for f in "$@"; do
    [ -f "$f" ] || die "not a file: $f"
done

for f in "$@"; do
    target="$DEST/$(basename "$f")"
    ssh "$HOST" "docker exec -i $CONTAINER sh -c 'cat > \"\$1\"' sh $(printf '%q' "$target")" < "$f" \
        || die "failed to copy $f"
    echo "Copied $f -> $CONTAINER:$target"
done

if [ "$restart" -eq 1 ]; then
    ssh "$HOST" docker restart "$CONTAINER" >/dev/null
    echo "Restarted $CONTAINER"
fi
