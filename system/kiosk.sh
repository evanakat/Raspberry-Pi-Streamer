#!/usr/bin/env bash
# Launches the full-screen menu: Chromium in kiosk mode inside the cage
# Wayland compositor. Started from ~/.bash_profile on tty1 after auto-login.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/pi-streamer}"
PROFILE_DIR="${HOME}/.config/pi-streamer-chromium"

BROWSER="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$BROWSER" ]; then
  echo "pi-streamer: Chromium is not installed" >&2
  exit 1
fi

# If Chromium was killed (power cut, crash), clear the "restore pages?" prompt.
PREFS="${PROFILE_DIR}/Default/Preferences"
if [ -f "$PREFS" ]; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]*"/"exit_type":"Normal"/' "$PREFS" || true
fi

# cage: -d no window decorations, -s allow switching to another console (Ctrl+Alt+F2).
exec cage -d -s -- "$BROWSER" \
  --kiosk \
  --ozone-platform=wayland \
  --user-data-dir="$PROFILE_DIR" \
  --no-first-run \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=Translate \
  --check-for-update-interval=31536000 \
  --autoplay-policy=no-user-gesture-required \
  --start-fullscreen \
  "file://${APP_DIR}/menu/index.html"
