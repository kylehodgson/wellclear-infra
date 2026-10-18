#!/bin/sh
# WellClear deviation (this repo's README): Remote ID aircraft (hex prefix
# 'FF', the rid2all convention) render as a quadcopter with the Q-code
# mapping — applied to tar1090's html at build time.
#
# Uses the files in this directory:
#   multicopter-shape.js   inserted into markers.js (shape definition)
#   planeobject-insert.js  inserted into planeObject.js (FF -> Q4 type)
#   sprites.png            regenerated atlas (shape inserted before 'uav'
#                          shifts sprite ids; the static atlas must match —
#                          regenerated with tar1090's own iconTest generator)
# POSIX sh + sed: must run on BusyBox (nginx:alpine build image).
set -eu
HTML="$1"
PATCHDIR="$(cd "$(dirname "$0")" && pwd)"

insert_before() { # $1=file $2=regex $3=insert-file
    n=$(grep -n -m1 -E "$2" "$1" | cut -d: -f1)
    [ -n "$n" ] || { echo "rid-marker patch: anchor '$2' not found in $1"; exit 1; }
    head -n $((n - 1)) "$1" > "$1.tmp"
    cat "$3" >> "$1.tmp"
    tail -n "+$n" "$1" >> "$1.tmp"
    mv "$1.tmp" "$1"
}
insert_after() { # $1=file $2=regex $3=insert-file
    n=$(grep -n -m1 -E "$2" "$1" | cut -d: -f1)
    [ -n "$n" ] || { echo "rid-marker patch: anchor '$2' not found in $1"; exit 1; }
    head -n "$n" "$1" > "$1.tmp"
    cat "$3" >> "$1.tmp"
    tail -n "+$((n + 1))" "$1" >> "$1.tmp"
    mv "$1.tmp" "$1"
}

# 1. markers.js: insert the multicopter shape before 'uav'
insert_before "$HTML/markers.js" "^    'uav': \{" "$PATCHDIR/multicopter-shape.js"

# 2. markers.js: remap the Eurocontrol UAS type codes (Q1/Q4/Q9/Q25) from
#    tar1090's stock fixed-wing 'uav' silhouette to the multicopter
sed -E "s/'(Q1|Q4|Q9|Q25)': \['uav', 1\],/'\1': ['multicopter', 1],/" \
    "$HTML/markers.js" > "$HTML/markers.js.tmp" && mv "$HTML/markers.js.tmp" "$HTML/markers.js"

# 3. planeObject.js: FF-prefix -> Q4 (insert after the squawk-7777 TWR case)
insert_after "$HTML/planeObject.js" "icaoType = 'TWR';" "$PATCHDIR/planeobject-insert.js"

# 4. sprite atlas: shipped pre-regenerated (static WebGL texture must match
#    the new shape list)
cp "$PATCHDIR/sprites.png" "$HTML/images/sprites.png"

# sanity: all edits present
grep -q "multicopter" "$HTML/markers.js" || { echo "rid-marker patch failed (markers.js)"; exit 1; }
grep -q "'Q4': \['multicopter', 1\]," "$HTML/markers.js" || { echo "rid-marker patch failed (Q remap)"; exit 1; }
grep -q "'FF'" "$HTML/planeObject.js" || { echo "rid-marker patch failed (planeObject.js)"; exit 1; }
cmp -s "$PATCHDIR/sprites.png" "$HTML/images/sprites.png" || { echo "sprites.png copy failed"; exit 1; }
echo "rid-marker patch applied"
