# PICO-8 Favourites Sorter — Manager Script

An elegant, robust terminal manager that automatically generates and manages a self-contained **GTK3 Python GUI Application** (`pico8-fav-sorter`) to sort, categorize, and organize your PICO-8 Splore favorites. Designed for Raspberry Pi OS.

PICO-8 prepends all newly favorited cartridges to the top of its flat `favourites.txt` file. This utility allows you to map those unsorted games into clear, collapsible, human-readable comment headers (`#`) while remaining perfectly invisible to PICO-8.

---

## 🛠️ Features

* **Zero External Assets:** The single script generates everything it needs—the Python GUI application, an SVG launcher icon, and the desktop integration shortcut.
* **Intelligent Auto-Sorting:** Maps entries into categories using local title/author keyword rules.
* **BBS Tag Enrichment:** Queries the official Lexaloffle BBS via a background thread pull to look up missing user tags and automatically classify ambiguous carts.
* **BBS Quick Link:** Adds an inline `🔗` button to jump straight to a cart’s web forum thread directly from the GUI.
* **Atomic Saves & Safety First:** Implements fail-safe atomic writes via file-system replacement and provides real-time single `.bak` generation with an instant restore utility inside the manager.
* **Touch Friendly UI:** Hand-tailored CSS tailored to the *Solace Dark Theme*, boasting robust 44px min-touch targets perfect for a Raspberry Pi touchscreen setup.
## 🎮 Also Available for MuOS

If you're sorting PICO-8 favourites on a **MuOS handheld device** (e.g. Anbernic), check out the companion project:

👉 [MuOS-Pico8-Favs-Sorter](https://github.com/PuppetHoundZ/MuOS-Pico8-Favs-Sorter) — Native Python favourites sorter for MuOS

---

## 📋 Requirements

* **OS:** Linux / Raspberry Pi OS (Tested on *Pi OS Trixie / Debian 13 arm64*).
* **Environment:** Wayland (labwc) or X11 environment.
* **Screen Resolution:** Optimized to look crisp at low-profile resolutions (e.g., 800×480 touchscreen displays) up to 1080p desktop layouts.

The terminal script automatically checks and installs any missing system dependencies (`python3-gi`, `python3-gi-cairo`, `gir1.2-gtk-3.0`).

---

## 🚀 Installation & Usage

1.  Download or copy the manager script to your system.
2.  Make the script executable:
    ```bash
    chmod +x pico8-fav-sorter-manager.sh
    ```
3.  Execute the script as your **normal system user** (do *NOT* run with `sudo` or as `root`):
    ```bash
    ./pico8-fav-sorter-manager.sh
    ```

### Terminal Menu Options
Upon execution, you will be greeted by an interactive menu panel allowing you to:
1.  **Install/Repair GUI Application** (Deploys code hooks, generates scalable SVGs, installs shortcuts)
2.  **Launch GUI Application** (Runs the interface from user space)
3.  **Uninstall Application** (Cleans binaries, shortcuts, and icons safely; keeps shared dependencies intact)
4.  **Restore safe copies** (Loads immediate state files or manual backups if a recovery point is requested)

---

## 📂 Key Path Architecture

The manager cleanly compartmentalizes all assets within standard Linux desktop locations:

| Asset Type | File Path Location |
| :--- | :--- |
| **GTK3 Python App** | `~/.local/bin/pico8-fav-sorter` |
| **Desktop Launcher** | `~/.local/share/applications/pico8-fav-sorter.desktop` |
| **Scalable Vector Icon** | `~/.local/share/icons/hicolor/scalable/apps/pico8-fav-sorter.svg` |
| **Rollback State Dir** | `~/.local/share/pico8-fav-sorter-manager/` |
| **Default Data File** | `~/.lexaloffle/pico-8/favourites.txt` |

---

## 🧱 The Favourites.txt Format

PICO-8 reads and writes pipe-delimited strings with space-padded fixed widths containing 7 internal fields:
```text
|slug                 |name                 |bbs_id |author           |                    |display_title

---

