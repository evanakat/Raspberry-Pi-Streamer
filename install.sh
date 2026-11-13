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
APP_DIR=/opt/pi-streamer
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }

step "Checking this machine"
if [ "$TARGET_USER" = "root" ]; then
  echo "Run this from your normal user with sudo (not as root), so the kiosk runs as that user." >&2
  echo "Or set TARGET_USER: sudo TARGET_USER=pi ./install.sh" >&2
  exit 1
fi
if ! getent passwd "$TARGET_USER" >/dev/null; then
  echo "User '$TARGET_USER' does not exist." >&2
  exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo unknown)"
echo "Device: $MODEL"
case "$MODEL" in
  *"Raspberry Pi 4"*) ;;   # also matches the Pi 400
  *) warn "built and tested for a Raspberry Pi 4; continuing anyway." ;;
esac
[ "$(uname -m)" = "aarch64" ] || warn "this is not 64-bit Raspberry Pi OS; ESPN's protected streams need 64-bit."
echo "Installing for user: $TARGET_USER"

step "Installing packages"
apt-get update
apt-get install -y --no-install-recommends cage v4l-utils python3 python3-evdev fonts-dejavu-core
apt-get install -y chromium || apt-get install -y chromium-browser
# Widevine lets Chromium play DRM-protected streams such as ESPN's.
apt-get install -y libwidevinecdm0 || echo "Warning: libwidevinecdm0 not available; protected streams may not play." >&2

step "Copying files to $APP_DIR"
mkdir -p "$APP_DIR"
rm -rf "$APP_DIR/system" "$APP_DIR/menu"   # drop files from older versions
cp -r "$SRC_DIR/system" "$SRC_DIR/menu" "$APP_DIR/"
rm -rf "$APP_DIR/system/__pycache__"
chmod +x "$APP_DIR"/system/*.sh "$APP_DIR"/system/*.py "$APP_DIR"/system/pi-streamer-reload "$APP_DIR"/system/pi-streamer-doctor
mkdir -p "$APP_DIR/menu/generated"
chown "$TARGET_USER:$TARGET_USER" "$APP_DIR/menu/generated"
ln -sf "$APP_DIR/system/pi-streamer-reload" /usr/local/bin/pi-streamer-reload
ln -sf "$APP_DIR/system/pi-streamer-doctor" /usr/local/bin/pi-streamer-doctor

step "Installing the editable site list"
mkdir -p /etc/pi-streamer
if [ -f /etc/pi-streamer/sites.json ]; then
  echo "Keeping your existing /etc/pi-streamer/sites.json (the default list is in config/sites.json)"
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
systemctl enable --now pi-streamer-cec.service pi-streamer-remote.service || warn "services will start on reboot"

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
echo "Check everything with: pi-streamer-doctor"
echo "Then reboot to start Pi Streamer: sudo reboot"
