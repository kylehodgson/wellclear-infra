# DECISIONS.md — verified upstream facts and deviations

Phase 0 rule from the plan: *every* flag, port, config key and license claim below was
checked against current upstream source on 2026-10-06, not taken from memory. Source
links point at the exact file or repo section used.

Pinned upstream refs (verified via GitHub API on 2026-10-06):

| Component | Repo | Pinned commit | Commit date |
| --- | --- | --- | --- |
| readsb | wiedehopf/readsb | `094720939c01943de82b14df6f42f67fff1cd514` | 2026-09-27 |
| mlat-server | wiedehopf/mlat-server | `9b27a6d609c5bb47549016412222a79ecb0f48e4` | 2026-04-03 |
| tar1090 | wiedehopf/tar1090 | `e784ee5ae82948f41efe3ef5c235ade0943ab8ff` | 2026-09-29 |
| TimescaleDB image | `timescale/timescaledb` | tag `2.17.2-pg16`, digest `sha256:4e459e217f00cbb09920c34d245501e63427e6767a495de57ce76823ff280f12` | — |

Re-verify these SHAs before each phase; update this table when we bump.

---

## 1. How an aggregator readsb receives feeds with receiver UUIDs

**Feeder side** (verified: readsb `README.md`, "BeastReduce output" section):

```
--net-connector=feed.example.com,30004,beast_reduce_plus_out,uuid=0033062d-e17e-4389-91a9-79ebb967fb4c
```

- `beast_reduce_plus_out` sends throttled Beast (interval default 125 ms via
  `--net-beast-reduce-interval`); messages are normal Beast frames, compatible with any
  Beast receiver.
- The `uuid=` parameter is a valid position in any `--net-connector` list
  (`any position in the comma separated list can also be either silent_fail or uuid=<uuid>`
  per `--help`).
- If `uuid=` is absent, readsb falls back to the UUID in `--uuid-file=<path>`. If neither
  is present, **no UUID is sent**.
- `beast_reduce_out` (non-plus) never sends a UUID — always use the `_plus_` variant.

**Hub side** (verified: same README section + `--help`):

- The aggregator enables `--net-receiver-id` ("forward receiver ID") and `--net-ingest`
  ("primary ingest node") — the README states this combination "is made to work with
  beast_reduce_plus_out".
- `--net-garbage=<ports>` exists for "timeout receivers, output messages from timed out
  receivers as beast on <ports>" — candidate for detecting silent feeders later.
- `--receiver-focus=<receiverId>` allows debugging a single receiver's stream.

**How readsb identifies receivers internally** (verified: `receiver.c`, `net_io.c`):

- The hub derives a `receiverId` (uint64) by hashing the UUID string sent by the feeder
  (`fasthash64(proxy_string)` in `net_io.c`); connections without a UUID get a random
  receiverId that is *not* stable across reconnects.
- Receiver table entries time out after 24 h idle (or 20 min under table pressure;
  `receiver.c::receiverTimeout`) — our stats worker must treat `last_seen` accordingly.

**Per-receiver stats exposure** (verified: `receiver.c::generateReceiversJson`,
`readsb.c` line 2992):

- With `--write-receiver-id-json`, the hub writes `receivers.json` into the JSON dir
  every `--write-json-every` interval. Each entry is:

  ```
  [ "uuid", positions_per_sec, timeouts_per_hour,
    latMin, latMax, lonMin, lonMax, badExtent(0/1),
    latCenter, lonCenter ]
  ```

  Source: `receiver.c` lines 367–419. This is the primary machine-readable per-receiver
  feed for the phase 3 stats worker. NOTE: `positions_per_sec` is a rate averaged over
  the receiver's lifetime (`positionCounter / elapsed`) — the worker must accumulate
  deltas, not absolute values, to avoid double counting across restarts.
- Receiver *message* counts are not in `receivers.json`, only position counts and the
  lat/lon extent box. Message-level per-receiver counts would need `--net-garbage` /
  prometheus output investigation in phase 3 (TODO(phase-3)).
