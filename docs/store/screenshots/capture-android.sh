#!/usr/bin/env bash
# Capture the Android emulator screen as a Play-valid 1080x1920 PNG.
#
# The emulator window is 1080x2400 (the Pixel 7 AVD's physical panel), so a
# window-level screenshot comes out 20:9 and Play rejects it. This grabs the
# guest framebuffer instead, which honours the "wm size 1080x1920" override.
#
# Usage: ./docs/store/screenshots/capture-android.sh <output.png>

set -euo pipefail

ADB="${ANDROID_ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
OUT="${1:?usage: capture-android.sh <output.png>}"

mkdir -p "$(dirname "$OUT")"
"$ADB" exec-out screencap -p > "$OUT"

WIDTH=$(sips -g pixelWidth "$OUT" | awk '/pixelWidth/{print $2}')
HEIGHT=$(sips -g pixelHeight "$OUT" | awk '/pixelHeight/{print $2}')

echo "wrote $OUT (${WIDTH}x${HEIGHT})"

# Play accepts an aspect ratio between 16:9 and 9:16 and rejects anything else.
if [ "$WIDTH" -lt 320 ] || [ "$HEIGHT" -lt 320 ]; then
  echo "ERROR: smaller than the 320px minimum" >&2
  exit 1
fi
if ! awk "BEGIN{exit !($WIDTH/$HEIGHT >= 0.5625 && $WIDTH/$HEIGHT <= 1.7778)}"; then
  echo "ERROR: aspect ratio $WIDTH/$HEIGHT is outside 16:9-9:16; re-apply 'adb shell wm size 1080x1920'" >&2
  exit 1
fi