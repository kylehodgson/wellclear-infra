#!/bin/bash
# Hub readsb entrypoint — network-only aggregator.
# Flags verified against wiedehopf/readsb at the pinned commit (docs/DECISIONS.md).
set -euo pipefail

: "${HUB_BEAST_IN_PORT:=30004}"     # feeders connect here (beast_reduce_plus_out + uuid)
: "${HUB_BEAST_OUT_PORT:=30005}"    # beast out for consumers

mkdir -p /run/readsb /run/globe_history

# Verified (docs/DECISIONS.md §9): --net-bi-port is the Beast *input* listener
# (READ_MODE_BEAST/decodeBinMessage); --net-bo-port is a beast OUTPUT server that
# ignores data. Feeders must land on bi-port.
exec tini -- readsb \
    --net \
    --net-only \
    --net-bi-port="${HUB_BEAST_IN_PORT},30104" \
    --net-bo-port="${HUB_BEAST_OUT_PORT}" \
    --net-sbs-in-port=30106 \
    --net-receiver-id \
    --net-ingest \
    --devel=ping_reject,30000 \
    --max-range=99999 \
    --write-json=/run/readsb \
    --write-receiver-id-json \
    --write-json-every=1 \
    --json-location-accuracy=2 \
    --write-globe-history=/run/globe_history \
    --db-file=/usr/local/share/aircraft.csv.gz \
    --quiet
