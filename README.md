# PICO-8 Favourites Sorter

A single-file bash installer for a GTK3 GUI that organizes PICO-8's `favourites.txt` on Linux (built and tested on Raspberry Pi OS Trixie, labwc/Wayland).

**Status:** 🟢 GOLD — v2.1.1 (confirmed on real hardware, 2026-06-30)

## The problem

Every time you favourite a cart in Splore, PICO-8 prepends a new line to the *top* of `favourites.txt`. It never sorts, groups, or sections the file — it just grows as an unsorted stack. This tool gives you a touch-friendly GUI to sort that stack into labelled categories, without ever touching PICO-8 itself.

## Features

- **Unsorted / All Entries views** — see newly favourited carts, or browse everything sortable by name, author, or category, with a live filter
- **Category management** — add, rename, reorder, and delete categories; move entries between them with a click
- **Auto-Sort** — instant keyword-based category suggestions (no network needed), with an optional BBS tag fetch to fill in the gaps. Shows a clear hint if nothing matches by keyword alone
- **Suggest New Categories** — scans your unsorted/all entries for themes (horror, sports, rhythm, tower defence, and more) or recurring authors ("`<AUTHOR>` COLLECTION") and proposes brand-new categories once enough entries cluster around a theme
- **Duplicate detection** — finds both exact-revision duplicates (same cart, different `-N` suffix, sorted newest-first) and fuzzy author+title matches (re-uploaded carts with a new BBS ID), with a per-group Keep/Remove resolver
- **Master category backup** (`favourites.txt.master.json`) — remembers every category assignment outside the file itself, so your organization survives PICO-8 (or a stray edit) stripping the `#` category headers. Export/Import lets you carry your categorization to another device
- **Reload / Discard Changes** — re-read the file from disk if you want to bail on unsaved edits
- **BBS link opener** — jump straight to a cart's Lexaloffle BBS page from its row
- Preserves every line of `favourites.txt` byte-for-byte — this tool never reformats or reparses PICO-8's own data, only adds `#` comment headers PICO-8 already ignores
- Single `.bak` backup written before every save, with a restore option in the terminal menu

## Requirements

- Linux with GTK3 (`python3-gi`, `gir1.2-gtk-3.0` — the installer checks and installs these via `apt` if missing)
- Python 3
- Built and tested on Raspberry Pi 4, Pi OS Trixie (Debian 13 arm64), labwc Wayland compositor, 800×480 touchscreen

## Install

```bash
chmod +x pico8-fav-sorter-manager.sh
./pico8-fav-sorter-manager.sh
```

Run as your normal user — **do not run as root**. The menu walks you through Install/Repair, Uninstall, and restoring from backup.

This installs:

| File | Purpose |
|---|---|
| `~/.local/bin/pico8-fav-sorter` | GTK3 GUI |
| `~/.local/share/applications/pico8-fav-sorter.desktop` | App-menu shortcut |
| `~/.local/share/icons/hicolor/scalable/apps/pico8-fav-sorter.svg` | Icon |
| `~/.local/share/pico8-fav-sorter-manager/` | Rollback/crash-recovery state |

## Usage

1. Launch from your app menu, or run `~/.local/bin/pico8-fav-sorter` directly
2. Click **Open Default** to load `~/.lexaloffle/pico-8/favourites.txt`, or **Open File** to pick another location
3. Select an entry in the left panel, then tap a category button (or use the ⚙ Actions menu) to move it
4. **Save File** writes your changes back — a single `.bak` is kept alongside the original

## Uninstall

Run the script again and choose **Uninstall** from the menu. This removes only the files this tool created (GUI script, desktop shortcut, icon, state directory). Shared system packages (`python3-gi`, etc.) are left in place, since other tools may depend on them.

## File format notes

`favourites.txt` is a pipe-delimited, fixed-width file. This tool never reparses a line back into columns — every entry is stored and rewritten verbatim. Category sections are added as plain `#` comment blocks, which PICO-8 treats as comments and ignores completely:

```
# ============================================================
# CATEGORY NAME
# ============================================================
|slug|name|bbs_id|author|             |Display Title
```

Anything above the first `# ===` divider is treated as unsorted (i.e. recently favourited, not yet sorted).

## Credits

Category/keyword-sorting logic and the duplicate-detection + master-list-recovery design were adapted from [PuppetHoundZ/MuOS-Pico8-Favs-Sorter](https://github.com/PuppetHoundZ/MuOS-Pico8-Favs-Sorter) (a native SDL2 build of the same idea for muOS handhelds) and reimplemented for GTK3/Linux — the rendering and input layers are unrelated, only the sorting/recovery logic transferred.

## License

MIT License

Copyright (c) 2026 Kaleb Fabsik

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

