#!/usr/bin/env bash
# WellClear feeder installer — fallback path for plain readsb installs.
#
# What it does:
#   1. ensures a feeder UUID exists (/var/lib/wellclear-feeder/uuid, reused if present)
#   2. adds ONE net-connector line to /etc/default/readsb (NET_OPTIONS)
#   3. installs an wellclear-mlat-client systemd service (if lat/lon provided)
# It changes nothing else and is idempotent — safe to run repeatedly.
#
# Usage:
#   sudo WELLCLEAR_HUB_HOST=<hub> WELLCLEAR_LAT=43.5 WELLCLEAR_LON=-80.4 WELLCLEAR_ALT=320 ./install.sh
#   (or pass --hub / --lat / --lon / --alt / --uuid; --dry-run supported)
#
# License note: this script configures GPL components but contains no GPL code.

set -euo pipefail

HUB="${WELLCLEAR_HUB_HOST:-}"
BEAST_PORT="${WELLCLEAR_BEAST_PORT:-30004}"
MLAT_PORT="${WELLCLEAR_MLAT_PORT:-31090}"
LAT="${WELLCLEAR_LAT:-}"
LON="${WELLCLEAR_LON:-}"
ALT="${WELLCLEAR_ALT:-}"
UUID="${WELLCLEAR_UUID:-}"
UUID_FILE="/var/lib/wellclear-feeder/uuid"
DEFAULT_READSB="/etc/default/readsb"
MARKER="wellclear-feeder"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hub) HUB="$2"; shift 2 ;;
        --lat) LAT="$2"; shift 2 ;;
        --lon) LON="$2"; shift 2 ;;
        --alt) ALT="$2"; shift 2 ;;
        --uuid) UUID="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        *) echo "unknown arg: $1"; exit 1 ;;
    esac
done

run() {
    echo "+ $*"
    if [[ $DRY_RUN -eq 0 ]]; then "$@"; fi
}

[[ -n $HUB ]] || { echo "ERROR: set WELLCLEAR_HUB_HOST or --hub"; exit 1; }
[[ $(id -u) -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }

# --- 1. UUID: reuse if we or the existing readsb config already have one -------
if [[ -z $UUID ]]; then
    if [[ -f $UUID_FILE ]]; then
        UUID=$(cat "$UUID_FILE")
        echo "reusing existing UUID: $UUID"
    elif grep -o 'uuid-file[= ][^ "]*' "$DEFAULT_READSB" 2>/dev/null | awk '{print $2}' | head -1 | grep -q .; then
        UUID=$(grep -o 'uuid-file[= ][^ "]*' "$DEFAULT_READSB" | awk '{print $2}' | head -1)
        echo "reusing readsb --uuid-file UUID: $UUID"
    else
        UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
        run mkdir -p "$(dirname "$UUID_FILE")"
        echo "$UUID" > "$UUID_FILE"
        run chmod 644 "$UUID_FILE"
        echo "generated new UUID: $UUID (saved to $UUID_FILE)"
    fi
fi
# readsb hashes only the first 16 hex digits into the stable receiver id
if [[ ${UUID:0:16} == "00000000-0000-00" ]]; then
    echo "WARNING: UUID starts with too many zeros; pick a more random one"
fi

# --- 2. readsb net-connector into /etc/default/readsb ---------------------------
CONNECTOR="--net-connector=${HUB},${BEAST_PORT},beast_reduce_plus_out,uuid=${UUID}"
if [[ -f $DEFAULT_READSB ]] && grep -q "$MARKER" "$DEFAULT_READSB"; then
    echo "readsb connector already present; leaving unchanged"
elif [[ -f $DEFAULT_READSB ]]; then
    run cp "$DEFAULT_READSB" "${DEFAULT_READSB}.wellclear.bak"
    if grep -q '^NET_OPTIONS=' "$DEFAULT_READSB"; then
        run sed -i "s|^NET_OPTIONS=\"\(.*\)\"|NET_OPTIONS=\"\1 ${CONNECTOR}\" # ${MARKER}|" "$DEFAULT_READSB"
    else
        run tee -a "$DEFAULT_READSB" > /dev/null <<< "NET_OPTIONS=\"${CONNECTOR}\" # ${MARKER}"
    fi
    echo "added connector to $DEFAULT_READSB (backup: ${DEFAULT_READSB}.wellclear.bak)"
else
    echo "WARNING: $DEFAULT_READSB not found — is readsb installed? skipping connector"
fi

# --- 3. mlat-client service (needs a receiver location) --------------------------
if [[ -n $LAT && -n $LON ]]; then
    VENV=/usr/local/share/wellclear-mlat/venv
    if [[ ! -x $VENV/bin/mlat-client ]]; then
        run apt-get update -qq
        run apt-get install -y -qq python3-pip python3-venv git build-essential python3-dev ca-certificates
        run install -d -m 755 "$(dirname "$VENV")"
        run python3 -m venv "$VENV"
        run "$VENV/bin/pip" install --quiet \
            "git+https://github.com/wiedehopf/mlat-client@28ae4f7409c9dfddd2bb8984baadce5d31fdc8e3"
    fi
    run mkdir -p /etc/systemd/system
    cat <<UNIT | run tee /etc/systemd/system/wellclear-mlat-client.service > /dev/null
[Unit]
Description=WellClear mlat-client
After=readsb.service network-online.target
Wants=network-online.target

[Service]
ExecStart=$VENV/bin/mlat-client --input-connect 127.0.0.1:30005 --input-type dump1090 --server ${HUB}:${MLAT_PORT} --user ${UUID} --uuid ${UUID} --lat ${LAT} --lon ${LON} --alt ${ALT:-0}
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
    run systemctl daemon-reload
    run systemctl enable --now wellclear-mlat-client
    echo "mlat-client service installed"
else
    echo "no --lat/--lon given: skipping mlat-client (beast feed only)"
fi

# --- 4. restart readsb if we changed its config ----------------------------------
if [[ -f $DEFAULT_READSB ]] && grep -q "$MARKER" "$DEFAULT_READSB" && [[ $DRY_RUN -eq 0 ]]; then
    run systemctl restart readsb
fi

echo
echo "Done. Your feeder UUID: $UUID"
echo "Check https://<portal>/ 'Am I feeding?' within a couple of minutes."