- readsb also writes `receiver.json` (singular, its own location) and supports
  `--write-prom=<file>` for prometheus metrics.

## 2. Ports conventionally used by community networks

Verified from adsb.lol production k8s manifests (`adsblol/infra`,
`bases/readsb/base/readsb.yaml`, `bases/mlat-server/base/mlat-server.yaml`) and the
sdr-enthusiasts ultrafeeder README:

| Port | Use | Source |
| --- | --- | --- |
| 30004 | Beast input at the aggregator (feeders connect *out* to it with `beast_reduce_plus_out`) | readsb README examples; adsb.lol `adsb-in` containerPort |
| 30005 | Beast output (hub → consumers) | adsb.lol `adsb-out`; readsb convention |
| 30006 | Beast output (secondary, adsb.lol uses for raw-ish out) | adsb.lol `adsb-out-r` |
| 30105 | MLAT results into readsb hub (adsb.lol sets `MLATPORT=30105` on the readsb container) | adsb.lol readsb.yaml env |
| 31090 | mlat-server client listen (standard mlat-client connects here) | adsb.lol mlat.yaml `--client-listen=31090`; ultrafeeder README example `mlat,in.adsb.lol,31090` |
| 30104 | mlat-server → hub Basestation-format results (`--filtered-basestation-listen=30104`) | adsb.lol mlat.yaml |
| 30152 | readsb HTTP API (`--net-api-port`) | adsb.lol `http-api` |
| 8080 | tar1090 web (we choose; adsb.lol serves via nginx on 80) | our config |

We will adopt 30004 / 30005 / 31090 as feeder-facing ports; everything else is internal
to the Compose network and configurable via `.env`.

## 3. MLAT server facts (wiedehopf fork)

Verified: `mlat-server/README.md`, `mlat/main.py` argument definitions:

- License: **AGPL v3** (README "License" section, confirmed in `COPYING`). Operating it
  as a network service obliges us to offer source of modifications to the *users of the
  server* (i.e. feeders). The server sends an AGPL notice + source URL to each client;
  that URL is configured in `mlat/config.py` — we must update it to our public patch repo.
- Key flags: `--client-listen [host:]tcp_port[:udp_port]` (required),
  `--basestation-connect/--basestation-listen`, `--filtered-basestation-connect/--listen`
  (Basestation-format results out), `--work-dir` (required; debug/stats output and
  blacklist), `--motd`, `--partition n/count`, `--write-csv`.
