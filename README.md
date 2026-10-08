# wellclear-infra

Public infrastructure repository for **WellClear** (wellclear.aero), a community
flight-tracking network. This repo exists to satisfy the license obligations of
the community software we run:

| Component | License | What we publish here |
|---|---|---|
| [readsb](https://github.com/wiedehopf/readsb) (hub, aggregator mode) | GPL v3+ | Dockerfile, entrypoint, pinned SHA (`094720939c01943de82b14df6f42f67fff1cd514`) |
| [mlat-server](https://github.com/wiedehopf/mlat-server) (wiedehopf fork) | **AGPL v3** | Dockerfile, pinned SHA (`9b27a6d609c5bb47549016412222a79ecb0f48e4`), and **any future patches** (`infra/mlat-server/patches/`) |
| [tar1090](https://github.com/wiedehopf/tar1090) (network map) | GPL v2+ | Dockerfile, nginx config, pinned SHA (`e784ee5ae82948f41efe3ef5c235ade0943ab8ff`) |

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
upstream source (see `docs/DECISIONS.md` — the full decision log is synced from
the private repo).
