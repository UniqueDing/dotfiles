#!/usr/bin/env python3
"""Bing daily wallpaper for Deepin 25 and macOS. Standard library only."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
from urllib.parse import urlencode
from urllib.request import urlopen


MACOS_SCRIPT = """on run argv
    tell application "System Events"
        set picture of every desktop to item 1 of argv
    end tell
end run"""


def fetch_archive(market):
    query = urlencode(dict(format="js", idx=0, n=8, mkt=market))
    with urlopen(f"https://www.bing.com/HPImageArchive.aspx?{query}", timeout=30) as response:
        return json.load(response)["images"]


def image_key(image):
    return image["urlbase"].rsplit("_", 1)[0]


def fetch_bing(market):
    archives = {locale: fetch_archive(locale) for locale in dict.fromkeys((market, "en-US", "zh-CN"))}
    image = archives[market][0]
    text = {}
    for locale in ("en-US", "zh-CN"):
        text[locale] = next((
            {
                "title": entry["title"],
                "description": entry["copyright"],
                "copyright": entry["copyright"],
                "info_url": entry["copyrightlink"],
            }
            for entry in archives[locale]
            if image_key(entry) == image_key(image) and f"_{locale.upper()}" in entry["urlbase"]
        ), None)
    return {
        "source": "bing",
        "date": image["startdate"],
        "requested_market": market,
        "image_url": f"https://www.bing.com{image['urlbase']}_UHD.jpg",
        "text": text,
    }


def atomic_write(path, data):
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        stream.write(data)
        temporary = Path(stream.name)
    temporary.replace(path)


def write_json(path, value):
    atomic_write(path, (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def run(command):
    return subprocess.run(
        command, check=True, stdout=subprocess.PIPE, text=True, timeout=60
    ).stdout


def bus_call(service, method, *arguments):
    return [
        "busctl", "--user", "--json=short", "call", service,
        "/" + service.replace(".", "/"), service, method, *arguments,
    ]


def deepin_commands(path):
    reply = run(bus_call("org.deepin.dde.Display1", "ListEffectiveOutputNames"))
    monitors = json.loads(reply)["data"][0]
    return [
        bus_call("org.deepin.dde.Appearance1", "SetCurrentWorkspaceBackgroundForMonitor",
                 "ss", path.as_uri(), monitor)
        for monitor in monitors
    ]


def macos_commands(path):
    return [["osascript", "-e", MACOS_SCRIPT, str(path)]]


def wallpaper_commands(path):
    if sys.platform == "darwin":
        return macos_commands(path)
    if sys.platform == "linux":
        return deepin_commands(path)
    raise ValueError("Supported systems: Deepin 25 and macOS")


def prune_cache(cache, keep, current):
    images = sorted(cache.glob("*.jpg"), key=lambda p: p.stat().st_mtime, reverse=True)
    older = [image for image in images if image != current]
    for image in older[keep - 1:]:
        image.unlink()
        image.with_suffix(".json").unlink(missing_ok=True)


def show_info(cache):
    state = json.loads((cache / "state.json").read_text(encoding="utf-8"))
    path = cache / state["image"]
    info = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
    for key in ("source", "date", "requested_market"):
        print(f"{key}: {info[key]}")
    for locale, text in info["text"].items():
        print(f"[{locale}]")
        if text is None:
            print("Official caption not available")
        else:
            for key, value in text.items():
                print(f"{key}: {value}")
    print(f"file: {path}")


def default_cache():
    if sys.platform == "darwin":
        return Path.home() / "Library/Caches/bing-wallpaper"
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "bing-wallpaper"


def update(args):
    info = fetch_bing(args.market)
    digest = hashlib.sha256(info["image_url"].encode()).hexdigest()[:12]
    path = args.cache_dir / f"{info['date']}_{digest}.jpg"
    commands = [] if args.download_only else wallpaper_commands(path)
    if args.dry_run:
        print(f"Download: {info['image_url']}\nCache: {path}")
        for command in commands:
            print(shlex.join(command))
        return

    args.cache_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not path.exists():
        with urlopen(info["image_url"], timeout=60) as response:
            atomic_write(path, response.read())
    write_json(path.with_suffix(".json"), info)
    if args.download_only:
        print(path)
        return

    state_path = args.cache_dir / "state.json"
    previous = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else None
    state = {"image": path.name, "commands": commands}
    if args.force or state != previous:
        for command in commands:
            run(command)
        # Record success only after all displays have been updated.
        write_json(state_path, state)
        print(f"Applied: {path}")
    prune_cache(args.cache_dir, args.keep, path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--market", default="en-US", help="Bing market (default: en-US)")
    parser.add_argument("--keep", type=int, default=8, help="Images to retain (default: 8)")
    parser.add_argument("--cache-dir", type=Path, default=default_cache())
    parser.add_argument("--force", action="store_true", help="Reapply the cached image")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--download-only", action="store_true", help="Download image and metadata only")
    mode.add_argument("--dry-run", action="store_true", help="Preview without writing or applying")
    mode.add_argument("--info", action="store_true", help="Show last applied image metadata offline")
    args = parser.parse_args(argv)
    if args.keep < 1:
        parser.error("--keep must be at least 1")
    args.cache_dir = args.cache_dir.expanduser().resolve()
    try:
        if args.info:
            show_info(args.cache_dir)
        else:
            update(args)
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"bing-wallpaper: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
