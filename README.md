# wellclear-infra

Public infrastructure repository for **WellClear** (wellclear.aero), a community
flight-tracking network. This repo exists to satisfy the license obligations of
the community software we run:

| Component | License | What we publish here |
|---|---|---|
| [readsb](https://github.com/wiedehopf/readsb) (hub, aggregator mode) | GPL v3+ | Dockerfile, entrypoint, pinned SHA (`094720939c01943de82b14df6f42f67fff1cd514`) |
| [mlat-server](https://github.com/wiedehopf/mlat-server) (wiedehopf fork) | **AGPL v3** | Dockerfile, pinned SHA (`9b27a6d609c5bb47549016412222a79ecb0f48e4`), and **any future patches** (`infra/mlat-server/patches/`) |
| [tar1090](https://github.com/wiedehopf/tar1090) (network map) | GPL v2+ | Dockerfile, nginx config, marker patch + regenerated sprite atlas, pinned SHA (`e784ee5ae82948f41efe3ef5c235ade0943ab8ff`) |

## AGPL note (why this repo exists)

mlat-server is AGPL v3: operating it as a network service requires offering the
source of any modifications to the service's users (our feeders). We currently
run **unmodified upstream** at the pinned SHAs above — the moment we patch it,
the patch lands here BEFORE it deploys, and the client-facing source URL in
`mlat/config.py` is updated to point at this repository.

## What is NOT here (by design)

The API, stats worker, and feeder portal are closed-source (they contain no
community-licensed code and are the private `wellclear` repository). Compose
files here include those service stanzas with a banner comment noting their
build contexts are not part of this repo — the GPL/AGGPL components build
standalone from their directories.

## Feeding WellClear

See `feeder/` — the install paths (ultrafeeder, plain readsb, install.sh) and
their documentation. Feeder-facing docs live here so they're publicly
accessible without access to the private repo.

## Verification discipline

Every pinned SHA, port, and flag in this repo was verified against current
upstream source before use. The full verification log lives in the private
repository; the compliance-relevant facts are documented here: the pinned
SHAs in the table above, the AGPL note, and the deviations below.

## Deviations from upstream

- **tar1090**: two build-time deviations, both applied by
  `infra/tar1090/patches/rid-marker.sh` from files in that directory:
  1. one link ("Receiver map" badge) is injected into `index.html`,
     pointing at our receiver map layer
  2. **Remote ID drone marker**: aircraft with a synthesized ICAO in the
     unassigned `FF` prefix (our Remote ID feeders use the rid2all
     convention) render as a quadcopter (`multicopter` shape added to
     `markers.js`, `FF`-prefix hex forced to type Q4 in `planeObject.js`,
     sprite atlas regenerated with tar1090's own iconTest generator — the
     static atlas must match the JS shape list).
- **mlat-server**: unmodified upstream at the pinned SHA. Any future patch
  must land in `infra/mlat-server/patches/` here BEFORE it deploys (AGPL),
  with the client-facing source URL in `mlat/config.py` updated to point
  at this repository.
