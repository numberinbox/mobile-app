#!/usr/bin/env bash
# Capture an iOS simulator screen as a store-valid PNG.
#
# Runs on the host, not on the device: `xcrun simctl` only exists on macOS, so
# screenshot capture must happen here while integration_test/store_capture
# drives the app on the simulator.
#
# Usage: ./docs/store/screenshots/capture-ios.sh <output.png> [udid]
#        with the booted device as default:
#          ./docs/store/screenshots/capture-ios.sh shot.png

set -euo pipefail

OUT="${1:?usage: capture-ios.sh <output.png> [udid]}"
UDID="${2:-${STORE_CAPTURE_UDID:-}}"

if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices booted -j \
    | python3 -c 'import json,sys
d = json.load(sys.stdin)["devices"]
booted = [x["udid"] for v in d.values() for x in v if x.get("state") == "Booted"]
print(booted[0] if booted else "")')
fi

if [ -z "$UDID" ]; then
  echo "ERROR: no booted simulator; pass a udid or boot one first" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
xcrun simctl io "$UDID" screenshot --type=png "$OUT"

WIDTH=$(sips -g pixelWidth "$OUT" | awk '/pixelWidth/{print $2}')
HEIGHT=$(sips -g pixelHeight "$OUT" | awk '/pixelHeight/{print $2}')

echo "wrote $OUT (${WIDTH}x${HEIGHT}) from $UDID"

if [ "$WIDTH" -lt 320 ] || [ "$HEIGHT" -lt 320 ]; then
  echo "ERROR: smaller than the 320px minimum" >&2
  exit 1
fi

# App Store accepts 16:9 through 4:3 for the accepted device families.
if ! awk "BEGIN{exit !($WIDTH/$HEIGHT >= 0.5625 && $WIDTH/$HEIGHT <= 1.3334)}"; then
  echo "ERROR: aspect ratio $WIDTH/$HEIGHT is outside the accepted range" >&2
  exit 1
fi