- Results are returned to contributing clients automatically ("Results get passed back to
  the clients that contributed to the positions", README §Output). This is the mechanism
  that returns MLAT positions to feeders' local readsb (feeders enable `--forward-mlat`
  or ultrafeeder auto-integrates return data — ultrafeeder README: "any MLAT return data
  from the MLAT Server will automatically be integrated").
- adsb.lol runs `ghcr.io/katlol/mlat-server` (a fork of the same codebase) with
  `PYTHONOPTIMIZE=2` and thread-limit env (`MKL_NUM_THREADS=1` etc.) — useful operational
  hints.
- Python deps for the wiedehopf fork: numpy, scipy, pykalman, python-graph-core, uvloop,
  ujson, Cython (setup.py build_ext), plus gcc to compile. Python 3.4+ per README.

## 4. tar1090 facts

Verified: tar1090 `README.md`, `TAR1090-INFO.md` (404 on master — the info wiki moved to
the adsb-wiki), readsb README "Saving traces" section:

- tar1090 is a static HTML/JS app served by any webserver; it reads readsb's JSON output
  dir (`/tar1090/data`), optionally globe history (`/tar1090/globe_history`) and the
  readsb HTTP API (`/tar1090/re-api` proxy to `--net-api-port`, only with
  `--write-json-globe-index` + `--tar1090-use-api`).
- Hub aggregation setup per readsb README: `--write-globe-history <dir>` + `--heatmap 30`
  + `--write-json-globe-index` + `--db-file aircraft.csv.gz` (from
  `wiedehopf/tar1090-db` csv branch).
- For a small network (< 500 concurrent aircraft) `--write-json-globe-index` is not
  required — start without it in phase 1 (decision deferred to phase 1 demo).

## 5. Ultrafeeder config syntax (feeder install path, phase 5)

Verified: sdr-enthusiasts/docker-adsb-ultrafeeder README (main branch):

```yaml
- ULTRAFEEDER_CONFIG=adsb,<host>,<port>,beast_reduce_plus_out,uuid=<UUID>
- ULTRAFEEDER_CONFIG=mlat,<host>,31090,uuid=<UUID>
```

- MLAT return data is auto-integrated by ultrafeeder (no extra config).
- `ULTRAFEEDER_CONFIG` strings cannot contain `;` or `,` inside values (e.g. in UUIDs —
  not an issue since UUIDs have no commas).
- Legacy `READSB_NET_CONNECTOR` / `MLAT_NET_CONNECTOR` still work; we document only the
  modern `ULTRAFEEDER_CONFIG` form.

## 6. Licenses and what they oblige us to publish

| Component | License (verified) | Source file | Obligation for WellClear |
| --- | --- | --- | --- |
| readsb | GPL v3 or later | `LICENSE` ("licensed under the GPL, v3 or any later version") | If we distribute modified readsb, publish source. Running unmodified via pinned upstream image/commit: attribution + comply when distributing containers. Config files are ours. |
| tar1090 | GPL v2 or later | `LICENSE` ("GPL, v2 or later") | Same pattern as readsb. |
| mlat-server (wiedehopf fork of mutability) | **AGPL v3** | `README.md` §License, `COPYING` | **Any patch we run must be offered in source to our users (feeders).** Keep patches in a public repo from the first commit and point `mlat/config.py` URL at it. |
| docker-adsb-ultrafeeder | GPL v3 | `LICENSE` | We only ship config lines, no distribution issue. |
| adsblol/infra | BSD-style, © 2023 Katia Esposito | `LICENSE` | Permissive; study/reuse with attribution. Do **not** copy code from any private repo of other networks. |

Consequence (per plan): the repo split is `wellclear` (private: api, worker, portal) plus a
public `wellclear-infra` mirror of everything that builds/runs GPL/AGPL components
(Dockerfiles, patches, compose for the GPL services). To be created before the mlat-server
Dockerfile lands its first patch — TODO(kyle): create the public repo; until then the
`infra/mlat-server` directory contains only unmodified upstream builds.

## 7. Deviations from the plan

- The plan said mlat-server is "believed to be AGPL" — confirmed AGPL v3, including the
  `mlat/config.py` client-notice mechanism.
- The plan guessed "`--net-receiver-id` or equivalent" — confirmed exact flags:
  `--net-receiver-id` + `--net-ingest` on the hub, `uuid=` on feeder connectors.
- adsb.lol runs a *fork* of mlat-server (`katlol/mlat-server`) in production, not the
  wiedehopf fork directly. We start with wiedehopf's fork (upstream of that fork family);
  revisit if we need their patches.
- `TAR1090-INFO.md` referenced in some guides no longer exists in the tar1090 repo;
  current documentation lives in the repo README + wiedehopf/adsb-wiki.

## 8. Build-time findings (phase 0, learned while building the images)

- readsb from source needs `pkg-config`, `libzstd-dev` and `libncurses-dev` (README's
  Debian-package dep list is accurate; threadpool.h includes zstd.h unconditionally,
  and the ncurses detection goes through pkg-config). The runtime image needs
  `libncurses6 libzstd1 zlib1g`.
- mlat-server: `python:3.12-slim` no longer ships setuptools, and setuptools >= 81 has
  removed `pkg_resources`, which `python-graph-core`'s `pygraph` imports at *runtime*
  (`pygraph/mixins/__init__.py`). Runtime requirement: `"setuptools<81"`. Logged as an
  upstream-compat note; if pygraph ever fixes this we can drop the pin.
- `docker compose up --wait` verified healthy: db, api, worker, readsb-hub, tar1090;
  mlat-server starts and listens on 31090.
- Hub `receivers.json` confirmed written with `--write-receiver-id-json` (empty `receivers: []`
  until feeders connect) — stats-worker plumbing is live end to end.

## 9. Beast/DF17 wire-format facts (verified the hard way, phase 1)

While building tools/fake-feeder we validated our DF17 encoder against pyModeS v2
(battle-tested decoder) and readsb source. Facts below were each confirmed after
producing real mis-decodes:

- **Parity**: DF17 uses plain parity = CRC(payload) (full-frame syndrome 0). readsb
  reads the DF17 address from payload bits 9-32 and expects syndrome 0; the
  "syndrome = sender ICAO" rule applies to Mode-S surveillance DFs (0/4/5/16/20/21),
  NOT DF17 (readsb mode_s.c). Canonical vector 8D406B902015A678D4D220AA4BDA confirms:
  its parity = CRC(payload) exactly.
- **CRC**: readsb crc.c::modesChecksum — byte-wise over the first n-3 bytes (table
  lookup, poly 0xFFF409), then the last 3 bytes (parity) XORed in raw. Do NOT use a
  naive bit-by-bit over all 112 bits (different result).
- **Airborne position ME layout (BDS 0,5)** — 56 bits, no spare bit:
  `TC 1-5 | SS 6-7 | NICsb 8 | ALT 9-20 (12b, Q=1 → 25 ft) | T 21 | F 22 | LAT 23-39 |
  LON 40-56`. The T (UTC-sync) flag at bit 21 is easy to miss; LON extends to the last
  bit (readsb mode_s.c::decodeESAirbornePosition).
- **CPR encode zones**: even frame longitude uses NL(lat) zones, odd uses NL(lat) − 1.
  Using NL(lat − dlat/2) as some references suggest produces wrong longitudes near NL
  zone boundaries (verified: 2000/2000 worldwide round-trips through pyModeS v2 global
  decode with NL(lat) / NL(lat)−1).
- **UUID handshake on beast connections** (readsb net_io.c::read_uuid): client sends
  `0x1a 0xe4` + ASCII UUID (dashes ignored) any time before the receiverId locks;
  hub derives the stable receiverId from the FIRST 16 hex digits — UUIDs that differ
  only in later digits collide into one receiver.
- **Feeders connect to readsb's --net-bi-port, NOT --net-bo-port.** readsb has separate
  services: `net-bi-port` = Beast TCP input (`READ_MODE_BEAST`/`decodeBinMessage`);
  `net-bo-port` = a beast OUTPUT server (`READ_MODE_BEAST_COMMAND`) that accepts
  connections but ignores incoming data (readsb net_io.c lines 962/1072). Symptom if
  wrong: TCP connects fine, zero messages, no disconnects. readsb's own macOS example
  uses `--net-bi-port 30004,30104`, matching community convention (adsb.lol exposes
  30004 as adsb-in). Hub config: `--net-bi-port=30004,30104`, `--net-bo-port=30005`.
- pyModeS v3 rescales CPR fields oddly (reports cpr values ×2 vs the 17-bit wire
  values) — use pyModeS<3 for validation work.

## 10. MLAT facts (phase 2, verified)

- **MLAT results into the hub**: mlat-server `--filtered-basestation-connect` emits
  SBS with current timestamps; readsb's `--net-sbs-in-port=<port ending in 6>`
  automatically opens the MLAT SBS input on `<port+1>` (verified net_io.c lines
  1025-1040: last digit 6→7; prio →8, jaero →9). We use `--net-sbs-in-port=30106`
  (hub) + mlat-server → `readsb-hub:30107`. Positions ingested there get
  `SOURCE_MLAT` and appear on tar1090 flagged **mlat** (verified end-to-end by SBS
  injection: hub aircraft.json shows `"type": "mlat"` with decoded lat/lon).
- **readsb validates SBS timestamps**: messages with sysTimestamp outside
  now+1s / now−20min are inhibited (decodeSbsLine) — mlat-server sends current
  receive timestamps so this is fine; beware in tests with hardcoded timestamps.
- **SBS field positions matter**: fields 11-16 are callsign, altitude, speed,
  track, lat, lon (mlat-server output.py TEMPLATE matches; a hand-written test
  line misaligned by one field silently produces no position).
- **mlat-client** (wiedehopf fork, pinned `28ae4f74…`): `--input-connect host:port`
  (12 MHz beast), `--server host:port`, `--user`, `--lat/--lon/--alt`, `--uuid`.
  Results returned automatically to contributing clients; ultrafeeder
  auto-integrates return data (phase 5 install path). Needs `setuptools` +
  `pyasyncore` on Python 3.12 (asyncore was removed from stdlib).
- **mlat-client's beast parser is strict** (modes_reader.c): wrong frame types
  (e.g. a 7-byte payload sent as type '3') cause "Lost sync" fatal errors and
  reconnect loops — unlike readsb which silently resyncs. Our DF11 frames must go
  out as type '2'.
- **AGPL note (§6)**: mlat-server sends each client the AGPL notice + source URL
  (observed in client logs); when we patch mlat-server, the URL in
  `mlat/config.py` must point at our public repo.
- **Multilateration dof**: filtered basestation output suppresses positions while
  the Kalman state is invalid (`dof < 1`), i.e. fewer than 5 receivers per solve
  (tracker/coordinator source). We run 5 fake feeders so the path is testable;
  production will have far more.
- **Phase 2 status**: clients connect, server reports "5 clients 0 bad sync",
  per-client sync state visible (coordinator Status lines + workdir
  clients.json/sync.json + client-side status). The server does NOT yet compute
  MLAT positions from our synthetic cross-feeder streams — the simulators' emit
  loops are independent, so identical transmissions arrive spread over ~100 ms and
  clock-sync group matching doesn't form. **Full MLAT validation is deferred to
  phase 5 with real feeders**, as the plan anticipates. Every infrastructure hop
  (client→server, server→hub SBS-MLAT, hub→map flagged mlat) is verified working.

## 11. Phase 3 design facts

- **readsb's clients.json lists ALL input-service clients**, including the mlat-server's
  own basestation feed (a connection with no uuid and no data). The worker therefore
  registers only receivers that have feed data or an mlat-client entry — otherwise the
  MLAT pipeline itself shows up as a phantom receiver.
- **Accounting model**: per-receiver hourly stats are incremented via deltas of hub
  cumulative counters (`positions_cum` exact; messages estimated as avg rate × conn
  time — readsb exposes no per-receiver cumulative message count). Last-observed state
  lives in `worker_stats_state`, which the worker loads at startup: a worker restart
  resumes counting exactly (no double counting, verified by the integration test).
  A hub restart resets hub-side cumulative counters; the reconnect branch counts the
  new connection's totals as fresh (the old connection's unpolled tail is lost, ≤1
  interval — small and documented).
