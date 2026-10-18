# Hub readsb: network-only aggregator (phase 1).
# Built from pinned upstream commit — see this repo's README.
# GPL v3: unmodified upstream build; config in this directory is ours.
FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
        git build-essential pkg-config zlib1g-dev libzstd-dev libncurses-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Pin: wiedehopf/readsb (this repo's README)
RUN git clone https://github.com/wiedehopf/readsb.git /src/readsb \
    && cd /src/readsb \
    && git checkout 094720939c01943de82b14df6f42f67fff1cd514 \
    && make -j"$(nproc)" RTLSDR=no

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash tini libncurses6 libzstd1 zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/readsb/readsb /usr/local/bin/readsb

# Aircraft metadata db (rolling csv, fetched at build; see this repo's README)
ADD https://github.com/wiedehopf/tar1090-db/raw/csv/aircraft.csv.gz /usr/local/share/aircraft.csv.gz

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Aggregator flags (verified: this repo's README) are set in entrypoint.sh.
ENTRYPOINT ["/entrypoint.sh"]
