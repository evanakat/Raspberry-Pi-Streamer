#!/usr/bin/env bash
# Pi Streamer installer. Run on a fresh Raspberry Pi OS Lite (64-bit) install:
#   sudo ./install.sh
# Safe to run again; each step checks whether it is already done.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo ./install.sh" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-${TARGET_USER:-pi}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
APP_DIR=/opt/pi-streamer
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

step() { printf '\n==> %s\n' "$*"; }

step "Installing packages"
apt-get update
apt-get install -y --no-install-recommends cage v4l-utils python3 python3-evdev fonts-dejavu-core
apt-get install -y chromium || apt-get install -y chromium-browser
# Widevine lets Chromium play DRM-protected streams such as ESPN's.
apt-get install -y libwidevinecdm0 || echo "Warning: libwidevinecdm0 not available; protected streams may not play." >&2

step "Copying files to $APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$SRC_DIR/system" "$SRC_DIR/menu" "$APP_DIR/"
chmod +x "$APP_DIR"/system/*.sh "$APP_DIR"/system/*.py "$APP_DIR"/system/pi-streamer-reload
mkdir -p "$APP_DIR/menu/generated"
chown "$TARGET_USER:$TARGET_USER" "$APP_DIR/menu/generated"
ln -sf "$APP_DIR/system/pi-streamer-reload" /usr/local/bin/pi-streamer-reload

step "Installing the editable site list"
mkdir -p /etc/pi-streamer
if [ -f /etc/pi-streamer/sites.json ]; then
  echo "Keeping your existing /etc/pi-streamer/sites.json"
else
  install -m 644 "$SRC_DIR/config/sites.json" /etc/pi-streamer/sites.json
fi

step "Giving $TARGET_USER access to the display and input devices"
usermod -aG video,render,input "$TARGET_USER"

step "Enabling console auto-login"
if command -v raspi-config >/dev/null; then
  raspi-config nonint do_boot_behaviour B2
else
  echo "raspi-config not found; set up auto-login on tty1 yourself." >&2
fi

step "Forcing 1080p60 on HDMI"
CMDLINE=/boot/firmware/cmdline.txt
[ -f "$CMDLINE" ] || CMDLINE=/boot/cmdline.txt
if ! grep -q 'video=HDMI-A-1' "$CMDLINE"; then
  sed -i '1 s/$/ video=HDMI-A-1:1920x1080M@60/' "$CMDLINE"
fi

step "Enabling the HDMI-CEC service (TV power and remote)"
install -m 644 "$SRC_DIR/system/pi-streamer-cec.service" /etc/systemd/system/
install -m 644 "$SRC_DIR/system/pi-streamer-remote.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable pi-streamer-cec.service pi-streamer-remote.service

step "Starting the menu automatically on login"
PROFILE="$TARGET_HOME/.bash_profile"
MARK="# pi-streamer kiosk"
if ! grep -q "$MARK" "$PROFILE" 2>/dev/null; then
  cat >> "$PROFILE" <<'EOF'

# pi-streamer kiosk
# Only on the physical console (tty1), so SSH logins are unaffected.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  while true; do
    /opt/pi-streamer/system/kiosk.sh
    sleep 2   # restart the menu if the browser ever exits or crashes
  done
fi
EOF
  chown "$TARGET_USER:$TARGET_USER" "$PROFILE"
fi

step "Done"
echo "Reboot to start Pi Streamer: sudo reboot"
