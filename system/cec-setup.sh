#!/usr/bin/env bash
# Registers the Pi on HDMI-CEC as a playback device, turns the TV on and
# switches the TV's input to the Pi. Once registered, the kernel turns TV
# remote button presses into keyboard events the menu can read.
set -uo pipefail

DEV="${CEC_DEVICE:-/dev/cec0}"   # /dev/cec0 = the HDMI port next to the USB-C power port
OSD_NAME="${CEC_OSD_NAME:-Pi Streamer}"

for _ in $(seq 1 30); do
  [ -e "$DEV" ] && break
  sleep 1
done
if [ ! -e "$DEV" ]; then
  echo "pi-streamer-cec: $DEV not found; is the TV on HDMI port 0?" >&2
  exit 0
fi

cec-ctl -d "$DEV" --playback --osd-name "$OSD_NAME" >/dev/null

# The TV may need a moment to report our physical address after hotplug.
PHYS=""
for _ in $(seq 1 10); do
  PHYS="$(cec-ctl -d "$DEV" | awk -F': *' '/Physical Address/ {print $2; exit}')"
  [ -n "$PHYS" ] && [ "$PHYS" != "f.f.f.f" ] && break
  sleep 1
done

# Wake the TV, then tell it to switch to our input.
cec-ctl -d "$DEV" --to 0 --image-view-on >/dev/null || true
if [ -n "$PHYS" ] && [ "$PHYS" != "f.f.f.f" ]; then
  cec-ctl -d "$DEV" --to 15 --active-source "phys-addr=$PHYS" >/dev/null || true
fi

echo "pi-streamer-cec: registered as '$OSD_NAME' at ${PHYS:-unknown address}"
