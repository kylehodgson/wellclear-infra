# Contributing to wellclear-infra

wellclear-infra is the **public infrastructure mirror** of the
[WellClear](https://wellclear.aero) community flight-tracking network. Its
purpose is license compliance and public review: everything that builds or
runs GPL/AGPL-licensed community software (readsb, mlat-server, tar1090)
lives here, and feeder-facing documentation lives here so it's accessible
without a private-repo account.

Contributions are welcome — especially from feeders, since you're running
this stack in your own setup.

## What belongs here vs. what doesn't

| Belongs here | Doesn't |
|---|---|
| Dockerfiles, patches, compose files for the GPL/AGPL components (`infra/`) | API, stats worker, portal code (private `wellclear` repo) |
| Patches to GPL/AGPL software — **before** they deploy (see below) | Anything containing WellClear business logic or feeder identities |
| Feeder install docs and scripts (`feeder/`) | Private verification logs, credentials, internal runbooks |
| Upstream-fix PRs we intend to send back (e.g. the tar1090 marker patch) | Secrets of any kind — verify before committing |

The private `wellclear` repo is the system of record for internal decisions;
this repo mirrors the public-facing subset.

## The AGPL discipline (read before touching mlat-server)

`infra/mlat-server` runs **unmodified upstream** at a pinned SHA. The moment
we patch it:

1. The patch lands in `infra/mlat-server/patches/` and is committed here
   **before** the modified server deploys.
2. The client-facing source URL in `mlat/config.py` is updated to point at
   this repository.

If your PR touches `infra/mlat-server/`, the review will check both points.

## Verification discipline

Every pinned SHA, port, and flag here was verified against current upstream
source. If you change a pin, bump it deliberately and say in the PR what you
verified (the SHA matches what you built and ran). Pins are not bumped
casually.

## Dev workflow

Changes are tested on a live feeder host before merging where feasible:

- `infra/compose.yml` (local/dev) vs `infra/compose.prod.yml` — keep both
  in sync unless the change is intentionally dev-only; say so in the PR.
- The tar1090 deviations are applied at build time by
  `infra/tar1090/patches/rid-marker.sh`. After editing `multicopter-shape.js`
  or `planeobject-insert.js`, regenerate `sprites.png` via that script so the
  marker patch stays reproducible from source.
- `feeder/install.sh` assumes a fresh Raspberry Pi OS / Debian host; smoke-test
  it (or at least `shellcheck` it) after editing.

## Pull requests

- One logical change per PR.
- Feeder docs (`feeder/*.md`) are user-facing: prefer obvious placeholders
  (`YOUR-LONGITUDE`) over examples that look like real config.
- License headers/notes are part of the compliance surface — don't strip
  attribution comments from upstream-derived files.
- Upstream-bound fixes (wiedehopf's readsb/mlat-server/tar1090) should be
  noted in the PR so they can be tracked for the corresponding upstream PR.
