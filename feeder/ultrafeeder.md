# Feeding WellClear from an ultrafeeder / adsb.im install

One config change. Your existing feeds are untouched; MLAT return data is
integrated automatically by ultrafeeder (no extra config).

## The environment

Add to the ultrafeeder environment (docker-compose `environment:` list or the
adsb.im web UI "Feeder" page):

```yaml
- UUID=<your-uuid>                               # your feeder UUID (REQUIRED, see below)
- READSB_LAT=<your-lat>
- READSB_LON=<your-lon>
- ALT=<your-alt-m>
- ULTRAFEEDER_CONFIG=adsb,<hub-host>,30004,beast_reduce_plus_out,uuid=${UUID};mlat,<hub-host>,31090,uuid=${UUID}
```

Replace the `<...>` placeholders: `UUID` is the feeder UUID you registered with
(see "Am I feeding?" below), `READSB_LAT`/`READSB_LON` your receiver coordinates
in decimal degrees, and `ALT` your altitude **in metres** (e.g. `320`).

- `<hub-host>` — the WellClear ingest hostname (or IP while in beta)
- **Use the SAME UUID for the adsb and mlat constructs** — one station is one
  identity in the network registry. Note it must ALSO be set as the standalone
  `UUID` env: the ultrafeeder mlat-client service refuses to start without it
  (verified in the sdr-enthusiasts image's s6 script), even though the
  per-construct `uuid=` is documented.
- The image wants `READSB_LAT`/`READSB_LON` for the mlat-client location; plain
  `LAT`/`LON` were rejected by the mlat service in our test (17.1 image, 2026-10).
- Semicolons separate constructs; a single construct needs no trailing semicolon
  (common gotcha — this bit our first beta feeder).
- If you already have `ULTRAFEEDER_CONFIG` entries (e.g. for other networks),
  append ours after a `;` — do not create a second variable.

## After applying

Restart ultrafeeder, then check https://<portal>/ ("Am I feeding?") — you should
see your receiver listed within a couple of minutes. From there you can log in
with a magic link and claim your receiver.

## Status

- **Live-verified** with a real ultrafeeder installation (beta feeder 1) feeding
  both 1090 and MLAT (2026-10-07).
- **Container-verified end to end** against the live dev hub (2026-10-07,
  sdr-enthusiasts image): receiver appeared in the hub registry and the
  mlat-client connected to our MLAT server, using exactly the envs above.
- Syntax verified against sdr-enthusiasts/docker-adsb-ultrafeeder README
  (`ULTRAFEEDER_CONFIG` adsb + mlat constructs).