- **Per-receiver aircraft_seen / coverage attribution is approximate**: receivers.json
  exposes only each receiver's decoded-position extent box (latMin/latMax/lonMin/
  lonMax), so the worker attributes sampled positions to receivers whose box contains
  them. True per-receiver attribution would need readsb's globe-index trace data —
  revisit if revenue-share scoring needs exactness (TODO(phase-5)).
- **max_range_km** = great-circle distance from the receiver's mlat-reported position
  to the farthest corner of its extent box (readsb has no per-receiver range metric).
- **mlat_synced_s** counts intervals where the receiver's mlat-client reports
  `peer_count > 0 and bad_sync_timeout == 0` (all zero until real clock sync exists,
  see §10).
- **Registry**: receivers auto-register by UUID on first sight; `tier` defaults to
  `community`; exact coordinates come from the feeder's mlat-client lat/lon and are
  stored in `lat_exact/lon_exact` (owner-only) with rounded public mirrors. The API's
  public status endpoint returns only a sha256-derived short hash, never the UUID.
- The hub's own healthchecks (TCP dials to 30004) do not create phantom receivers
  (no data, filtered) — verified after initially suspecting them.

## 12. Phase 4 design facts

- **Feeder source IPs** come from hub `clients.json` (readsb reports the peer host).
  Stored in `receiver_ips`, used only for the claim flow, dropped after
  `IP_RETENTION_HOURS` (24h default) by the worker. Docker Desktop quirk: host
  requests to published ports arrive at the API with the host's egress IP, which for
  a feeder on the same machine equals its feed IP — the IP-match claim flow therefore
  works in the dev demo. Real remote feeders can't IP-match (their feed IP ≠ browser
  IP), so there is an admin force-claim endpoint (`POST /v1/admin/receivers/{uuid}/claim`)
  for beta onboarding by hand — the plan's phase 5 runbook task.
