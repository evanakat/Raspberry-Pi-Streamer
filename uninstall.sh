#!/usr/bin/env bash
# Removes Pi Streamer and puts the Pi back to a normal console boot.
#   sudo ./uninstall.sh          keeps your /etc/pi-streamer/sites.json
#   sudo ./uninstall.sh --purge  removes it too
# Installed packages (Chromium, cage, ...) are left in place.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo ./uninstall.sh" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-${TARGET_USER:-pi}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "==> Stopping services"
systemctl disable --now pi-streamer-remote.service pi-streamer-cec.service 2>/dev/null || true
rm -f /etc/systemd/system/pi-streamer-remote.service /etc/systemd/system/pi-streamer-cec.service
systemctl daemon-reload

echo "==> Removing the kiosk from $TARGET_HOME/.bash_profile"
PROFILE="$TARGET_HOME/.bash_profile"
if [ -f "$PROFILE" ]; then
  # Delete from the marker line through the closing "fi" of the kiosk block.
  sed -i '/^# pi-streamer kiosk$/,/^fi$/d' "$PROFILE"
fi

echo "==> Removing files"
rm -rf /opt/pi-streamer
rm -f /usr/local/bin/pi-streamer-reload /usr/local/bin/pi-streamer-doctor
rm -rf "$TARGET_HOME/.config/pi-streamer-chromium"
if [ "${1:-}" = "--purge" ]; then
  rm -rf /etc/pi-streamer
else
  echo "Kept /etc/pi-streamer/sites.json (use --purge to remove it)"
fi

echo "==> Restoring normal boot"
for f in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
  [ -f "$f" ] && sed -i 's/ video=HDMI-A-1:1920x1080M@60//' "$f"
done
if command -v raspi-config >/dev/null; then
  raspi-config nonint do_boot_behaviour B1   # console, login required
fi

echo "Done. Reboot to finish: sudo reboot"
