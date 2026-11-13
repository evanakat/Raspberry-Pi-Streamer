#!/usr/bin/env python3
"""Turn TV remote buttons (arriving over HDMI-CEC) into keys Chromium understands.

The kernel already turns CEC remote presses into key events, but with TV-style
names: "OK" arrives as KEY_OK and "Back" as KEY_EXIT, which a browser ignores.
This service grabs the CEC input device and re-sends each press as the
keyboard key (or shortcut) a browser expects.

  OK / Select          -> Enter
  Arrows               -> Arrows (moves between tiles, and links on websites)
  Back / Return / Exit -> Alt+Left (browser back)
  Home / Menu          -> back to the Pi Streamer menu
  Play / Pause         -> media Play/Pause
  0-9                  -> 0-9

Runs as root from pi-streamer-remote.service.
"""
import re
import subprocess
import sys
import time

GO_HOME = "GO_HOME"  # special action: restart the kiosk, which reopens the menu

KEYMAP = {
    "KEY_OK": ["KEY_ENTER"],
    "KEY_SELECT": ["KEY_ENTER"],
    "KEY_ENTER": ["KEY_ENTER"],
    "KEY_UP": ["KEY_UP"],
    "KEY_DOWN": ["KEY_DOWN"],
    "KEY_LEFT": ["KEY_LEFT"],
    "KEY_RIGHT": ["KEY_RIGHT"],
    "KEY_BACK": ["KEY_LEFTALT", "KEY_LEFT"],
    "KEY_EXIT": ["KEY_LEFTALT", "KEY_LEFT"],
    "KEY_ESC": ["KEY_LEFTALT", "KEY_LEFT"],
    "KEY_HOME": GO_HOME,
    "KEY_ROOT_MENU": GO_HOME,
    "KEY_MENU": GO_HOME,
    "KEY_SETUP": GO_HOME,
    "KEY_PLAY": ["KEY_PLAYPAUSE"],
    "KEY_PAUSE": ["KEY_PLAYPAUSE"],
    "KEY_PLAYPAUSE": ["KEY_PLAYPAUSE"],
    "KEY_STOP": ["KEY_STOPCD"],
    "KEY_CHANNELUP": ["KEY_PAGEUP"],
    "KEY_CHANNELDOWN": ["KEY_PAGEDOWN"],
    **{f"KEY_{n}": [f"KEY_{n}"] for n in range(10)},
    **{f"KEY_NUMERIC_{n}": [f"KEY_{n}"] for n in range(10)},
}

# Keys that should keep repeating while the button is held.
REPEATABLE = {"KEY_UP", "KEY_DOWN", "KEY_LEFT", "KEY_RIGHT", "KEY_CHANNELUP", "KEY_CHANNELDOWN"}

DEVICE_NAME = re.compile(r"cec|hdmi", re.IGNORECASE)


def action_for(key_name, value):
    """What to do for one input event.

    key_name: evdev key name, e.g. "KEY_OK". value: 1 press, 2 repeat, 0 release.
    Returns None (ignore), GO_HOME, or a list of key names to tap as a chord.
    """
    if value == 0:
        return None
    if value == 2 and key_name not in REPEATABLE:
        return None
    return KEYMAP.get(key_name)


def go_home():
    # The kiosk loop in ~/.bash_profile restarts Chromium on the menu page.
    subprocess.run(["pkill", "-f", "pi-streamer-chromium"], check=False)


def find_device(evdev):
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        # Require a remote-style key too, so HDMI audio "jack" devices don't match.
        keys = dev.capabilities().get(evdev.ecodes.EV_KEY, [])
        if DEVICE_NAME.search(dev.name or "") and evdev.ecodes.KEY_OK in keys:
            return dev
        dev.close()
    return None


def run(evdev):
    e = evdev.ecodes
    out_keys = {e.ecodes[k] for chord in KEYMAP.values() if chord != GO_HOME for k in chord}
    ui = evdev.UInput({e.EV_KEY: sorted(out_keys)}, name="pi-streamer-remote")

    while True:
        dev = find_device(evdev)
        if dev is None:
            time.sleep(5)
            continue
        print(f"pi-streamer-remote: listening on {dev.path} ({dev.name})", flush=True)
        try:
            dev.grab()  # stop the raw TV keys from also reaching Chromium
            for event in dev.read_loop():
                if event.type != e.EV_KEY:
                    continue
                name = e.KEY.get(event.code)
                if isinstance(name, list):  # some codes have several names
                    name = next((n for n in name if n in KEYMAP), name[0])
                act = action_for(name, event.value)
                if act == GO_HOME:
                    go_home()
                elif act:
                    codes = [e.ecodes[k] for k in act]
                    for c in codes:
                        ui.write(e.EV_KEY, c, 1)
                    for c in reversed(codes):
                        ui.write(e.EV_KEY, c, 0)
                    ui.syn()
        except OSError as err:  # device went away (TV unplugged, HDMI hotplug)
            print(f"pi-streamer-remote: lost device: {err}", flush=True)
            time.sleep(2)


def main():
    try:
        import evdev
    except ImportError:
        print("pi-streamer-remote: python3-evdev is not installed", file=sys.stderr)
        return 1
    run(evdev)
    return 0


if __name__ == "__main__":
    sys.exit(main())
