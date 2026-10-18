# Feeding WellClear from a plain readsb install

Two changes: one net-connector line in readsb's config, plus an mlat-client
service. Nothing else on your system is touched.

## 1. readsb: add the feeder connector

Edit `/etc/default/readsb` and append our connector to the `NET_OPTIONS` value:

```
NET_OPTIONS="--net --net-ri-port 30001 --net-ro-port 30002 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005 --net-connector=<hub-host>,30004,beast_reduce_plus_out,uuid=<your-uuid>"
```

Flags verified against wiedehopf/readsb:

- `beast_reduce_plus_out` is the protocol aggregators expect; plain
  `beast_reduce_out` never sends your UUID.
- `uuid=` may sit anywhere in the connector list; if omitted, readsb falls back
  to `--uuid-file`. We pass it explicitly.
- Your existing outputs (other networks) keep working unchanged.

Then `sudo systemctl restart readsb`.

## 2. MLAT client (optional but recommended — you get MLAT positions back)

Install the wiedehopf mlat-client:

```sh
sudo apt install -y python3-pip python3-venv
sudo install -d -m 755 /usr/local/share/wellclear-mlat
sudo python3 -m venv /usr/local/share/wellclear-mlat/venv
sudo /usr/local/share/wellclear-mlat/venv/bin/pip install \
    "git+https://github.com/wiedehopf/mlat-client@28ae4f7409c9dfddd2bb8984baadce5d31fdc8e3"
```

Create `/etc/systemd/system/wellclear-mlat-client.service`:

```ini
[Unit]
Description=WellClear mlat-client
After=readsb.service network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/share/wellclear-mlat/venv/bin/mlat-client \
    --input-connect 127.0.0.1:30005 \
    --input-type dump1090 \
    --server <hub-host>:31090 \
    --user <your-uuid> \
    --uuid <your-uuid> \
    --lat <your-lat> --lon <your-lon> --alt <your-alt-m>
Restart=always

[Install]
WantedBy=multi-user.target
```

Then:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now wellclear-mlat-client
```

MLAT results are returned to your readsb automatically (mlat-client outputs
beast; add `--results beast,connect,127.0.0.1:30004` if you want them on your
own map via readsb's mlat-flagged input).

`feeder/install.sh` does all of the above for you; this page documents what it
changes so you can do it by hand.

## Status

- Connector args verified against wiedehopf/readsb at the pinned commit
  (see this repo's README).
- Live-tested against a real hub with a synthetic source (phase 5).