# Pi Streamer

Turns a Raspberry Pi 4 into a sports box for your TV. It boots straight into a
full-screen menu of free streaming sites that you drive with your normal TV
remote over HDMI-CEC.

## Status

- [x] Step 1: base system (auto-login, 1080p, Chromium kiosk, HDMI-CEC)
- [ ] Step 2: editable site list
- [ ] Step 3: menu with remote control
- [ ] Step 4: one-command installer polish

## What you need

- Raspberry Pi 4 (2 GB or more), power supply, microSD card (16 GB or more)
- Micro-HDMI to HDMI cable, plugged into **HDMI 0** (the port next to the USB-C power port)
- A TV with HDMI-CEC turned on. Brands name it differently: Anynet+ (Samsung),
  Bravia Sync (Sony), SimpLink (LG), EasyLink (Philips), CEC (most others).

## Install

1. Flash **Raspberry Pi OS Lite (64-bit)** with Raspberry Pi Imager. In the
   Imager settings, set a username, Wi-Fi and enable SSH.
2. Boot the Pi, SSH in, then:

   ```bash
   sudo apt-get install -y git
   git clone https://github.com/evanakat/<repo>.git pi-streamer
   cd pi-streamer
   sudo ./install.sh
   sudo reboot
   ```

After the reboot the TV should turn on, switch to the Pi, and show the menu.

## How it works

| Piece | File | What it does |
| --- | --- | --- |
| Auto-login | `install.sh` | Logs into the console on boot (`raspi-config` B2) |
| Kiosk | `system/kiosk.sh` | Runs Chromium full-screen inside the `cage` compositor; restarts it if it exits |
| 1080p | `install.sh` | Adds `video=HDMI-A-1:1920x1080M@60` to `cmdline.txt` |
| TV control | `system/cec-setup.sh` | Registers as a CEC playback device, wakes the TV and switches its input |
| Menu | `menu/index.html` | The page the kiosk shows |

SSH logins are not affected by the kiosk; it only runs on the physical console.

## Troubleshooting

- **TV doesn't turn on or switch input:** check CEC is enabled on the TV, the
  cable is in HDMI 0, then run `sudo systemctl status pi-streamer-cec`.
- **See what the remote sends:** `cec-ctl -d /dev/cec0 --monitor` and press buttons.
- **Get a normal console:** press Ctrl+Alt+F2 on a USB keyboard.