- **Claim flow**: magic-link login → portal shows claim candidates for the visitor IP
  (10-minute freshness window per plan) → claim POST must originate from the
  feeder's IP. Records `receiver_claims(method='ip')` and emits a claim event.
- **Magic links**: `login_tokens` one-time tokens; account creation records
  community-terms acceptance in `feeder_agreements` (idempotent backfill at login for
  accounts created before phase 4). Dev mode (`MAIL_MODE=dev`) returns the link in
  the API response; SMTP delivery is a production TODO.
- **Public location precision** is a config switch: `PUBLIC_COORD_PRECISION`
  (default 2 decimals ≈ 1.1 km) — Kyle's open decision, never hard-coded.
  `map_visible=false` (owner setting) hides the public location entirely.
- **Privacy verified by test**: owner view exposes `location_exact`; the hash-keyed
  public view never returns the UUID or exact coords; other users' sessions get 401/403
  on owner endpoints.
- **Portal** is static HTML/JS served by the API at `/portal` (mounted volume), no
  build step, no third-party scripts. Terms text is `portal/terms.html` — placeholder,
  Kyle to write (version via `COMMUNITY_TERMS_VERSION`).
- Gotcha recorded: a FastAPI cookie set on the injected `response` parameter is lost
  if you return a different Response object — set cookies on the returned response.

