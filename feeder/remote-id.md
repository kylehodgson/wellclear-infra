# Feeding Remote ID (drones) to WellClear

Drones don't transmit on 1090 MHz — they broadcast **Remote ID** over
Bluetooth/Wi-Fi (FAA/EU mandatory). To track them, a receiver needs a Remote
ID radio; the open-source path uses a [DroneScout](https://dronescout.co/)
receiver and [rid2all](https://github.com/kylehodgson/rid2all).

```
DroneScout DS110/DS220/DB120 ──MAVLink (USB serial)──▶ rid2all ─┬─SBS─▶ ultrafeeder ─beast─▶ feed.wellclear.aero
                                                                └─SBS (direct)─▶ feed.wellclear.aero:$HUB_SBS_IN_PORT
```

rid2all is an open-source daemon (MIT) that:

- reads both DroneScout MAVLink formats (`OPEN_DRONE_ID_MESSAGE_PACK` and
  `ADSB_VEHICLE`, auto-detected — switch the radio's mode any time)
- tracks multiple aircraft, deduplicates GNSS jitter (stationary hold)
- emits SBS/BaseStation: serves a port and/or pushes to ultrafeeder's
  `READSB_NET_SBS_INPUT_PORT`
- writes a readsb aircraft db (`--db-file`) so tar1090 shows drone
  type/description/serial — with a `multicopter` tar1090 patch available
  (upstream PR pending) for a proper drone icon instead of the fixed-wing
  'uav' silhouette

## Install

Full instructions (including a drop-in service for an existing
ultrafeeder compose stack) live in the rid2all repo:

**https://github.com/kylehodgson/rid2all** — see the README quick start and
`compose-examples/ultrafeeder-service.yml` / `ultrafeeder-config.toml`.

Short version: run rid2all in the same compose network as your ultrafeeder,
push SBS to `ultrafeeder:32006` with
`READSB_NET_SBS_INPUT_PORT=32006` set on the ultrafeeder service, and add
`READSB_EXTRA_ARGS=--db-file=/rid-db/db.csv.gz` + a shared `rid-db` volume
for the drone details/icon.

## Feeding WellClear

Two paths to the hub:

1. **Via ultrafeeder (default):** readsb merges the rid2all SBS into its
   aircraft table, and the normal `beast_reduce_plus_out` connector to
   `feed.wellclear.aero:30004` forwards everything (drones appear with
   synthesized `FFxxxx` ICAOs — an unassigned ICAO prefix that marks
   non-Mode-S sources).
2. **Direct SBS push:** the hub exposes a dedicated Remote ID SBS ingest on
   `feed.wellclear.aero:${HUB_SBS_IN_PORT}` (internal 30106). Add a `[[push]]`
   target to rid2all's `config.toml` — no ultrafeeder config change needed.
   Use path 1 if your Pi already runs ultrafeeder; path 2 otherwise.

The hub SBS port is unauthenticated input like the beast port; both are open
in the EC2 security group so feeders on dynamic IPs can connect — restrict
them to known feeder IPs if you can.

## Requirements

- DroneScout receiver (DS110 dongle, DS220, or DB120) — 2.4 GHz Bluetooth
  Legacy/Long Range + WLAN Beacon Remote ID
- A Raspberry Pi or any Linux box running the ultrafeeder compose stack
- No SDR needed for drone reception (keeps working alongside your 1090 MHz feed)
