# tar1090 network map (phase 0: static shell; hub data wiring verified in phase 1).
# Serves tar1090's html from the pinned upstream commit, with readsb's JSON output
# volume mounted at /data (tar1090 expects /tar1090/data — mapped via nginx config).
FROM nginx:1.27-alpine

# Pin: wiedehopf/tar1090 (this repo's README). GPL v2+; we serve upstream at
# the pinned commit plus two documented deviations (see patches/rid-marker.sh
# and this repo's README):
#   1. one injected badge link to our receiver map
#   2. Remote ID drone marker (FF-prefix hex -> multicopter shape, Q-code
#      remap, regenerated sprite atlas)
ADD https://github.com/wiedehopf/tar1090/archive/e784ee5ae82948f41efe3ef5c235ade0943ab8ff.tar.gz /tmp/tar1090.tar.gz
COPY patches /tmp/rid-patches

RUN tar -xzf /tmp/tar1090.tar.gz -C /tmp \
    && mkdir -p /usr/share/nginx/html/tar1090 \
    && cp -r /tmp/tar1090-*/html/. /usr/share/nginx/html/tar1090/ \
    && sed -i 's|</body>|<a href="https://map.wellclear.aero/receivers" style="position:absolute;bottom:64px;left:10px;z-index:100;font:12px/1.4 system-ui;padding:4px 10px;border:1px solid rgba(255,255,255,.35);border-radius:999px;background:rgba(0,0,0,.55);color:#eee;text-decoration:none" target="_blank">↗ Receiver map</a></body>|' /usr/share/nginx/html/tar1090/index.html \
    && /tmp/rid-patches/rid-marker.sh /usr/share/nginx/html/tar1090 \
    && rm -rf /tmp/tar1090* /tmp/rid-patches

COPY nginx.conf /etc/nginx/conf.d/default.conf
