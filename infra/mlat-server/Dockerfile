# mlat-server (wiedehopf fork), built from pinned upstream commit.
# AGPL v3: see this repo's README— any patch to this image MUST be published,
# and mlat/config.py's source URL must point at our public repo. Until we patch
# anything, this is an unmodified upstream build.
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git tini \
    && rm -rf /var/lib/apt/lists/*

# Pin: wiedehopf/mlat-server (this repo's README)
RUN git clone https://github.com/wiedehopf/mlat-server.git /opt/mlat-server \
    && cd /opt/mlat-server \
    && git checkout 9b27a6d609c5bb47549016412222a79ecb0f48e4 \
    && pip install --no-cache-dir numpy scipy pykalman python-graph-core uvloop ujson Cython "setuptools<81" \
    && python setup.py build_ext --inplace

WORKDIR /opt/mlat-server

# Thread limits per upstream/adsb.lol practice
ENV MKL_NUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1 \
    OMP_NUM_THREADS=1

RUN mkdir -p /run/mlat-server

ENTRYPOINT ["/usr/bin/tini", "--", "python3", "/opt/mlat-server/mlat-server"]