## 13. Phase 5 install-path facts (verified live)

- **ultrafeeder mlat-client requires the standalone `UUID` env** — the sdr-enthusiasts
  image's s6 script aborts with "either UUID or MLAT_USER must be defined" even when
  the mlat construct carries `uuid=` (verified in the image's
  `/etc/s6-overlay/scripts/mlat-client`). Our documented config therefore sets both.
- The image rejects plain `LAT/LON` for the mlat location ("READSB_LON or LONG must be
  defined") — use `READSB_LAT`/`READSB_LON`.
- Live confirmation of the SBS-MLAT 6→7 rule in the wild: the SDR-E image's own readsb
  logged "32007: SBS TCP input MLAT port" next to `--net-sbs-in-port=32006`.
- **Plain readsb path live-tested**: readsb with
  `--net-connector <src>,beast_in` + `--net-connector <hub>,30004,beast_reduce_plus_out,uuid=…`
  + a separate pinned mlat-client — both feeds registered on hub and mlat-server.
- **install.sh tested** in a Debian container with a stubbed systemctl: 10/10
  assertions (idempotency, UUID reuse, exact-once connector appended inside
  NET_OPTIONS, existing options preserved, dry-run changes nothing, mlat unit
  correct). Note: the script needs root and touches only /etc/default/readsb,
  /var/lib/wellclear-feeder/uuid and the wellclear-mlat-client unit.
- Raspberry Pi OS hardware test: not available in this environment — the install.sh
  path is functionally identical to a Pi (Debian + systemd); recommend Kyle runs it
  once on a real Pi during beta.

## Open verify-first questions carried into later phases

- [ ] phase 1: exact hub readsb flag set for globe history volume layout and tar1090
      integration (verify against current README at build time).
- [ ] phase 3: per-receiver *message* counts (receivers.json only exposes position
      rates + extent) — investigate readsb prometheus output or `--net-garbage` stats.
- [ ] phase 3: mlat-server per-client sync state exposure (there is stats output under
      `--work-dir`; verify format when we get there).
- [ ] phase 5: whether Cloudflare Spectrum or plain TCP via VPS for feeder-facing ports.

## 14. Product name

- The working title **AVData is now WellClear**; domain registered: `wellclear.aero`
  (2026-10). Hostname plan: `feed.` (ingest, never moved), bare/www (portal+API),
  `map.` (tar1090). Everything was already env-config-driven, so this was a pure
  rename pass (packages, images, container names, docs, portal).
- The plan file at repo root still says "AVData" — it's the historical plan of record;
  WellClear = the product, AVData = the working title.

## 15. Production architecture decisions (AWS)

- **Product**: WellClear (wellclear.aero) — renamed from AVData; §14.
- **Provider**: AWS ca-central-1 (startup credits). Same Montreal market as the
  OVH-BHS alternative; credits neutralize the cost delta. Single EC2
  (t3.xlarge, 200 GB gp3) + Compose; the two-tier split stays a documented seam.
- **DB: RDS Postgres (vanilla), NOT Timescale** — decisive analysis:
  we never store raw messages in Postgres (the high-volume time series is
  globe-history → S3). Hourly aggregates are ~90k rows/year at 10 feeders —
  hypertables added nothing at that scale, and RDS has no Timescale option.
  Vanilla PG keeps the ops surface managed by AWS and covered by credits.
  Migration 0001 REWRITTEN (dev DBs were discarded in the rename; no applied
  prod envs existed) to drop `create_hypertable`/compression/retention.
  Retention (2y) is now a worker-side hourly DELETE; compression unnecessary at
  this scale. If raw MLAT/track data ever enters the DB, revisit Timescale —
  via managed TigerData, not self-hosting.
- **Analytics: S3 Tables (Iceberg)** — `aws_s3tables_table_bucket` provisioned;
  raw traces in /raw/YYYY/MM/DD/ stay canonical; Iceberg tables get created
  when the coverage-scoring pipeline work starts. VERIFY-FIRST: aws_s3tables_*
  resources need AWS provider ≥ 5.90 — pin exact version at deploy time.
- **Web edge: Caddy (Let's Encrypt) on the box, NOT CloudFront/ALB** — the EIP
  is public anyway (feed. record for raw feeder TCP), so hiding it buys
  nothing; Caddy adds one container and zero AWS moving parts. CloudFront/WAF
  is the documented upgrade if DDoS/abuse becomes real.
- **Log rotation in prod overlay** (json-file max 50m × 5) — the one true
  append-log risk we verified. Vector/Loki/Grafana planned for observability;
  deferred until invitations are close (not in this kit yet).
- **Secrets**: SSM SecureString (/wellclear/prod/*) written by Terraform,
  read by user_data bootstrap into infra/.env on the box. GitHub PAT included
  (bootstrap clone of the private repo).
- **wellclear-infra public repo**: sync script included
  (deploy/wellclear-infra-sync.sh, manual push). Trigger: any patch to
  mlat-server must land there BEFORE running in prod, with the client-facing
  source URL updated in mlat/config.py. Currently we run unmodified upstream,
  so nothing is owed yet — but the repo must exist before first prod deploy.
- **Cost**: ~$200/mo with credits; post-credits lean path documented in
  RUNBOOK-DEPLOY (~$90/mo: t3.large + no CloudFront + aggressive S3 tiering).
