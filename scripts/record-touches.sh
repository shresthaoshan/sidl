#!/bin/sh
# Records real trackpad frames into a test fixture.
# Usage: scripts/record-touches.sh <name>   (for example: left-edge-swipe)
#
# Quits a running Sidl, then runs Sidl.app with recording on, until you press Control-C.
# Sidl still runs the gestures' actions while it records. Run scripts/bundle.sh first.
set -eu
cd "$(dirname "$0")/.."
name="${1:?usage: scripts/record-touches.sh <name>}"
out="Tests/SidlTests/Fixtures/$name.csv"
mkdir -p Tests/SidlTests/Fixtures
pkill -x Sidl || true
echo "Recording to $out. Press Control-C to stop."
SIDL_RECORD="$PWD/$out" Sidl.app/Contents/MacOS/Sidl &
sidl=$!
# Stop Sidl on Control-C, then report. The script stops it, so this works when Sidl ignores the signal too.
trap 'kill "$sidl" 2>/dev/null' INT TERM
wait "$sidl" || true
echo
echo "Saved $out ($(($(wc -l < "$out") - 1)) lines). Run: open Sidl.app"
