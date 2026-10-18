# feeder/

Feeder-side install paths — written and tested in **phase 5**, per the plan:

- `ultrafeeder.md` — exact `ULTRAFEEDER_CONFIG` line (syntax already verified,
  see `this repo's README` §5)
- `readsb.md` — exact `--net-connector` args for plain readsb installs
- `install.sh` — fallback feed script: adds a connector + mlat-client service,
  generates a UUID only if one doesn't exist, changes nothing else
