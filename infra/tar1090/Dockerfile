# tar1090 network map (phase 0: static shell; hub data wiring verified in phase 1).
# Serves tar1090's html from the pinned upstream commit, with readsb's JSON output
# volume mounted at /data (tar1090 expects /tar1090/data — mapped via nginx config).
FROM nginx:1.27-alpine

# Pin: wiedehopf/tar1090 (docs/DECISIONS.md). GPL v2+; we serve unmodified upstream.
ADD https://github.com/wiedehopf/tar1090/archive/e784ee5ae82948f41efe3ef5c235ade0943ab8ff.tar.gz /tmp/tar1090.tar.gz

RUN tar -xzf /tmp/tar1090.tar.gz -C /tmp \
    && mkdir -p /usr/share/nginx/html/tar1090 \
    && cp -r /tmp/tar1090-*/html/. /usr/share/nginx/html/tar1090/ \
    && rm -rf /tmp/tar1090*

COPY nginx.conf /etc/nginx/conf.d/default.conf
