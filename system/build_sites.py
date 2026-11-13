#!/usr/bin/env python3
"""Turn the editable sites.json into menu/generated/sites.js.

The menu is a local file:// page, and Chromium won't let such a page fetch a
JSON file, so we convert the list into a small script the page can load.
Bad entries are skipped with a warning instead of breaking the menu.

Usage: build_sites.py <sites.json> <output sites.js>
"""
import json
import sys
from urllib.parse import urlparse


def load_sites(path):
    """Return (sites, warnings). Never raises on bad content."""
    warnings = []
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return [], [f"{path} not found"]
    except json.JSONDecodeError as e:
        return [], [f"{path} is not valid JSON (line {e.lineno}, column {e.colno}): {e.msg}"]

    raw = data.get("sites") if isinstance(data, dict) else data
    if not isinstance(raw, list):
        return [], [f'{path} needs a "sites" list']

    sites = []
    for i, entry in enumerate(raw, start=1):
        if not isinstance(entry, dict):
            warnings.append(f"entry {i}: not an object, skipped")
            continue
        name = str(entry.get("name", "")).strip()
        url = str(entry.get("url", "")).strip()
        if not name or not url:
            warnings.append(f"entry {i}: needs both name and url, skipped")
            continue
        parsed = urlparse(url)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            warnings.append(f"entry {i} ({name}): url must start with http:// or https://, skipped")
            continue
        sites.append({
            "name": name,
            "url": url,
            "category": str(entry.get("category", "")).strip(),
            "note": str(entry.get("note", "")).strip(),
        })
    return sites, warnings


def render(sites, warnings):
    payload = json.dumps({"sites": sites, "warnings": warnings}, indent=2, ensure_ascii=False)
    # Guard against a "</script>" inside a value closing the page's script tag.
    payload = payload.replace("</", "<\\/")
    return f"// Generated from sites.json by build_sites.py. Do not edit.\nwindow.PI_STREAMER = {payload};\n"


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    sites, warnings = load_sites(argv[1])
    for w in warnings:
        print(f"pi-streamer: {w}", file=sys.stderr)
    with open(argv[2], "w", encoding="utf-8") as f:
        f.write(render(sites, warnings))
    print(f"pi-streamer: {len(sites)} site(s) written to {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
