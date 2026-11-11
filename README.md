# my linux config files

## list

* deepin
* archlinux 
* nixos
* hyprland
* eww
* sway
* rime
* zsh
* zinit
* nvim
* ~~ranger~~
* tmux
* yazi
* ~~lf~~
* foot
* ~~kitty~~
* ~~alacritty~~
* ~~dwm~~
* ~~st~~
* ~~fish~~
* ~~coc.nvim~~

## nixos
    
nixos-rebuild switch --flake --#HOSTNAME

## manual

> [manual](doc/manaul.md)

## Bing daily wallpaper (Deepin 25 / macOS)

`scripts/bing-wallpaper.py` uses only the Python 3 standard library. It runs once
and exits, with no window or tray icon. Defaults: US market (`en-US`), UHD,
and eight cached images. Each image has a JSON sidecar with English (`text.en-US`)
and Chinese (`text.zh-CN`) titles, descriptions, copyrights, and source links.
Captions are matched to the same image across the two eight-day feeds. Missing
official captions are `null`; no machine translation is used. Bing can override
the requested market based on location; the script does not relabel those captions.

```bash
python3 scripts/bing-wallpaper.py --dry-run       # Preview without writing or applying
python3 scripts/bing-wallpaper.py --download-only # Download image and metadata only
python3 scripts/bing-wallpaper.py                 # Apply to the current desktop's displays
python3 scripts/bing-wallpaper.py --info          # Read last applied image metadata offline
python3 scripts/bing-wallpaper.py --force         # Reapply the cached image
```

Options: `--market en-US`, `--keep 8`, `--cache-dir PATH`.
Cache: `${XDG_CACHE_HOME:-~/.cache}/bing-wallpaper` on Linux;
`~/Library/Caches/bing-wallpaper` on macOS. Updates skip unchanged images.
Failed applications leave the previous success record intact and retry next run.
Multi-display updates are not atomic. Disable existing wallpaper rotation manually.
macOS may request System Events automation permission; not all Spaces are guaranteed.

After Home Manager activation, the `light`, `app`, and macOS profiles provide
`bing-wallpaper`. Automatic updates are **off by default**. To enable login and
hourly checks, set this in the relevant Home Manager configuration:

```nix
programs.bing-wallpaper.automatic = true;
```

Linux uses a systemd user timer (one minute after user-manager startup, then hourly).
macOS uses launchd (at load, then hourly). Both require a logged-in desktop session.
Linux logs: `journalctl --user -u bing-wallpaper.service`.
macOS logs: `~/.local/state/bing-wallpaper/{stdout,stderr}.log` (under XDG stateHome).
