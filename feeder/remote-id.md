# Feeding Remote ID (drones) to WellClear

Drones don't transmit on 1090 MHz — they broadcast **Remote ID** over
Bluetooth/Wi-Fi (FAA/EU mandatory). To track them, a receiver needs a Remote
ID radio; the open-source path uses a [DroneScout](https://dronescout.co/)
receiver and [rid2all](https://github.com/kylehodgson/rid2all).

```
DroneScout DS110/DS220/DB120 ──MAVLink (USB serial)──▶ rid2all ─┬─SBS──▶ ultrafeeder (local map)
                                                               └─SBS──▶ feed.wellclear.aero:30105 (network)
```

**Three steps.** Drones appear on the WellClear network map with synthesized
`FFxxxx` hexes alongside regular aircraft.

> **Why the direct push?** readsb forwards only raw Mode-S messages on its
> beast outputs — SBS-ingested aircraft (our drones) never ride the beast
> feed (verified in readsb `net_io.c`: SBS-input messages go to SBS outputs
> only). So drones reach the hub via rid2all's direct SBS push; everything
> else (your 1090 feed, MLAT) is unaffected.

## Install (ultrafeeder / adsb.im compose stack)

1. **Plug the DroneScout radio** into the Pi (USB). It shows up as
   `/dev/ttyACM0` (`ls /dev/ttyACM*`).
2. **Run the installer** (from the rid2all repo, or once published:
   `curl -fsSL <raw-url>/setup-ultrafeeder.sh | sudo bash`):
   ```sh
   git clone https://github.com/kylehodgson/rid2all && cd rid2all
   sudo bash setup-ultrafeeder.sh /opt/adsb     # your compose dir
   ```
   The script writes a compose **override** file (your `docker-compose.yml`
   is never touched), the rid2all config, the shared drone-db dir, starts
   the containers, and verifies the push connected.
3. **Check**: the script's last lines show `SBS push into ultrafeeder:
   CONNECTED`. Drones appear on your local tar1090 map
   (`http://<pi>:8080`) and on wellclear.aero's map within a minute of
   flying.

Re-run the script any time (e.g. after moving the radio or changing USB
ports) — it's idempotent.

### Troubleshooting

- **`no /dev/ttyACM0`** — radio not plugged in / different port
  (`ls /dev/ttyACM*`); re-run the script after plugging in.
- **rid2all crash-looping with "config.toml is a DIRECTORY"** — you ran
  `docker compose up` before the config file existed; the script fixes this
  itself on re-run (`rm -rf /opt/adsb/config.toml` then re-run).
- **"READSB_EXTRA_ARGS already set" note** — your stack already uses that
  env var; merge the `--db-file=/rid-db/db.csv.gz` flag into your existing
  value.

## What the script changes (and doesn't)

| File | Change |
|---|---|
| `docker-compose.override.yml` | **new** (auto-loaded by compose) — rid2all service + ultrafeeder SBS input/db env |
| `rid2all-config.toml` | **new** — rid2all config |
| `rid-db/` | **new** — drone db export + copy of the standard aircraft db |
| `docker-compose.yml` | **unchanged** |
| existing feeds (piaware, adsb.fi, …) | **unchanged** |

Uninstall: `docker compose down && rm docker-compose.override.yml && docker compose up -d`
(rm `rid2all-config.toml` and `rid-db/` too if you want a full cleanup).

## Requirements

- DroneScout receiver (DS110 dongle, DS220, or DB120) — 2.4 GHz Bluetooth
  Legacy/Long Range + WLAN Beacon Remote ID
- A Raspberry Pi or any Linux box already running an ultrafeeder compose stack
- No SDR needed for drone reception (coexists with your 1090 MHz feed)

## Without ultrafeeder (or second push target)

rid2all can push SBS straight to the hub (and to multiple targets at once):
`feed.wellclear.aero:${HUB_SBS_IN_PORT}` (internal 30106, currently 30105
host-side). Add to `rid2all-config.toml`:

```toml
[[sbs.push]]
host = "feed.wellclear.aero"
port = 30105
```

## Local display polish (optional — no effect on feeding)

By default tar1090 shows drones with its stock UAV icon (a fixed-wing
military drone silhouette) and no type/reg info. For a proper quadcopter
icon + type/description/serial in the popup:

- the `--db-file` flag on ultrafeeder (already set by the installer) makes
  readsb load rid2all's per-drone db export (type code Q4 = rotorcraft);
- a small tar1090 `markers.js` + sprite patch maps Q-codes to a
  multicopter icon — pending as an upstream PR; ping us if you want the patch.
