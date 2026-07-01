#!/usr/bin/env bash
# ==============================================================================
# pico8-fav-sorter-manager.sh
# PICO-8 Favourites Sorter — Manager Script
# Version: 2.1.1
# Status: 🟢 GOLD (confirmed 2026-06-30)
# Last updated: 2026-06-30
#
# Self-contained — generates all required files on Install:
#   • pico8-fav-sorter  (GTK3 Python GUI)   → ~/.local/bin/pico8-fav-sorter
#   • Desktop shortcut + SVG icon           → ~/.local/share/
#
# No companion files required. Distribute and run this single script.
#
# Purpose:
#   PICO-8 dumps all newly favourited carts at the top of favourites.txt.
#   This GUI lets you open that file, assign unsorted entries to labelled
#   category sections (# headers), move/reorder entries within categories,
#   sort a category A→Z by author, and save back — preserving every line
#   exactly as PICO-8 wrote it (spacing, pipes, encoding).
#
# Usage:
#   chmod +x pico8-fav-sorter-manager.sh
#   ./pico8-fav-sorter-manager.sh
#
# Do NOT run as root.
#
# ==============================================================================
#
# AI REFERENCE NOTES — pico8-fav-sorter-manager.sh
# Single source of truth. Read this block in full before making any changes.
#
# ── WHAT THIS SCRIPT DOES ────────────────────────────────────────────────────
#   Terminal menu installs/repairs/uninstalls the "PICO-8 Favourites Sorter"
#   GTK3 Python GUI. The GUI opens a favourites.txt, splits entries into
#   "Unsorted" (any lines before the first # section header) and named
#   categories (lines under # === / # CATEGORY NAME / # === blocks), lets
#   the user assign unsorted entries to categories via click→button, reorder
#   or sort entries within a category, and saves back. A single .bak file
#   (overwritten on each save) is kept alongside favourites.txt.
#
# ── KEY PATHS ────────────────────────────────────────────────────────────────
#   ~/.local/bin/pico8-fav-sorter                           — GTK3 GUI script
#   ~/.local/share/applications/pico8-fav-sorter.desktop    — desktop shortcut
#   ~/.local/share/icons/hicolor/scalable/apps/pico8-fav-sorter.svg — icon
#   ~/.local/share/pico8-fav-sorter-manager/                — rollback state dir
#   <favourites.txt>.master.json  — persistent slug→category map (v2.1.0+),
#                                    lives next to whichever file is open;
#                                    survives PICO-8 stripping # headers.
#
# ── FAVOURITES.TXT FORMAT ────────────────────────────────────────────────────
#   Location: ~/.lexaloffle/pico-8/favourites.txt (Linux/Pi OS default)
#
#   PICO-8 WRITE BEHAVIOUR — critical to understand:
#     Every time a cart is favourited in Splore, PICO-8 prepends a new line
#     to the TOP of favourites.txt. It does not sort, group, or section the
#     file in any way. This is the entire reason this tool exists — the file
#     grows as an unsorted prepend-only stack until you organise it manually.
#
#   LINE FORMAT — pipe-delimited, fixed-width padded, 7 fields:
#     |slug                 |name                 |bbs_id |author           |                     |display_title
#
#   Field breakdown:
#     slug          — cart identifier. Two forms:
#                     1. Named:   cartname-N  (e.g. "porklike-2")
#                                 N is PICO-8's local revision counter,
#                                 incremented each time the cart is updated.
#                     2. Numeric: raw BBS post ID (e.g. "49232")
#                                 Used for older carts or those without a
#                                 named slug on the BBS.
#     name          — internal cart name (usually matches slug base, no -N)
#     bbs_id        — Lexaloffle BBS section/thread category ID. NOT a version
#                     number. Tells Splore which BBS section to fetch from:
#                       1792 — very old carts (pre-standardisation)
#                       1794 — standard BBS cartridge submissions (majority)
#                       1795 — slightly different submission category
#                       1800 — newer submission category
#                       1807 — special category (e.g. jam submissions)
#                     Never modify this field — PICO-8 uses it for fetching.
#     author        — Lexaloffle BBS username of the cart creator
#     empty         — always blank; reserved column, always preserve as-is
#     display_title — the human-readable cart name shown in Splore and on the
#                     BBS. THIS is the canonical name to read/display. The
#                     slug and numeric ID fields are internal references only.
#
#   COLUMN PADDING — fields are space-padded to fixed widths within each
#     column. This tool stores and rewrites every line VERBATIM — the raw
#     string is never parsed back into columns or reformatted. Any line not
#     matching the | prefix is silently skipped.
#
#   COMMENT / SECTION HEADERS — lines starting with # are completely ignored
#     by PICO-8 (treated as comments). This tool uses them to create named
#     category sections that organise the file for humans while remaining
#     invisible to PICO-8:
#       # ============================================================
#       # CATEGORY NAME
#       # ============================================================
#     Parser detects the === divider lines to find category boundaries.
#     Any entry appearing before the first # === divider is treated as
#     "unsorted" (i.e. newly prepended by PICO-8 since last sort).
#
#   BACKUP — a single .bak file written to <filepath>.bak before every save,
#     overwriting the previous backup. One backup at a time — no accumulation.
#     do_restore (terminal menu option 4) restores from this file.
#
# ── CATEGORY RESEARCH ────────────────────────────────────────────────────────
#   Categories were determined by fetching each cart's BBS page and reading
#   the tags field. Primary source for every cart:
#     https://www.lexaloffle.com/bbs/?pid=<slug>
#   e.g. https://www.lexaloffle.com/bbs/?pid=porklike
#   Tags are returned in the page HTML as class="tag" elements.
#   Author cart listings (for verifying creator collections like MOT):
#     https://www.lexaloffle.com/bbs/?mode=carts&uid=<uid>
#
#   Tag → category mapping used for initial sort (2026-06-24):
#     roguelike, broughlike, dungeon-crawler, turnbased → ROGUELIKES
#     shooter, fps, shmup, topdown+combat               → SHOOTERS / SPACE GAMES
#     puzzle, sokoban, match3, portal, 2048             → PUZZLE GAMES
#     racing, driving, pseudo-3d, racer, flight,
#       ski, sport, endless (runner)                    → RACING / FLYING / ACTION
#     platformer, metroidvania, adventure (action)      → PLATFORMERS / ADVENTURE
#     narrative, text-based, exploration, walking,
#       atmospheric, adventure (story/choices)          → ATMOSPHERIC / WALKING SIMS
#     demoscene, demo, music, musicdisk, chiptune,
#       procgen (visual/audio)                         → MUSIC / DEMOSCENE
#     all author=mot entries                           → MOT COLLECTION
#     clock, timer, utility, calculator                → CLOCKS / UTILITIES / TOYS
#
#   Edge cases resolved during research:
#     hutton minimal       — tagged space/elite/roguelike → ROGUELIKES
#     cortex override      — tagged roguelike/cyberpunk   → ROGUELIKES (not SHOOTERS)
#     cyberlike            — tagged roguelike/porklike    → ROGUELIKES (not SHOOTERS)
#     gar's den            — tagged 14drl (14-day roguelike jam) → ROGUELIKES
#     crater               — tagged metroidvania          → PLATFORMERS (not MUSIC)
#     onelastvisit         — tagged puzzle/top-down       → PUZZLE GAMES (not ATMOSPHERIC)
#     aimatrix             — tagged puzzle/2048/citybuilder → PUZZLE GAMES (not SHOOTERS)
#     crazy position       — tagged racer/arcade          → RACING (not PUZZLES)
#     lowmemsky            — No Man's Sky demake          → RACING / FLYING
#     freds72_snow         — tagged sport/ski/3d          → RACING / FLYING (not ATMOSPHERIC)
#     sally neptune        — tagged shooter/raycast       → SHOOTERS (not PLATFORMERS)
#     starlessplantcleanup — tagged action/topdown/combat → SHOOTERS
#     farewell fair friend — tagged music/chiptune        → MUSIC / DEMOSCENE
#     liloscar             — tagged music/audio/toy       → MUSIC / DEMOSCENE
#     snakator / mer_ork   — tagged demoscene             → MUSIC / DEMOSCENE
#     the last shift       — tagged story/choices/multipleendings → ATMOSPHERIC
#   Carts with no useful tags were categorised by BBS description text.
#
# ── ENVIRONMENT ──────────────────────────────────────────────────────────────
#   Raspberry Pi 4, Pi OS Trixie (Debian 13 arm64), labwc Wayland compositor.
#   800×480 touchscreen (primary) + 1080p HDMI (secondary, not always connected).
#   GTK3 window: set_default_size(796, 460), set_size_request(776, 360).
#   Centre column wrapped in ScrolledWindow so action buttons scroll at 400px height.
#   PipeWire audio — this script does NOT touch audio, PipeWire, or services.
#   Everything runs in user space. No autostart. No systemd units.
#
#     CENTRE — "Actions" popover button at top opens Gtk.Popover with groups:
#               CATEGORY (Add/Rename/Up/Down/Delete), ENTRY (Move/Assign/Remove/
#               Delete), AUTO (Auto-Sort Unsorted, Suggest Categories),
#               SORT CATEGORY (Title/Author/A+T).
#               Scrollable category button list below takes remaining height.
#
# ── BBS LINK FEATURE ─────────────────────────────────────────────────────────
#   Every entry row has a "🔗 BBS" button (btn-link style, right-aligned).
#   URL construction per pico8-favourites-reference.md:
#     Named cart:   entry["base"] = parts[2] (base slug, no -N suffix)
#                   URL: https://www.lexaloffle.com/bbs/?pid=<base>
#     Numeric cart: entry["base"] = parts[2] (cart post ID)
#                   URL: https://www.lexaloffle.com/bbs/?pid=<base>
#   Both cases use parts[2] — "base" field added to parse_entry in v1.9.3.
#   Launched via xdg-open (subprocess.Popen, stdout/stderr suppressed).
#   URL guard: BBS_ALLOWED_PREFIX checked before xdg-open — blocks any URL
#   that does not start with https://www.lexaloffle.com/bbs/?pid=
#   BBS button also appears inside the Auto-Sort suggestion dialog rows.
#
# ── BBS TAG FETCH FEATURE ────────────────────────────────────────────────────
#   fetch_bbs_tags(pid): urllib.request GET to lexaloffle.com/bbs/?pid=<base>.
#   Parses <span class="tag">...</span> from HTML (no BeautifulSoup needed).
#   Returns [] on error or if cart has no tags (many carts are untagged).
#   bbs_tags_to_category(tags, categories): maps BBS tags via TAG_TO_CAT dict
#   to a local category name. First match wins.
#   TAG_TO_CAT: ~60 common PICO-8 BBS tags mapped to DEFAULT_CATEGORIES.
#   Threading: ThreadPoolExecutor(max_workers=3) in a daemon thread.
#   UI updates via GLib.idle_add(_on_result, ...) — never touches GTK from
#   the worker thread. Progress bar updates per-result. Fetch button disabled
#   while running, re-enabled on completion.
#   BBS results override keyword suggestions (source badge: [BBS] vs [kw]).
#
# ── AUTO-SORT FEATURE ────────────────────────────────────────────────────────
#   AUTO_SORT_RULES: list of (category_name, {titles: [...], authors: [...]})
#   auto_suggest_category(entry, categories): returns first matching cat or None.
#   _on_auto_sort(): scans all unsorted entries, shows scrollable checkbox dialog
#   (all pre-checked). User unchecks any to skip. "Apply Checked" moves all
#   checked entries via _assign_entry_to(). Suggestion badge (yellow → cat name)
#   shown inline on each unsorted entry row in the left panel.
#   AUTO_SORT_RULES is editable in ~/.local/bin/pico8-fav-sorter after install.
#
# ── GUI LAYOUT ───────────────────────────────────────────────────────────────
#   Three-column layout:
#     LEFT   — Toggle column: NEW/UNSORTED or ALL ENTRIES view
#               NEW/UNSORTED: entries before first # header (newly favourited)
#               ALL ENTRIES: all carts across every category, sortable by
#                 Name/Author/Category (click to sort, click again to flip dir),
#                 with a live filter box. Category shown as 3rd line on each row.
#                 Selecting an entry here and clicking a category button moves it.
#     CENTRE — Category buttons (scrollable list) + two action groups:
#               CATEGORY: Add, Cat Up, Cat Down, Delete Category
#               ENTRY:    Move Up, Move Down, Move to..., To Unsorted, Delete Game
#     RIGHT  — Category viewer (entries in currently selected category)
#   Workflow: click entry in LEFT or RIGHT → click category button → entry moves.
#   Action buttons between columns: ↑ Move Up, ↓ Move Down, ⇅ Sort A→Z, ✕ Remove.
#   Save writes all categories in order, UNSORTED appended last if non-empty.
#   Backup written to same directory as the opened file.
#
# ── GTK3 GUI NOTES ───────────────────────────────────────────────────────────
#   Written as a bash heredoc (PYEOF). Re-generated on Install and Repair.
#   CSS applied via Gtk.CssProvider — matches Solace dark theme palette.
#   ListBox rows: card2 style (dark card, 10px radius), 44px min touch targets.
#   Selected entry highlighted via a dedicated CSS class (.row-selected) rather
#   than GTK selection — avoids ListBox selection mode conflicts when clicking
#   category buttons outside the list.
#   python3-gi / gir1.2-gtk-3.0 required (already present if cava-manager or
#   script-launcher-manager has been installed).
#
# ── INSTALL / UNINSTALL NOTES ────────────────────────────────────────────────
#   install_gui_deps(): checks python3-gi / gir1.2-gtk-3.0 via dpkg before apt.
#   Rollback: state files in ~/.local/share/pico8-fav-sorter-manager/,
#   auto-restore on crash — same proven pattern as cava-manager.sh.
#   Uninstall removes GUI script, desktop shortcut, icon, state dir.
#   Dependencies (python3-gi etc.) are kept — shared with other tools.
#
# ── VERSION HISTORY ──────────────────────────────────────────────────────────
#   v2.1.1 (2026-06-30) — Auto-Sort empty-state hint: when keyword matching
#                          finds zero suggestions (self._categories has no
#                          AUTO_SORT_RULES keyword hits for the current pool),
#                          the list now shows an inline hint row ("Couldn't
#                          figure it out from keywords — try Fetch BBS Tags")
#                          instead of silently showing "0 suggestions" in
#                          small header text only. GTK3 has no built-in toast
#                          widget, so this is an in-list row — same pattern
#                          already used for Suggest Categories' empty state.
#                          Disappears automatically once any BBS match or
#                          keyword match populates suggestions_map.
#   v2.1.0 (2026-06-30) — Part 7: ported logic from PuppetHoundZ/MuOS-Pico8-
#                          Favs-Sorter main.py (v1.7.12), adapted to GTK3/Pi:
#                          (1) Duplicate detection: find_duplicate_groups()
#                          groups by base-slug + fuzzy author/title match;
#                          "Find Duplicates…" popover action opens a per-group
#                          resolve dialog (Keep Newest/Keep Both). Separate
#                          from the existing exact-slug auto-dedup at file open.
#                          BUG CAUGHT IN SELF-TEST before ship: groups were
#                          returned in arbitrary dict-insertion order, so
#                          "Keep Latest" actually kept whichever entry was
#                          scanned first — could delete the newer revision.
#                          Fixed by tagging each group "revision" (same base
#                          slug, sorted newest -N first — a real signal) vs
#                          "fuzzy" (author+title match, different carts, no
#                          revision order — button relabelled "Keep First"
#                          with an on-screen caveat). Verified with 5 unit
#                          tests incl. scrambled input order and the blank-
#                          base false-positive guard (see KEYWORD note below).
#                          (2) Author-collection suggestions:
#                          suggest_author_categories() proposes "<AUTHOR>
#                          COLLECTION" for authors with >= MIN_SUGGEST works,
#                          merged into the existing Suggest Categories dialog
#                          as lowest-priority (keyword/BBS suggestions win).
#                          (3) Master category JSON (favourites.txt.master.
#                          json): persists slug→category on every assign/
#                          rename/delete, resynced fully on Save. On file
#                          load, reconcile_stripped_categories() recovers
#                          entries sitting in Unsorted whose last-known
#                          category still exists — protects against PICO-8
#                          or a manual edit dropping # headers. Deleting a
#                          category marks its slugs UNSORTED in master
#                          (excluded from recovery, history kept) so a
#                          delete can't be silently undone by reconcile.
#                          Export/Import Master List popover actions for
#                          carrying assignments to another device.
#                          (4) "Reload (Discard Changes)" popover action:
#                          re-parses from disk via the same _load_file() path
#                          (so it also re-runs the reconcile step), resetting
#                          _categories to DEFAULT_CATEGORIES first so an
#                          unsaved Add Category can't survive the reload.
#                          (5) Dormant AUTO_SORT_RULES entries added for
#                          HORROR/SPORTS/CARD & BOARD GAMES/TOWER DEFENCE/
#                          SIMULATION/MULTIPLAYER/IDLE & CLICKER/RHYTHM/
#                          METROIDVANIA — inert until the matching category
#                          is actually created via Suggest Categories (the
#                          existing "cat_name not in categories: skip" guard
#                          already handles this), kept in sync with
#                          TAG_TO_NEW_CAT/KEYWORD_TO_NEW_CAT. Existing
#                          DEFAULT_CATEGORIES (10) and file-format handling
#                          left untouched — not part of the muOS source,
#                          which targets a different device entirely.
#   v2.0.0–v2.0.4 (2026-06-26) — Actions popover redesign (replaced cramped
#                          centre-column buttons): category stepper, Suggest
#                          Categories wiring, BBS icon-only button, touch-
#                          target sweep to 44px, category-rename/delete
#                          correctness fixes (sort-state migration, author
#                          A→Z ordering on delete, stale-state cleanup).
#   v1.9.0–v1.9.9 (2026-06-25/26) — BBS tag fetch + link opener, auto-sort
#                          keyword engine, atomic save (os.replace), 800x480
#                          layout fit, empty-category save bug fix, watchdog
#                          timeout tuning.
#   v1.0.0–v1.8.0 (2026-06-24/25) — Initial release through core workflow:
#                          parse/write favourites.txt, category CRUD, entry
#                          move/reorder/sort, duplicate detection at load,
#                          Open Default/config persistence, restore-from-.bak.
#
# ==============================================================================

set -Eeuo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_VERSION="2.1.1"

GUI_SCRIPT="${HOME}/.local/bin/pico8-fav-sorter"
GUI_ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
GUI_ICON="${GUI_ICON_DIR}/pico8-fav-sorter.svg"
GUI_DESKTOP_DIR="${HOME}/.local/share/applications"
GUI_DESKTOP="${GUI_DESKTOP_DIR}/pico8-fav-sorter.desktop"

STATE_DIR="${HOME}/.local/share/pico8-fav-sorter-manager"
PARTIAL_MARKER="${STATE_DIR}/install.partial"
BACKUP_GUI_SCRIPT="${STATE_DIR}/gui.backup"
BACKUP_GUI_ICON="${STATE_DIR}/icon.backup"
BACKUP_GUI_DESKTOP="${STATE_DIR}/desktop.backup"

mkdir -p "${STATE_DIR}"

# ── Colours & logging ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() {
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $*${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
}

press_enter() { echo ""; read -rp "  Press [Enter] to continue…"; }

confirm() {
    local prompt="${1:-Are you sure?} [y/N] "
    local response=""
    read -r -p "  $prompt" response
    [[ "$response" =~ ^[Yy]$ ]]
}

refuse_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "\n${RED}[ERROR]${NC} Do not run this script as root."
        echo -e "        Run as your normal user: ${BOLD}bash $0${NC}\n"
        exit 1
    fi
}

# ── Rollback / crash recovery ─────────────────────────────────────────────────
_ROLLBACK_OP=""
_EXIT_CODE=0
_FAILED_COMMAND=""
_FAILED_LINE=""

trap '_EXIT_CODE=$?; _FAILED_COMMAND="$BASH_COMMAND"; _FAILED_LINE="$LINENO"' ERR
trap '_rollback_cleanup "$?"' EXIT
trap 'echo ""; log_warn "Interrupted."; exit 130' INT TERM HUP

_rollback_begin() {
    _ROLLBACK_OP="$1"
    echo "$1" > "$PARTIAL_MARKER"
    if [[ -f "$GUI_SCRIPT" ]];  then cp -f "$GUI_SCRIPT"  "$BACKUP_GUI_SCRIPT";  fi
    if [[ -f "$GUI_ICON" ]];    then cp -f "$GUI_ICON"    "$BACKUP_GUI_ICON";    fi
    if [[ -f "$GUI_DESKTOP" ]]; then cp -f "$GUI_DESKTOP" "$BACKUP_GUI_DESKTOP"; fi
}

_rollback_end() {
    _ROLLBACK_OP=""
    rm -f "$PARTIAL_MARKER" "$BACKUP_GUI_SCRIPT" "$BACKUP_GUI_ICON" "$BACKUP_GUI_DESKTOP"
}

_rollback_cleanup() {
    local exit_code="${1:-0}"
    local op="$_ROLLBACK_OP"

    if [[ -f "$PARTIAL_MARKER" && "$exit_code" -ne 0 ]]; then
        echo ""
        log_error "Failed (exit $exit_code) at line ${_FAILED_LINE:-?}: ${_FAILED_COMMAND:-unknown}"
        log_warn "Operation '${op}' did not complete — rolling back…"

        if [[ -f "$BACKUP_GUI_SCRIPT" ]]; then
            cp -f "$BACKUP_GUI_SCRIPT" "$GUI_SCRIPT" && log_info "Restored: $GUI_SCRIPT"
            rm -f "$BACKUP_GUI_SCRIPT"
        elif [[ "$op" == "install" && -f "$GUI_SCRIPT" ]]; then
            rm -f "$GUI_SCRIPT" && log_info "Removed partial GUI script."
        fi
        if [[ -f "$BACKUP_GUI_ICON" ]]; then
            cp -f "$BACKUP_GUI_ICON" "$GUI_ICON" && log_info "Restored: $GUI_ICON"
            rm -f "$BACKUP_GUI_ICON"
        elif [[ "$op" == "install" && -f "$GUI_ICON" ]]; then
            rm -f "$GUI_ICON" && log_info "Removed partial icon."
        fi
        if [[ -f "$BACKUP_GUI_DESKTOP" ]]; then
            cp -f "$BACKUP_GUI_DESKTOP" "$GUI_DESKTOP" && log_info "Restored: $GUI_DESKTOP"
            rm -f "$BACKUP_GUI_DESKTOP"
        elif [[ "$op" == "install" && -f "$GUI_DESKTOP" ]]; then
            rm -f "$GUI_DESKTOP" && log_info "Removed partial desktop entry."
        fi

        rm -f "$PARTIAL_MARKER"
        echo ""
        log_warn "Rollback complete. Fix the issue above and run Install / Repair again."
    elif [[ -f "$PARTIAL_MARKER" && "$exit_code" -eq 0 ]]; then
        rm -f "$PARTIAL_MARKER" "$BACKUP_GUI_SCRIPT" "$BACKUP_GUI_ICON" "$BACKUP_GUI_DESKTOP"
    fi
}

_check_partial_state() {
    [[ -f "$PARTIAL_MARKER" ]] || return 0
    local op
    op="$(cat "$PARTIAL_MARKER")"
    echo ""
    log_warn "Previous '${op}' did not complete (power loss or crash?) — auto-restoring…"

    if [[ -f "$BACKUP_GUI_SCRIPT" ]]; then
        cp -f "$BACKUP_GUI_SCRIPT" "$GUI_SCRIPT" && log_info "Restored: $GUI_SCRIPT"
        rm -f "$BACKUP_GUI_SCRIPT"
    else
        [[ -f "$GUI_SCRIPT" ]] && rm -f "$GUI_SCRIPT" && log_info "Removed incomplete GUI script."
    fi
    if [[ -f "$BACKUP_GUI_ICON" ]]; then
        cp -f "$BACKUP_GUI_ICON" "$GUI_ICON" && log_info "Restored: $GUI_ICON"
        rm -f "$BACKUP_GUI_ICON"
    else
        [[ -f "$GUI_ICON" ]] && rm -f "$GUI_ICON" && log_info "Removed incomplete icon."
    fi
    if [[ -f "$BACKUP_GUI_DESKTOP" ]]; then
        cp -f "$BACKUP_GUI_DESKTOP" "$GUI_DESKTOP" && log_info "Restored: $GUI_DESKTOP"
        rm -f "$BACKUP_GUI_DESKTOP"
    else
        [[ -f "$GUI_DESKTOP" ]] && rm -f "$GUI_DESKTOP" && log_info "Removed incomplete desktop entry."
    fi

    rm -f "$PARTIAL_MARKER"
    echo ""
    log_ok "Auto-restore complete."
    press_enter
}

# ── Status check ──────────────────────────────────────────────────────────────
gui_status() {
    if [[ -f "$GUI_SCRIPT" ]]; then
        echo -e "  GUI script   : ${GREEN}installed${NC}  ($GUI_SCRIPT)"
    else
        echo -e "  GUI script   : ${YELLOW}not installed${NC}"
    fi
    if [[ -f "$GUI_DESKTOP" ]]; then
        echo -e "  Desktop entry: ${GREEN}installed${NC}  ($GUI_DESKTOP)"
    else
        echo -e "  Desktop entry: ${YELLOW}not installed${NC}"
    fi
}

# ── Dependencies ──────────────────────────────────────────────────────────────
install_gui_deps() {
    log_info "Checking GTK3 Python dependencies…"
    local missing=()
    dpkg -s python3-gi        &>/dev/null || missing+=(python3-gi)
    dpkg -s python3-gi-cairo  &>/dev/null || missing+=(python3-gi-cairo)
    dpkg -s gir1.2-gtk-3.0   &>/dev/null || missing+=(gir1.2-gtk-3.0)

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_ok "GTK3 Python dependencies already present."
        return 0
    fi

    log_info "Installing: ${missing[*]}"
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y --no-install-recommends \
        "${missing[@]}"
    log_ok "GTK3 Python dependencies ready."
}

# ── SVG Icon ──────────────────────────────────────────────────────────────────
write_gui_icon() {
    mkdir -p "${GUI_ICON_DIR}"
    cat > "${GUI_ICON}" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="14" fill="#111118"/>
  <!-- Cartridge body -->
  <rect x="18" y="20" width="64" height="62" rx="8" fill="#1d2b53" stroke="#ffec27" stroke-width="2.5"/>
  <!-- Label area -->
  <rect x="26" y="28" width="48" height="30" rx="4" fill="#7e2553"/>
  <!-- PICO-8 text lines on label -->
  <rect x="30" y="33" width="28" height="3" rx="1.5" fill="#ffec27"/>
  <rect x="30" y="39" width="20" height="2" rx="1" fill="#ff77a8"/>
  <rect x="30" y="44" width="24" height="2" rx="1" fill="#ff77a8"/>
  <!-- Cartridge notch -->
  <rect x="38" y="72" width="24" height="8" rx="3" fill="#0a0a14"/>
  <!-- Star accent -->
  <circle cx="68" cy="36" r="5" fill="#ffec27" opacity="0.9"/>
</svg>
SVGEOF
    gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
    log_ok "Icon written: ${GUI_ICON}"
}

# ── Desktop entry ─────────────────────────────────────────────────────────────
write_gui_desktop() {
    mkdir -p "${GUI_DESKTOP_DIR}"
    cat > "${GUI_DESKTOP}" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=PICO-8 Favourites Sorter
GenericName=Favourites Organiser
Comment=Organise your PICO-8 favourites.txt into labelled categories
Exec=python3 ${GUI_SCRIPT}
Icon=pico8-fav-sorter
Terminal=false
Categories=Utility;Game;
Keywords=pico8;pico-8;favourites;splore;organise;sort;
StartupNotify=false
EOF
    chmod 644 "${GUI_DESKTOP}"
    update-desktop-database "${GUI_DESKTOP_DIR}" 2>/dev/null || true
    log_ok "Desktop entry written: ${GUI_DESKTOP}"
}

# ── GUI Script (Python / GTK3 heredoc) ────────────────────────────────────────
# PYEOF is single-quoted — bash does NOT expand variables inside.
write_gui_script() {
    mkdir -p "$(dirname "$GUI_SCRIPT")"
    cat > "$GUI_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
# =============================================================================
# pico8-fav-sorter — PICO-8 Favourites Sorter GTK3 GUI
# Generated by pico8-fav-sorter-manager.sh — re-run Install/Repair to update.
#
# Opens a PICO-8 favourites.txt, splits entries into unsorted (pre-header)
# and named category sections, lets you assign/reorder/sort entries, and
# saves back — preserving all line formatting exactly as PICO-8 wrote it.
# A single .bak file is kept alongside the favourites.txt (overwritten on each save).
# =============================================================================
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Pango", "1.0")
from gi.repository import Gtk, Gdk, GLib, Pango
import os
import re
import json
import shutil
import subprocess
import threading
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

CONFIG_DIR  = os.path.join(os.path.expanduser("~"), ".local", "share", "pico8-fav-sorter")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
DEFAULT_FAV = os.path.join(os.path.expanduser("~"), ".lexaloffle", "pico-8", "favourites.txt")

# ── Default categories (shown even before a file is opened) ──────────────────
DEFAULT_CATEGORIES = [
    "CURRENT FAVORITES",
    "ROGUELIKES / DUNGEON CRAWLERS",
    "MOT COLLECTION",
    "SHOOTERS / SPACE GAMES",
    "PUZZLE GAMES",
    "RACING / FLYING / ACTION",
    "PLATFORMERS / ADVENTURE",
    "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "MUSIC / DEMOSCENE",
    "CLOCKS / UTILITIES / TOYS",
]

# ── CSS — Solace dark theme palette ──────────────────────────────────────────
CSS = b"""
window {
    background-color: #111118;
}
.panel {
    background-color: #191922;
    border-radius: 8px;
}
.header-title {
    color: #ffec27;
    font-weight: bold;
    font-size: 15px;
}
.header-sub {
    color: #50506a;
    font-size: 11px;
}
.col-title {
    color: #1ebdd1;
    font-weight: bold;
    font-size: 12px;
}
.row-title {
    color: #e0e0f0;
    font-weight: bold;
    font-size: 12px;
}
.row-meta {
    color: #6a6a86;
    font-size: 10px;
}
.row-selected {
    background-color: #2a1f5a;
    border-radius: 6px;
}
.status-msg {
    color: #1ebdd1;
    font-size: 11px;
}
.status-warn {
    color: #ffec27;
    font-size: 11px;
}
.btn-primary {
    background: #1ebdd1;
    color: #111118;
    border-radius: 8px;
    border: none;
    font-weight: bold;
    font-size: 12px;
    padding: 4px 12px;
}
.btn-primary:hover { background: #38d8ef; }
.btn-save {
    background: #1ed760;
    color: #111118;
    border-radius: 8px;
    border: none;
    font-weight: bold;
    font-size: 12px;
    padding: 4px 14px;
}
.btn-save:hover { background: #3aef7a; }
.btn-secondary {
    background: #20202a;
    color: #c8c8d8;
    border-radius: 8px;
    border: 1px solid #33334a;
    font-size: 11px;
    padding: 3px 8px;
}
.btn-secondary:hover { background: #2a2a3a; }
.btn-cat {
    background: #1d2b53;
    color: #c8c8d8;
    border-radius: 8px;
    border: 1px solid #29366f;
    font-size: 11px;
    padding: 3px 8px;
}
.btn-cat:hover { background: #29366f; }
.btn-cat-active {
    background: #7b5ea7;
    color: #ffffff;
    border-radius: 8px;
    border: 1px solid #9b7ec7;
    font-size: 11px;
    font-weight: bold;
    padding: 3px 8px;
}
.btn-danger {
    background: #7e1525;
    color: #ffb8c0;
    border-radius: 8px;
    border: 1px solid #ff004d;
    font-size: 11px;
    padding: 3px 8px;
}
.btn-danger:hover { background: #a01c30; }
.btn-add {
    background: #1a2a1a;
    color: #1ed760;
    border-radius: 8px;
    border: 1px solid #1ed760;
    font-size: 11px;
    padding: 3px 8px;
}
.btn-add:hover { background: #1e3a1e; }
.row-new {
    color: #1ebdd1;
    font-size: 9px;
    font-weight: bold;
}
.row-suggest {
    color: #ffec27;
    font-size: 9px;
    font-weight: bold;
}
.btn-link {
    background: transparent;
    color: #4a8fa8;
    border-radius: 6px;
    border: 1px solid #253040;
    font-size: 10px;
    padding: 1px 6px;
}
.btn-link:hover { color: #1ebdd1; border-color: #1ebdd1; }
list { background-color: transparent; }
listbox row { background-color: transparent; }
listbox row:selected { background-color: transparent; }
"""

# ── Favourites parser ─────────────────────────────────────────────────────────
def parse_entry(raw_line):
    """Parse a pipe-delimited favourites line. Returns dict or None."""
    line = raw_line.rstrip("\n")
    if not line.startswith("|"):
        return None
    parts = line.split("|")
    if len(parts) < 6:
        return None
    slug = parts[1].strip()
    base = parts[2].strip()   # base slug (no -N) for named; cart ID for numeric
    return {
        "raw":    line,
        "slug":   slug,
        "base":   base,
        "author": parts[4].strip(),
        "title":  parts[6].strip() if len(parts) > 6 else base,
    }

DIVIDER_RE = re.compile(r"^#\s*={3,}")
CAT_RE     = re.compile(r"^#\s*([A-Z][^\n]*)$")

def parse_favourites(filepath):
    """
    Returns:
      sections  – dict: category_name (str) → [entry_dict, ...]
                  ordered by appearance in file
      cat_order – list of category names in file order
      unsorted  – [entry_dict, ...] entries before any # header
    """
    sections  = {}
    cat_order = []
    unsorted  = []
    current   = None

    with open(filepath, encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        line = lines[i].rstrip("\n")

        if DIVIDER_RE.match(line):
            # Consume divider block — next non-divider # line is the name
            i += 1
            while i < len(lines):
                ln = lines[i].rstrip("\n")
                if DIVIDER_RE.match(ln):
                    i += 1
                    continue
                m = CAT_RE.match(ln)
                if m:
                    cat = m.group(1).strip()
                    if cat not in sections:
                        sections[cat]  = []
                        cat_order.append(cat)
                    current = cat
                    i += 1
                break
            continue

        if line.startswith("#") or line.strip() == "":
            i += 1
            continue

        entry = parse_entry(line)
        if entry:
            if current is not None:
                sections[current].append(entry)
            else:
                unsorted.append(entry)
        i += 1

    return sections, cat_order, unsorted

def write_favourites(filepath, categories, sections, unsorted):
    """Write sorted favourites. Keeps exactly one .bak file — overwrites previous.

    File format:
      - Unsorted entries (raw, no header) written first — exactly as PICO-8
        would prepend them.
      - Named category sections follow, each wrapped in # === / # NAME / # ===.
      - The internal "UNSORTED" bucket is merged with unsorted and written raw.
    """
    backup = filepath + ".bak"

    # Remove old backup before writing new one (keep exactly one)
    if os.path.exists(backup):
        os.remove(backup)
    shutil.copy2(filepath, backup)

    out = []

    # Unsorted entries — raw at the top, no header (matches PICO-8 behaviour)
    remaining = list(unsorted) + sections.get("UNSORTED", [])
    for e in remaining:
        out.append(e["raw"])
    if remaining:
        out.append("")

    # Named category sections — always write the header so empty categories
    # survive a save/reload cycle. PICO-8 ignores headerless gaps; omitting
    # the header would silently drop the category from the file on next save.
    for cat in categories:
        if cat == "UNSORTED":
            continue
        entries = sections.get(cat, [])
        out.append("# " + "=" * 60)
        out.append(f"# {cat}")
        out.append("# " + "=" * 60)
        out.append("")
        for e in entries:
            out.append(e["raw"])
        out.append("")

    tmp = filepath + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    os.replace(tmp, filepath)

    return backup

BBS_ALLOWED_PREFIX = "https://www.lexaloffle.com/bbs/?pid="

def bbs_url(entry):
    """Return the Lexaloffle BBS URL for an entry.
    Named carts: use base slug (parts[2]) directly — already has no -N suffix.
    Numeric/legacy carts: same field (parts[2]) is the cart post ID.
    Either way, entry['base'] is the correct pid value.
    """
    return BBS_ALLOWED_PREFIX + entry["base"]

# ── BBS tag → category map ────────────────────────────────────────────────────
# Maps BBS genre tags (as returned by Lexaloffle) to local category names.
# First match wins. Only maps to categories that exist in DEFAULT_CATEGORIES.
# Common PICO-8 BBS tags sourced from https://www.lexaloffle.com/bbs/?cat=7
TAG_TO_CAT = {
    # Roguelikes / Dungeon Crawlers
    "roguelike":        "ROGUELIKES / DUNGEON CRAWLERS",
    "dungeon-crawler":  "ROGUELIKES / DUNGEON CRAWLERS",
    "dungeon":          "ROGUELIKES / DUNGEON CRAWLERS",
    "rogue":            "ROGUELIKES / DUNGEON CRAWLERS",
    "turn-based":       "ROGUELIKES / DUNGEON CRAWLERS",
    "strategy":         "ROGUELIKES / DUNGEON CRAWLERS",
    "rpg":              "ROGUELIKES / DUNGEON CRAWLERS",
    "top-down":         "ROGUELIKES / DUNGEON CRAWLERS",
    # Shooters / Space Games
    "shooter":          "SHOOTERS / SPACE GAMES",
    "shoot-em-up":      "SHOOTERS / SPACE GAMES",
    "shmup":            "SHOOTERS / SPACE GAMES",
    "bullet-hell":      "SHOOTERS / SPACE GAMES",
    "space":            "SHOOTERS / SPACE GAMES",
    "arcade":           "SHOOTERS / SPACE GAMES",
    "action":           "SHOOTERS / SPACE GAMES",
    # Puzzle Games
    "puzzle":           "PUZZLE GAMES",
    "sokoban":          "PUZZLE GAMES",
    "tile-based":       "PUZZLE GAMES",
    "match-3":          "PUZZLE GAMES",
    "logic":            "PUZZLE GAMES",
    "block":            "PUZZLE GAMES",
    # Racing / Flying / Action
    "racing":           "RACING / FLYING / ACTION",
    "driving":          "RACING / FLYING / ACTION",
    "flying":           "RACING / FLYING / ACTION",
    "flight":           "RACING / FLYING / ACTION",
    "fighting":         "RACING / FLYING / ACTION",
    "brawler":          "RACING / FLYING / ACTION",
    # Platformers / Adventure
    "platformer":       "PLATFORMERS / ADVENTURE",
    "platform":         "PLATFORMERS / ADVENTURE",
    "adventure":        "PLATFORMERS / ADVENTURE",
    "exploration":      "PLATFORMERS / ADVENTURE",
    "metroidvania":     "PLATFORMERS / ADVENTURE",
    "run-and-gun":      "PLATFORMERS / ADVENTURE",
    "runner":           "PLATFORMERS / ADVENTURE",
    # Atmospheric / Walking Sims / Narrative
    "narrative":        "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "story":            "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "visual-novel":     "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "walking-sim":      "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "atmospheric":      "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "horror":           "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    "art":              "ATMOSPHERIC / WALKING SIMS / NARRATIVE",
    # Music / Demoscene
    "music":            "MUSIC / DEMOSCENE",
    "rhythm":           "MUSIC / DEMOSCENE",
    "demoscene":        "MUSIC / DEMOSCENE",
    "demo":             "MUSIC / DEMOSCENE",
    "chiptune":         "MUSIC / DEMOSCENE",
    "audio":            "MUSIC / DEMOSCENE",
    # Clocks / Utilities / Toys
    "tool":             "CLOCKS / UTILITIES / TOYS",
    "utility":          "CLOCKS / UTILITIES / TOYS",
    "toy":              "CLOCKS / UTILITIES / TOYS",
    "clock":            "CLOCKS / UTILITIES / TOYS",
    "screensaver":      "CLOCKS / UTILITIES / TOYS",
    "generator":        "CLOCKS / UTILITIES / TOYS",
    "sandbox":          "CLOCKS / UTILITIES / TOYS",
}

def fetch_bbs_tags(pid):
    """Fetch genre tags for one cart from the Lexaloffle BBS.
    Returns list of tag strings, or [] on any error.
    Network call — must be run off the GTK main thread.
    """
    url = BBS_ALLOWED_PREFIX + pid
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (compatible; pico8-fav-sorter)"})
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            html = r.read().decode("utf-8", errors="replace")
        return re.findall(r'<span class="tag">(.*?)</span>', html)
    except Exception:
        return []

def bbs_tags_to_category(tags, categories):
    """Map a list of BBS tags to the first matching local category, or None."""
    for tag in tags:
        cat = TAG_TO_CAT.get(tag.lower())
        if cat and cat in categories:
            return cat
    return None

# ── New category suggestion maps ──────────────────────────────────────────────
# Tags/keywords that don't map to DEFAULT_CATEGORIES — used to propose entirely
# new categories when enough entries (MIN_SUGGEST = 3) share a theme.
# Tag label → proposed category name (UPPER, will be auto-upcased anyway).
TAG_TO_NEW_CAT = {
    # Horror as its own category (currently lumped into Atmospheric)
    "horror":           "HORROR",
    "survival-horror":  "HORROR",
    # Sports
    "sports":           "SPORTS",
    "football":         "SPORTS",
    "soccer":           "SPORTS",
    "basketball":       "SPORTS",
    "baseball":         "SPORTS",
    "golf":             "SPORTS",
    "tennis":           "SPORTS",
    # Card / Board / Tabletop
    "card-game":        "CARD & BOARD GAMES",
    "board-game":       "CARD & BOARD GAMES",
    "tabletop":         "CARD & BOARD GAMES",
    "deck-building":    "CARD & BOARD GAMES",
    "poker":            "CARD & BOARD GAMES",
    "chess":            "CARD & BOARD GAMES",
    # Tower Defence
    "tower-defense":    "TOWER DEFENCE",
    "tower-defence":    "TOWER DEFENCE",
    "td":               "TOWER DEFENCE",
    # Simulation
    "simulation":       "SIMULATION",
    "sim":              "SIMULATION",
    "city-builder":     "SIMULATION",
    "farming":          "SIMULATION",
    "management":       "SIMULATION",
    # Multiplayer / Co-op
    "multiplayer":      "MULTIPLAYER",
    "co-op":            "MULTIPLAYER",
    "2-player":         "MULTIPLAYER",
    "local-multiplayer":"MULTIPLAYER",
    # Idle / Clicker
    "idle":             "IDLE & CLICKER",
    "clicker":          "IDLE & CLICKER",
    "incremental":      "IDLE & CLICKER",
    # Rhythm
    "rhythm":           "RHYTHM",
    "dance":            "RHYTHM",
    # Metroidvania
    "metroidvania":     "METROIDVANIA",
}

# Keyword fragments matched against entry titles (lower) → proposed category.
# Kept separate from TAG_TO_NEW_CAT — keywords are fuzzier than BBS tags.
KEYWORD_TO_NEW_CAT = {
    "horror":    "HORROR",
    "zombie":    "HORROR",
    "haunt":     "HORROR",
    "creep":     "HORROR",
    "scary":     "HORROR",
    "terror":    "HORROR",
    "sport":     "SPORTS",
    "soccer":    "SPORTS",
    "footbal":   "SPORTS",
    "basket":    "SPORTS",
    "tennis":    "SPORTS",
    "golf":      "SPORTS",
    "chess":     "CARD & BOARD GAMES",
    "poker":     "CARD & BOARD GAMES",
    "card":      "CARD & BOARD GAMES",
    "tower def": "TOWER DEFENCE",
    "idle":      "IDLE & CLICKER",
    "clicker":   "IDLE & CLICKER",
    "farm":      "SIMULATION",
    "simul":     "SIMULATION",
    "tycoon":    "SIMULATION",
    "manage":    "SIMULATION",
    "rhythm":    "RHYTHM",
    "groove":    "RHYTHM",
    "metroidvania": "METROIDVANIA",
}

MIN_SUGGEST = 3  # minimum entries sharing a theme before suggesting a new category

def suggest_new_categories(entries, existing_categories):
    """Scan entries for themes not covered by existing categories.
    Returns dict: proposed_cat_name → [entry, ...] for groups >= MIN_SUGGEST.
    Uses keyword title matching only (no network). BBS tags passed in separately
    via the cached tags dict from a prior fetch.
    """
    from collections import defaultdict
    buckets = defaultdict(list)
    existing_upper = {c.upper() for c in existing_categories}

    for entry in entries:
        title = entry["title"].lower()
        matched = None
        for kw, proposed in KEYWORD_TO_NEW_CAT.items():
            if kw in title and proposed.upper() not in existing_upper:
                matched = proposed.upper()
                break
        if matched:
            buckets[matched].append(entry)

    return {cat: ents for cat, ents in buckets.items() if len(ents) >= MIN_SUGGEST}

def suggest_new_categories_from_tags(tag_cache, existing_categories):
    """Same as above but uses a pre-fetched tag_cache dict:
    entry_id → [tag, ...] (from a prior BBS fetch in the suggest dialog).
    Returns dict: proposed_cat_name → [entry, ...] for groups >= MIN_SUGGEST.
    """
    from collections import defaultdict
    buckets = defaultdict(list)
    existing_upper = {c.upper() for c in existing_categories}

    for entry_id, (entry, tags) in tag_cache.items():
        for tag in tags:
            proposed = TAG_TO_NEW_CAT.get(tag.lower())
            if proposed and proposed.upper() not in existing_upper:
                buckets[proposed.upper()].append(entry)
                break  # one tag match per entry per category is enough

    return {cat: ents for cat, ents in buckets.items() if len(ents) >= MIN_SUGGEST}


# Maps category name → list of keyword fragments matched against title (lower).
# Author fragments are matched against author field (lower).
# First matching category wins — order matters for overlapping keywords.
# User can edit this after Install by modifying ~/.local/bin/pico8-fav-sorter
# (or re-run Repair to reset to defaults).
AUTO_SORT_RULES = [
    ("CURRENT FAVORITES", {
        "titles":  [],
        "authors": [],
    }),
    ("ROGUELIKES / DUNGEON CRAWLERS", {
        "titles":  ["rogue", "dungeon", "crawl", "rl", "nethack", "spelunk",
                    "tomb", "crypt", "lich", "undead", "dwarf", "descent"],
        "authors": [],
    }),
    ("SHOOTERS / SPACE GAMES", {
        "titles":  ["shoot", "bullet", "shmup", "space", "galaxy", "star",
                    "asteroid", "invader", "blaster", "laser", "alien", "ufo",
                    "turret", "missile", "jet", "pilot"],
        "authors": [],
    }),
    ("PUZZLE GAMES", {
        "titles":  ["puzzle", "block", "match", "slide", "sokoban", "tetris",
                    "swap", "connect", "logic", "nonogram", "picross",
                    "sudoku", "flow", "pipe"],
        "authors": [],
    }),
    ("RACING / FLYING / ACTION", {
        "titles":  ["race", "racing", "drift", "kart", "drive", "speed",
                    "fly", "flight", "wing", "bird", "brawl", "fight",
                    "combat", "action", "beat"],
        "authors": [],
    }),
    ("PLATFORMERS / ADVENTURE", {
        "titles":  ["jump", "platform", "adventure", "quest", "explore",
                    "hero", "knight", "castle", "world", "land", "island",
                    "climb", "run", "escape", "maze"],
        "authors": [],
    }),
    ("ATMOSPHERIC / WALKING SIMS / NARRATIVE", {
        "titles":  ["walk", "wander", "story", "narrative", "visual novel",
                    "atmospheric", "calm", "relax", "ambient", "drift",
                    "dream", "memory", "journal", "letter"],
        "authors": [],
    }),
    ("MUSIC / DEMOSCENE", {
        "titles":  ["music", "song", "beat", "drum", "synth", "audio",
                    "sound", "demo", "chip", "tracker", "melody", "jukebox",
                    "radio", "concert"],
        "authors": [],
    }),
    ("CLOCKS / UTILITIES / TOYS", {
        "titles":  ["clock", "watch", "timer", "util", "tool", "toy",
                    "sandbox", "screensaver", "paint", "draw", "sketch",
                    "generator", "test", "demo"],
        "authors": [],
    }),
    # ── Dormant until the matching category is actually added via Suggest
    # Categories (auto_suggest_category's "cat_name not in categories: skip"
    # guard makes these inert otherwise). Kept in sync with TAG_TO_NEW_CAT /
    # KEYWORD_TO_NEW_CAT above.
    ("HORROR", {
        "titles":  ["horror", "scary", "fear", "creepy", "nightmare",
                    "haunt", "ghost", "zombie", "slasher", "dread"],
        "authors": [],
    }),
    ("SPORTS", {
        "titles":  ["sport", "soccer", "football", "basket", "baseball",
                    "bowling", "hockey", "tennis", "golf", "pinball"],
        "authors": [],
    }),
    ("CARD & BOARD GAMES", {
        "titles":  ["card", "poker", "solitaire", "chess", "checkers",
                     "board", "dice", "tabletop", "deck"],
        "authors": [],
    }),
    ("TOWER DEFENCE", {
        "titles":  ["tower defense", "tower defence", "tower def"],
        "authors": [],
    }),
    ("SIMULATION", {
        "titles":  ["tycoon", "theme", "city", "manage", "farm",
                    "delivery", "trade", "mining", "factory", "colony"],
        "authors": [],
    }),
    ("MULTIPLAYER", {
        "titles":  ["multiplayer", "co-op", "2 player", "2-player"],
        "authors": [],
    }),
    ("IDLE & CLICKER", {
        "titles":  ["idle", "clicker", "incremental", "afk", "autoclick"],
        "authors": [],
    }),
    ("RHYTHM", {
        "titles":  ["rhythm", "dance", "groove", "metronome", "disco"],
        "authors": [],
    }),
    ("METROIDVANIA", {
        "titles":  ["metroidvania", "vania"],
        "authors": [],
    }),
]

def auto_suggest_category(entry, categories):
    """Return the best matching category name for an entry, or None.
    Checks title keywords first, then author keywords.
    Only suggests categories that exist in the current category list.
    """
    title  = entry["title"].lower()
    author = entry["author"].lower()
    for cat_name, rules in AUTO_SORT_RULES:
        if cat_name not in categories:
            continue
        for kw in rules["titles"]:
            if kw in title:
                return cat_name
        for kw in rules["authors"]:
            if kw in author:
                return cat_name
    return None

def suggest_author_categories(entries, existing_categories):
    """Cluster entries by author, proposing '<AUTHOR> COLLECTION' for any
    author with >= MIN_SUGGEST works not already covered by an existing
    category of that name. Skips authors that already have a matching
    "<NAME> COLLECTION" category (e.g. MOT COLLECTION)."""
    from collections import defaultdict
    buckets = defaultdict(list)
    existing_upper = {c.upper() for c in existing_categories}
    for e in entries:
        author = e["author"].strip()
        if not author:
            continue
        proposed = f"{author.upper()} COLLECTION"
        if proposed in existing_upper:
            continue
        buckets[proposed].append(e)
    return {cat: ents for cat, ents in buckets.items() if len(ents) >= MIN_SUGGEST}

# ── Duplicate detection ───────────────────────────────────────────────────────
_SLUG_REV_RE = re.compile(r"^(.*)-(\d+)$")

def _dup_sort_key(e):
    """Best-effort revision ordering: slugs with a numeric -N suffix are
    later re-exports of the same base cart, higher N = newer. Unsuffixed
    slugs sort as revision -1 (the original)."""
    m = _SLUG_REV_RE.match(e["slug"])
    if m:
        return (m.group(1), int(m.group(2)))
    return (e["slug"], -1)

def find_duplicate_groups(all_entries):
    """Group entries that look like duplicates/revisions of each other.
      1. Exact base-slug match (same cart, different -N revision suffix) —
         a true "revision" group: slug -N ordering gives a real newest-wins
         signal, so entries are sorted newest-first.
      2. Fuzzy author+title match (same author, same title, different slug —
         catches a re-favourited/re-uploaded cart with a brand new BBS id).
         There's no reliable "newest" signal here (different carts entirely,
         no timestamp in favourites.txt) — order is deterministic but NOT
         a recency guarantee.
    Returns a list of dicts: {"entries": [...], "kind": "revision"|"fuzzy"}.
    Uses `e.get("base") or e["slug"]` rather than `.get("base", e["slug"])` —
    parse_entry always sets "base" (possibly to "" on a malformed column),
    and dict.get()'s default only triggers when the key is absent, not when
    it's present-but-falsy, so the naive version silently over-groups.
    """
    from collections import defaultdict
    by_base = defaultdict(list)
    for e in all_entries:
        key = e.get("base") or e["slug"]
        by_base[key].append(e)
    groups = []
    grouped_ids = set()
    for g in by_base.values():
        if len(g) > 1:
            g.sort(key=_dup_sort_key, reverse=True)  # newest revision first
            groups.append({"entries": g, "kind": "revision"})
            grouped_ids.update(id(e) for e in g)

    by_at = defaultdict(list)
    for e in all_entries:
        if id(e) in grouped_ids:
            continue
        key = (e["author"].strip().lower(), e["title"].strip().lower())
        if key[0] and key[1]:
            by_at[key].append(e)
    for g in by_at.values():
        if len(g) > 1:
            groups.append({"entries": g, "kind": "fuzzy"})
    return groups

# ── Master category JSON — recovery + portable backup ────────────────────────
# Persists slug -> last-known category alongside favourites.txt so manual
# organisation survives PICO-8 (or a manual edit) stripping category headers,
# and so the assignments can be carried to another device's favourites.txt.
def master_json_path(filepath):
    return filepath + ".master.json"

def load_master(filepath):
    try:
        with open(master_json_path(filepath), encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def save_master(filepath, master):
    path = master_json_path(filepath)
    tmp = path + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(master, f, indent=2, sort_keys=True)
        os.replace(tmp, path)
    except Exception:
        pass

def set_master_category_for_entries(filepath, entries, cat_name):
    """Immediately persist cat_name for these entries' slugs. Called right
    after assign/rename/delete so a PICO-8 strip mid-session can't
    resurrect a just-undone assignment via reconcile_stripped_categories."""
    if not filepath:
        return
    master = load_master(filepath)
    now = datetime.now().isoformat(timespec="seconds")
    for e in entries:
        master[e["slug"]] = {
            "cat": cat_name, "title": e["title"], "author": e["author"],
            "base": e["base"], "ts": now,
        }
    save_master(filepath, master)

def reconcile_stripped_categories(filepath, sections, unsorted, categories):
    """Restore entries currently sitting in Unsorted to their last-known
    category via the master JSON, when that category still exists.
    Returns (sections, still_unsorted, recovered_count)."""
    master = load_master(filepath)
    if not master:
        return sections, unsorted, 0
    recovered = 0
    still_unsorted = []
    for e in unsorted:
        rec = master.get(e["slug"])
        target = rec.get("cat") if rec else None
        if target and target != "UNSORTED" and target in categories:
            sections.setdefault(target, []).append(e)
            recovered += 1
        else:
            still_unsorted.append(e)
    return sections, still_unsorted, recovered

def export_master_list(filepath, dest_path):
    """Copy the master JSON to dest_path for transfer to another device."""
    master = load_master(filepath)
    with open(dest_path, "w", encoding="utf-8") as f:
        json.dump(master, f, indent=2, sort_keys=True)
    return len(master)

def import_merge_master_list(filepath, src_path):
    """Merge an imported master JSON into the current one. Newer timestamp
    per slug wins on conflict. Returns count of slugs added/updated."""
    try:
        with open(src_path, encoding="utf-8") as f:
            incoming = json.load(f)
    except Exception as ex:
        raise ValueError(f"Could not read master list:\n{ex}")
    current = load_master(filepath)
    changed = 0
    for slug, rec in incoming.items():
        existing = current.get(slug)
        if not existing or rec.get("ts", "") >= existing.get("ts", ""):
            current[slug] = rec
            changed += 1
    save_master(filepath, current)
    return changed

# ── Main window ───────────────────────────────────────────────────────────────
class FavSorterWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="PICO-8 Favourites Sorter")
        self.set_default_size(796, 460)
        self.set_size_request(776, 360)
        self.set_resizable(True)
        self.connect("delete-event", self._on_delete_event)

        # Apply CSS
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # App state
        self._filepath   = None
        self._sections   = {}
        self._cat_order  = []
        self._unsorted   = []
        self._categories = list(DEFAULT_CATEGORIES)
        self._sel_entry  = None
        self._sel_cat    = None
        self._sel_row_widget = None
        self._browse_mode   = False
        self._all_sort_col  = 0
        self._all_sort_asc  = True
        self._all_filter    = ""
        self._dirty         = False   # unsaved changes flag
        self._last_path     = None    # persisted across sessions via config
        self._cat_sort_state = {}     # cat → (col: 0=title,1=author,2=auth+title, asc: bool)
        self._new_slugs      = set()  # slugs that were unsorted when file was opened
        self._last_acted_slug = None  # slug of last moved/acted entry for scroll restore

        # Load config (last opened path)
        self._load_config()

        self._build_ui()

        # Esc deselects the current entry without moving it
        self.connect("key-press-event", self._on_key_press)

        # Auto-open last file if it still exists
        if self._last_path and os.path.isfile(self._last_path):
            GLib.idle_add(self._load_file, self._last_path)

    # ── UI construction ───────────────────────────────────────────────────────
    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.set_margin_top(8)
        root.set_margin_bottom(8)
        root.set_margin_start(10)
        root.set_margin_end(10)
        self.add(root)

        # ── Title bar ─────────────────────────────────────────────────────────
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        t = Gtk.Label(label="PICO-8 Favourites Sorter", xalign=0)
        t.get_style_context().add_class("header-title")
        title_box.pack_start(t, False, False, 0)
        self._status_lbl = Gtk.Label(label="Open a favourites.txt to begin.", xalign=0)
        self._status_lbl.get_style_context().add_class("status-msg")
        self._status_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        title_box.pack_start(self._status_lbl, False, False, 0)
        self._total_lbl = Gtk.Label(label="", xalign=0)
        self._total_lbl.get_style_context().add_class("header-sub")
        title_box.pack_start(self._total_lbl, False, False, 0)
        top.pack_start(title_box, True, True, 0)

        open_btn = Gtk.Button(label="📂  Open File")
        open_btn.get_style_context().add_class("btn-secondary")
        open_btn.set_size_request(0, 44)
        open_btn.connect("clicked", self._on_open)
        top.pack_start(open_btn, False, False, 0)

        self._open_default_btn = Gtk.Button(label="⭐  Open Default")
        self._open_default_btn.get_style_context().add_class("btn-primary")
        self._open_default_btn.set_size_request(0, 44)
        self._open_default_btn.set_sensitive(os.path.isfile(DEFAULT_FAV))
        self._open_default_btn.connect("clicked", self._on_open_default)
        top.pack_start(self._open_default_btn, False, False, 0)

        self._save_btn = Gtk.Button(label="💾  Save File")
        self._save_btn.get_style_context().add_class("btn-save")
        self._save_btn.set_size_request(0, 44)
        self._save_btn.set_sensitive(False)
        self._save_btn.connect("clicked", self._on_save)
        top.pack_start(self._save_btn, False, False, 0)

        root.pack_start(top, False, False, 0)

        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep.set_margin_top(6)
        sep.set_margin_bottom(6)
        root.pack_start(sep, False, False, 0)

        # ── Three-column body ─────────────────────────────────────────────────
        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        body.set_vexpand(True)
        root.pack_start(body, True, True, 0)

        # ── LEFT: unsorted / all-entries toggle column ────────────────────────
        left_wrap = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        left_wrap.set_size_request(300, -1)
        left_wrap.get_style_context().add_class("panel")
        left_wrap.set_margin_top(2); left_wrap.set_margin_bottom(2)

        # Toggle button row
        tog_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        tog_box.set_margin_top(8); tog_box.set_margin_start(8); tog_box.set_margin_end(8)
        self._tog_unsorted_btn = Gtk.Button(label="NEW / UNSORTED (0)")
        self._tog_unsorted_btn.get_style_context().add_class("btn-cat-active")
        self._tog_unsorted_btn.set_size_request(0, 44)
        self._tog_unsorted_btn.connect("clicked", self._on_toggle_browse, False)
        tog_box.pack_start(self._tog_unsorted_btn, True, True, 0)
        self._tog_all_btn = Gtk.Button(label="ALL ENTRIES")
        self._tog_all_btn.get_style_context().add_class("btn-cat")
        self._tog_all_btn.set_size_request(0, 44)
        self._tog_all_btn.connect("clicked", self._on_toggle_browse, True)
        tog_box.pack_start(self._tog_all_btn, True, True, 0)
        left_wrap.pack_start(tog_box, False, False, 0)

        # Dynamic count label
        self._unsorted_count = Gtk.Label(label="0 entries", xalign=0)
        self._unsorted_count.get_style_context().add_class("header-sub")
        self._unsorted_count.set_margin_start(10)
        left_wrap.pack_start(self._unsorted_count, False, False, 0)

        # Sort bar (all-entries mode only)
        self._sort_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
        self._sort_bar.set_margin_start(6); self._sort_bar.set_margin_end(6)
        self._sort_bar.set_margin_bottom(2)
        sort_lbl = Gtk.Label(label="Sort:")
        sort_lbl.get_style_context().add_class("row-meta")
        self._sort_bar.pack_start(sort_lbl, False, False, 0)
        self._sort_btns = []
        for i, col_name in enumerate(["Name", "Author", "Category"]):
            sb = Gtk.Button(label=col_name)
            sb.get_style_context().add_class("btn-secondary")
            sb.set_size_request(0, 30)
            sb.connect("clicked", self._on_all_sort_clicked, i)
            self._sort_bar.pack_start(sb, True, True, 0)
            self._sort_btns.append(sb)
        # Filter entry
        self._all_filter_entry = Gtk.Entry()
        self._all_filter_entry.set_placeholder_text("Filter...")
        self._all_filter_entry.set_size_request(0, 30)
        self._all_filter_entry.connect("changed", self._on_all_filter_changed)
        self._sort_bar.pack_start(self._all_filter_entry, True, True, 0)
        left_wrap.pack_start(self._sort_bar, False, False, 0)
        self._sort_bar.set_no_show_all(True)
        self._sort_bar.hide()

        # List
        lscroll = Gtk.ScrolledWindow()
        lscroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        lscroll.set_vexpand(True)
        self._unsorted_lb = Gtk.ListBox()
        self._unsorted_lb.set_selection_mode(Gtk.SelectionMode.NONE)
        self._unsorted_lb.connect("row-activated", self._on_left_activated)
        lscroll.add(self._unsorted_lb)
        left_wrap.pack_start(lscroll, True, True, 0)

        self._left_hint = Gtk.Label(label="Click entry, then a category →", xalign=0)
        self._left_hint.get_style_context().add_class("header-sub")
        self._left_hint.set_margin_start(10); self._left_hint.set_margin_bottom(8)
        left_wrap.pack_start(self._left_hint, False, False, 0)

        body.pack_start(left_wrap, False, False, 0)

        # ── CENTRE: Actions popover button + scrollable category list ────────────
        mid = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        mid.set_size_request(190, -1)
        mid.get_style_context().add_class("panel")
        mid.set_margin_top(2); mid.set_margin_bottom(2)

        # ── Actions popover button (top) ──────────────────────────────────────
        actions_btn = Gtk.Button(label="\u2699 Actions \u25be")
        actions_btn.get_style_context().add_class("btn-primary")
        actions_btn.set_size_request(0, 44)
        actions_btn.set_margin_top(8)
        actions_btn.set_margin_start(6); actions_btn.set_margin_end(6)
        mid.pack_start(actions_btn, False, False, 0)

        pop = Gtk.Popover()
        pop.set_relative_to(actions_btn)
        pop.set_position(Gtk.PositionType.BOTTOM)

        pop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        pop_box.set_margin_top(8); pop_box.set_margin_bottom(8)
        pop_box.set_margin_start(8); pop_box.set_margin_end(8)

        def _pop_header(text):
            lbl = Gtk.Label(label=text, xalign=0)
            lbl.get_style_context().add_class("header-sub")
            lbl.set_margin_top(6); lbl.set_margin_bottom(2)
            return lbl

        def _pop_btn(label, cb, css="btn-secondary"):
            b = Gtk.Button(label=label)
            b.get_style_context().add_class(css)
            b.set_size_request(0, 44)
            b.set_margin_start(2); b.set_margin_end(2)
            def _on_clicked(widget, _cb=cb):
                pop.popdown()
                _cb(widget)
            b.connect("clicked", _on_clicked)
            return b

        def _pop_row(btn_a, btn_b):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            row.pack_start(btn_a, True, True, 0)
            row.pack_start(btn_b, True, True, 0)
            return row

        # ── Active category context label ─────────────────────────────────────
        # Updated each time the popover opens so the user knows which category
        # the cat-specific actions will apply to.
        _pop_cat_lbl = Gtk.Label(xalign=0)
        _pop_cat_lbl.get_style_context().add_class("header-sub")
        _pop_cat_lbl.set_margin_bottom(4)
        _pop_cat_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        pop_box.pack_start(_pop_cat_lbl, False, False, 0)

        sep_top = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep_top.set_margin_bottom(2)
        pop_box.pack_start(sep_top, False, False, 0)

        # ── CATEGORY ─────────────────────────────────────────────────────────
        pop_box.pack_start(_pop_header("CATEGORY"), False, False, 0)
        pop_box.pack_start(_pop_btn("\uff0b Add Category",      self._on_add_category,    "btn-add"),      False, False, 0)
        _btn_rename = _pop_btn("\u270f Rename Category",   self._on_rename_category, "btn-secondary")
        pop_box.pack_start(_btn_rename, False, False, 0)
        # ── Category position stepper — stays open, updates live ──────────────
        stepper_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        stepper_box.set_margin_start(2); stepper_box.set_margin_end(2)

        _btn_cat_up = Gtk.Button(label="\u2b06 Up")
        _btn_cat_up.get_style_context().add_class("btn-secondary")
        _btn_cat_up.set_size_request(0, 44)

        _stepper_lbl = Gtk.Label(xalign=0.5)
        _stepper_lbl.get_style_context().add_class("header-sub")
        _stepper_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        _stepper_lbl.set_margin_top(2); _stepper_lbl.set_margin_bottom(2)

        _btn_cat_dn = Gtk.Button(label="\u2b07 Down")
        _btn_cat_dn.get_style_context().add_class("btn-secondary")
        _btn_cat_dn.set_size_request(0, 44)

        stepper_box.pack_start(_btn_cat_up,    False, False, 0)
        stepper_box.pack_start(_stepper_lbl,   False, False, 0)
        stepper_box.pack_start(_btn_cat_dn,    False, False, 0)
        pop_box.pack_start(stepper_box, False, False, 0)

        def _stepper_refresh():
            """Update stepper label with current position. Called after every move."""
            cat = self._sel_cat
            if not cat or cat not in self._categories:
                _stepper_lbl.set_markup(
                    '<span foreground="#50506a" size="small">—</span>')
                return
            idx   = self._categories.index(cat)
            total = len(self._categories)
            short = cat[:18] + "\u2026" if len(cat) > 18 else cat
            _stepper_lbl.set_markup(
                f'<span foreground="#1ebdd1" size="small">'
                f'{GLib.markup_escape_text(short)}</span>'
                f'  <span foreground="#50506a" size="small">'
                f'{idx + 1}/{total}</span>')
            _btn_cat_up.set_sensitive(idx > 0)
            _btn_cat_dn.set_sensitive(idx < total - 1)

        def _step_up(*_):
            if not self._sel_cat:
                return
            cats = self._categories
            try:
                idx = cats.index(self._sel_cat)
            except ValueError:
                return
            if idx <= 0:
                return
            cats[idx], cats[idx - 1] = cats[idx - 1], cats[idx]
            self._rebuild_cat_buttons()
            self._mark_dirty()
            _stepper_refresh()

        def _step_down(*_):
            if not self._sel_cat:
                return
            cats = self._categories
            try:
                idx = cats.index(self._sel_cat)
            except ValueError:
                return
            if idx >= len(cats) - 1:
                return
            cats[idx], cats[idx + 1] = cats[idx + 1], cats[idx]
            self._rebuild_cat_buttons()
            self._mark_dirty()
            _stepper_refresh()

        _btn_cat_up.connect("clicked", _step_up)
        _btn_cat_dn.connect("clicked", _step_down)
        _btn_del_cat  = _pop_btn("\U0001f5d1 Delete Category", self._on_delete_category, "btn-danger")
        pop_box.pack_start(_btn_del_cat, False, False, 0)

        # ── ENTRY ─────────────────────────────────────────────────────────────
        sep_e = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep_e.set_margin_top(6); sep_e.set_margin_bottom(2)
        pop_box.pack_start(sep_e, False, False, 0)
        pop_box.pack_start(_pop_header("ENTRY"), False, False, 0)
        pop_box.pack_start(_pop_row(
            _pop_btn("\u2191 Entry Up",   self._on_move_up,   "btn-secondary"),
            _pop_btn("\u2193 Entry Down", self._on_move_down, "btn-secondary"),
        ), False, False, 0)
        pop_box.pack_start(_pop_btn("\u2192 Move to Category\u2026", self._on_move_to,      "btn-primary"),  False, False, 0)
        pop_box.pack_start(_pop_btn("\u2605 Add to Favourites",       self._on_add_to_favs, "btn-add"),      False, False, 0)
        pop_box.pack_start(_pop_btn("\u2715 Send to Unsorted",        self._on_remove,      "btn-danger"),   False, False, 0)
        pop_box.pack_start(_pop_btn("\U0001f5d1 Delete Game",         self._on_delete_game, "btn-danger"),   False, False, 0)

        # ── AUTO-SORT ─────────────────────────────────────────────────────────
        sep_a = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep_a.set_margin_top(6); sep_a.set_margin_bottom(2)
        pop_box.pack_start(sep_a, False, False, 0)
        pop_box.pack_start(_pop_header("AUTO"), False, False, 0)
        pop_box.pack_start(_pop_btn("\U0001f916 Auto-Sort Unsorted\u2026", self._on_auto_sort,           "btn-add"), False, False, 0)
        pop_box.pack_start(_pop_btn("\u2728 Suggest Categories\u2026",      self._on_suggest_categories, "btn-add"), False, False, 0)
        pop_box.pack_start(_pop_btn("\U0001f50e Find Duplicates\u2026",     self._on_find_duplicates,    "btn-secondary"), False, False, 0)

        # ── FILE ─────────────────────────────────────────────────────────────
        sep_f = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep_f.set_margin_top(6); sep_f.set_margin_bottom(2)
        pop_box.pack_start(sep_f, False, False, 0)
        pop_box.pack_start(_pop_header("FILE"), False, False, 0)
        pop_box.pack_start(_pop_btn("\u21ba Reload (Discard Changes)", self._on_reload, "btn-danger"), False, False, 0)
        pop_box.pack_start(_pop_btn("\u2b06 Export Master List\u2026", self._on_export_master, "btn-secondary"), False, False, 0)
        pop_box.pack_start(_pop_btn("\u2b07 Import Master List\u2026", self._on_import_master, "btn-secondary"), False, False, 0)

        # ── SORT CATEGORY ─────────────────────────────────────────────────────
        sep_s = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep_s.set_margin_top(6); sep_s.set_margin_bottom(2)
        pop_box.pack_start(sep_s, False, False, 0)
        pop_box.pack_start(_pop_header("SORT CATEGORY"), False, False, 0)
        self._cat_sort_btns = {}
        for col_idx, short_label in [(0, "By Title"), (1, "By Author"), (2, "Author + Title")]:
            b = _pop_btn("\u21c5 " + short_label, lambda w, c=col_idx: self._on_sort_cat_col(w, c))
            self._cat_sort_btns[col_idx] = b
            pop_box.pack_start(b, False, False, 0)

        pop_box.show_all()
        # Wrap in ScrolledWindow so the popover never exceeds ~200x400px.
        # set_size_request on the ScrolledWindow constrains the Popover size.
        pop_scroll = Gtk.ScrolledWindow()
        pop_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        pop_scroll.set_size_request(190, 380)
        pop_scroll.add(pop_box)
        pop.add(pop_scroll)
        pop_scroll.show_all()

        def _on_pop_show(*_):
            """Refresh context label, stepper, and sensitivity each time popover opens."""
            cat = self._sel_cat
            has_cat = bool(cat)
            if has_cat:
                short = cat[:22] + "\u2026" if len(cat) > 22 else cat
                _pop_cat_lbl.set_markup(
                    f'<span foreground="#1ebdd1">\u25b6 {GLib.markup_escape_text(short)}</span>')
            else:
                _pop_cat_lbl.set_markup(
                    '<span foreground="#50506a">No category selected</span>')
            for btn in (_btn_rename, _btn_del_cat):
                btn.set_sensitive(has_cat)
            stepper_box.set_sensitive(has_cat)
            _stepper_refresh()

        pop.connect("show", _on_pop_show)
        actions_btn.connect("clicked", lambda *_: pop.popup())

        # ── CATEGORIES label + scrollable list ────────────────────────────────
        ct = Gtk.Label(label="CATEGORIES", xalign=0.5)
        ct.get_style_context().add_class("col-title")
        ct.set_margin_top(6)
        mid.pack_start(ct, False, False, 0)

        cat_scroll = Gtk.ScrolledWindow()
        cat_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        cat_scroll.set_vexpand(True)
        self._cat_btn_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        self._cat_btn_box.set_margin_start(4); self._cat_btn_box.set_margin_end(4)
        self._cat_btn_box.set_margin_bottom(6)
        cat_scroll.add(self._cat_btn_box)
        mid.pack_start(cat_scroll, True, True, 0)

        body.pack_start(mid, False, False, 0)

        # ── RIGHT: category viewer ────────────────────────────────────────────
        right_wrap = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        right_wrap.set_hexpand(True)
        right_wrap.get_style_context().add_class("panel")
        right_wrap.set_margin_top(2); right_wrap.set_margin_bottom(2)

        self._cat_title_lbl = Gtk.Label(label="SELECT A CATEGORY", xalign=0)
        self._cat_title_lbl.get_style_context().add_class("col-title")
        self._cat_title_lbl.set_margin_top(8); self._cat_title_lbl.set_margin_start(10)
        right_wrap.pack_start(self._cat_title_lbl, False, False, 0)

        self._cat_count_lbl = Gtk.Label(label="", xalign=0)
        self._cat_count_lbl.get_style_context().add_class("header-sub")
        self._cat_count_lbl.set_margin_start(10)
        right_wrap.pack_start(self._cat_count_lbl, False, False, 0)

        rscroll = Gtk.ScrolledWindow()
        rscroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        rscroll.set_vexpand(True)
        self._cat_lb = Gtk.ListBox()
        self._cat_lb.set_selection_mode(Gtk.SelectionMode.NONE)
        self._cat_lb.connect("row-activated", self._on_cat_entry_activated)
        rscroll.add(self._cat_lb)
        right_wrap.pack_start(rscroll, True, True, 0)

        body.pack_start(right_wrap, True, True, 0)

        self._rebuild_cat_buttons()
        self.show_all()

    # ── Row builder ───────────────────────────────────────────────────────────
    def _make_entry_row(self, entry, show_suggest=True):
        """Return a Gtk.ListBoxRow for one entry dict."""
        row = Gtk.ListBoxRow()
        row._entry = entry

        # Outer horizontal box: left info stack + right BBS button
        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        outer.set_margin_top(3); outer.set_margin_bottom(3)
        outer.set_margin_start(6); outer.set_margin_end(4)

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)

        title_lbl = Gtk.Label(label=entry["title"], xalign=0)
        title_lbl.get_style_context().add_class("row-title")
        title_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        card.pack_start(title_lbl, False, False, 0)

        meta_lbl = Gtk.Label(label=entry["author"], xalign=0)
        meta_lbl.get_style_context().add_class("row-meta")
        card.pack_start(meta_lbl, False, False, 0)

        badge_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        if entry["slug"] in self._new_slugs:
            new_lbl = Gtk.Label(label="NEW", xalign=0)
            new_lbl.get_style_context().add_class("row-new")
            badge_box.pack_start(new_lbl, False, False, 0)
        if show_suggest:
            suggestion = auto_suggest_category(entry, self._categories)
            if suggestion and suggestion != getattr(row, "_source_cat", None):
                sug_lbl = Gtk.Label(label=f"\u2192 {suggestion[:28]}", xalign=0)
                sug_lbl.get_style_context().add_class("row-suggest")
                badge_box.pack_start(sug_lbl, False, False, 0)
                row._suggestion = suggestion
        card.pack_start(badge_box, False, False, 0)

        outer.pack_start(card, True, True, 0)

        # BBS link button — always rightmost, non-activatable
        bbs_btn = Gtk.Button(label="\U0001f517")
        bbs_btn.get_style_context().add_class("btn-link")
        bbs_btn.set_valign(Gtk.Align.CENTER)
        bbs_btn.set_size_request(44, 44)
        url = bbs_url(entry)
        bbs_btn.connect("clicked", lambda b, u=url: self._open_bbs(u))
        outer.pack_start(bbs_btn, False, False, 0)

        row.add(outer)
        row._card = outer
        return row

    def _highlight_row(self, card_widget):
        """Apply selection highlight to one card, clear any previous one."""
        if self._sel_row_widget and self._sel_row_widget != card_widget:
            self._sel_row_widget.get_style_context().remove_class("row-selected")
        if card_widget:
            card_widget.get_style_context().add_class("row-selected")
        self._sel_row_widget = card_widget

    # ── Category button panel ─────────────────────────────────────────────────
    def _rebuild_cat_buttons(self):
        for w in self._cat_btn_box.get_children():
            self._cat_btn_box.remove(w)

        for cat in self._categories:
            count  = len(self._sections.get(cat, []))
            label  = f"{cat[:20]}…" if len(cat) > 20 else cat
            label  = f"{label}  ({count})"
            is_active = (cat == self._sel_cat)
            btn = Gtk.Button(label=label)
            btn.get_style_context().add_class(
                "btn-cat-active" if is_active else "btn-cat")
            btn.set_size_request(0, 44)
            btn.connect("clicked", self._on_cat_btn_clicked, cat)
            self._cat_btn_box.pack_start(btn, False, False, 0)

        self._cat_btn_box.show_all()

    def _refresh_cat_view(self):
        """Repopulate the right-panel ListBox for the current category."""
        for w in self._cat_lb.get_children():
            self._cat_lb.remove(w)

        if not self._sel_cat:
            self._cat_lb.show_all()
            return

        entries = self._sections.get(self._sel_cat, [])
        if entries:
            for e in entries:
                self._cat_lb.add(self._make_entry_row(e))
        else:
            # Empty-state hint
            hint_row = Gtk.ListBoxRow()
            hint_row.set_activatable(False)
            hint_lbl = Gtk.Label(
                label="No entries yet.  Assign from the left panel.", xalign=0.5)
            hint_lbl.set_justify(Gtk.Justification.CENTER)
            hint_lbl.get_style_context().add_class("header-sub")
            hint_lbl.set_margin_top(20); hint_lbl.set_margin_bottom(20)
            hint_lbl.set_margin_start(12); hint_lbl.set_margin_end(12)
            hint_row.add(hint_lbl)
            self._cat_lb.add(hint_row)
        self._cat_lb.show_all()
        count = len(entries)
        self._cat_count_lbl.set_text(f"{count} {'entry' if count == 1 else 'entries'}")

    def _refresh_unsorted_view(self):
        """Route to the correct left-column refresh based on current mode."""
        if self._browse_mode:
            self._refresh_all_view()
        else:
            self._refresh_only_unsorted()

    def _refresh_only_unsorted(self):
        for w in self._unsorted_lb.get_children():
            self._unsorted_lb.remove(w)
        entries = self._sections.get("UNSORTED", []) + self._unsorted
        for e in entries:
            self._unsorted_lb.add(self._make_entry_row(e))
        self._unsorted_lb.show_all()
        self._unsorted_count.set_text(f"{len(entries)} entries")

    def _refresh_all_view(self):
        """Populate left column with all entries across every category."""
        for w in self._unsorted_lb.get_children():
            self._unsorted_lb.remove(w)

        # Build flat list with category label
        flat = []
        for cat, entries in self._sections.items():
            if cat == "UNSORTED":
                continue
            for e in entries:
                flat.append((e, cat))
        for e in self._unsorted + self._sections.get("UNSORTED", []):
            flat.append((e, "— unsorted —"))

        # Filter
        q = self._all_filter.lower()
        if q:
            flat = [
                (e, c) for (e, c) in flat
                if q in e["title"].lower()
                or q in e["author"].lower()
                or q in c.lower()
            ]

        # Sort
        col = self._all_sort_col
        rev = not self._all_sort_asc
        if col == 0:
            flat.sort(key=lambda x: x[0]["title"].lower(), reverse=rev)
        elif col == 1:
            flat.sort(key=lambda x: x[0]["author"].lower(), reverse=rev)
        else:
            flat.sort(key=lambda x: x[1].lower(), reverse=rev)

        target_row = None
        for (e, cat) in flat:
            r = self._make_entry_row_browse(e, cat)
            self._unsorted_lb.add(r)
            if self._last_acted_slug and e["slug"] == self._last_acted_slug:
                target_row = r
        self._unsorted_lb.show_all()

        # Scroll to last-acted entry so position is preserved after move
        if target_row:
            GLib.idle_add(
                lambda r=target_row: self._unsorted_lb.get_adjustment() and
                    self._unsorted_lb.get_adjustment().set_value(
                        r.get_allocation().y) or False)

        total = sum(len(v) for v in self._sections.values()) + len(self._unsorted)
        shown = len(flat)
        self._unsorted_count.set_text(
            f"{shown} of {total}" if q else f"{total} entries")

        # Update sort button labels
        col_names = ["Name", "Author", "Category"]
        for i, sb in enumerate(self._sort_btns):
            label = col_names[i]
            if i == self._all_sort_col:
                label += "  " + ("▲" if self._all_sort_asc else "▼")
            sb.set_label(label)

    def _make_entry_row_browse(self, entry, category):
        """Row with title + author + category label for ALL ENTRIES mode."""
        row = Gtk.ListBoxRow()
        row._entry = entry
        row._source_cat = None if category == "\u2014 unsorted \u2014" else category

        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        outer.set_margin_top(3); outer.set_margin_bottom(3)
        outer.set_margin_start(6); outer.set_margin_end(4)

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)

        title_lbl = Gtk.Label(label=entry["title"], xalign=0)
        title_lbl.get_style_context().add_class("row-title")
        title_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        card.pack_start(title_lbl, False, False, 0)

        meta_lbl = Gtk.Label(label=entry["author"], xalign=0)
        meta_lbl.get_style_context().add_class("row-meta")
        card.pack_start(meta_lbl, False, False, 0)

        cat_lbl = Gtk.Label(label=category, xalign=0)
        cat_lbl.get_style_context().add_class("row-meta")
        cat_lbl.set_markup(f'<span foreground="#4a8fa8">{GLib.markup_escape_text(category)}</span>')
        card.pack_start(cat_lbl, False, False, 0)

        badge_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        if entry["slug"] in self._new_slugs:
            new_lbl = Gtk.Label(label="NEW", xalign=0)
            new_lbl.get_style_context().add_class("row-new")
            badge_box.pack_start(new_lbl, False, False, 0)
        card.pack_start(badge_box, False, False, 0)

        outer.pack_start(card, True, True, 0)

        bbs_btn = Gtk.Button(label="\U0001f517")
        bbs_btn.get_style_context().add_class("btn-link")
        bbs_btn.set_valign(Gtk.Align.CENTER)
        bbs_btn.set_size_request(44, 44)
        url = bbs_url(entry)
        bbs_btn.connect("clicked", lambda b, u=url: self._open_bbs(u))
        outer.pack_start(bbs_btn, False, False, 0)

        row.add(outer)
        row._card = outer
        return row

    # ── Toggle / sort / filter handlers ──────────────────────────────────────
    def _on_toggle_browse(self, btn, browse):
        self._browse_mode = browse
        self._sel_entry = None
        self._sel_row_widget = None

        if browse:
            self._tog_all_btn.get_style_context().remove_class("btn-cat")
            self._tog_all_btn.get_style_context().add_class("btn-cat-active")
            self._tog_unsorted_btn.get_style_context().remove_class("btn-cat-active")
            self._tog_unsorted_btn.get_style_context().add_class("btn-cat")
            self._sort_bar.show()
            self._left_hint.set_text("Click entry, then a category to move it →")
        else:
            self._tog_unsorted_btn.get_style_context().remove_class("btn-cat")
            self._tog_unsorted_btn.get_style_context().add_class("btn-cat-active")
            self._tog_all_btn.get_style_context().remove_class("btn-cat-active")
            self._tog_all_btn.get_style_context().add_class("btn-cat")
            self._sort_bar.hide()
            self._left_hint.set_text("Click entry, then a category →")

        self._refresh_unsorted_view()

    def _on_all_sort_clicked(self, btn, col_idx):
        if self._all_sort_col == col_idx:
            self._all_sort_asc = not self._all_sort_asc
        else:
            self._all_sort_col = col_idx
            self._all_sort_asc = True
        self._refresh_all_view()

    def _on_all_filter_changed(self, entry):
        self._all_filter = entry.get_text().strip()
        self._refresh_all_view()

    # ── Keyboard shortcuts ────────────────────────────────────────────────────
    def _on_key_press(self, win, event):
        """Esc clears the current entry selection without moving anything."""
        if event.keyval == Gdk.KEY_Escape and self._sel_entry:
            if self._sel_row_widget:
                self._sel_row_widget.get_style_context().remove_class("row-selected")
                self._sel_row_widget = None
            self._sel_entry = None
            self._set_status("Selection cleared.")
        return False  # propagate event

    def _on_left_activated(self, lb, row):
        """Unified handler for both unsorted and all-entries left column clicks."""
        entry = row._entry
        if self._browse_mode:
            source_cat = getattr(row, "_source_cat", None)
        else:
            source_cat = None
        self._sel_entry = {"entry": entry, "source_cat": source_cat}
        self._highlight_row(row._card)
        self._set_status(f"Selected: {entry['title'][:50]} — click a category to assign")

    def _on_unsorted_activated(self, lb, row):
        """Legacy — kept for safety, routes to unified handler."""
        self._on_left_activated(lb, row)

    def _on_cat_entry_activated(self, lb, row):
        entry = row._entry
        self._sel_entry = {"entry": entry, "source_cat": self._sel_cat}
        self._highlight_row(row._card)
        self._set_status(f"Selected: {entry['title'][:50]} — click a category to move, or use ↑↓")

    # ── Category button clicked ───────────────────────────────────────────────
    def _on_cat_btn_clicked(self, btn, cat):
        if self._sel_entry:
            self._assign_entry_to(cat)
        else:
            self._view_category(cat)

    def _view_category(self, cat):
        self._sel_cat = cat
        self._cat_title_lbl.set_text(cat)
        self._refresh_cat_view()
        self._rebuild_cat_buttons()

    def _assign_entry_to(self, target_cat):
        if not self._sel_entry:
            return
        entry      = self._sel_entry["entry"]
        source_cat = self._sel_entry["source_cat"]

        if source_cat == target_cat:
            self._sel_entry = None
            return

        entry_id = id(entry)

        # Remove from source by object identity (avoids partial-match false removes)
        if source_cat is None:
            self._unsorted = [e for e in self._unsorted if id(e) != entry_id]
            self._sections["UNSORTED"] = [
                e for e in self._sections.get("UNSORTED", []) if id(e) != entry_id]
        else:
            self._sections[source_cat] = [
                e for e in self._sections.get(source_cat, []) if id(e) != entry_id]

        # Guard: remove from target too if somehow already present (dedup safety)
        if target_cat not in self._sections:
            self._sections[target_cat] = []
        self._sections[target_cat] = [
            e for e in self._sections[target_cat] if id(e) != entry_id]

        # Append to target
        self._sections[target_cat].append(entry)
        set_master_category_for_entries(self._filepath, [entry], target_cat)

        self._last_acted_slug = entry["slug"]
        self._sel_entry      = None
        self._sel_row_widget = None
        self._refresh_unsorted_view()
        self._refresh_cat_view()
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(f"Moved '{entry['title'][:40]}' -> {target_cat}")

    # ── Action buttons ────────────────────────────────────────────────────────
    def _get_selected_in_cat(self):
        """Return (list_ref, index) for the currently selected entry in right panel."""
        if not self._sel_entry or self._sel_entry.get("source_cat") != self._sel_cat:
            return None, -1
        entry = self._sel_entry["entry"]
        lst   = self._sections.get(self._sel_cat, [])
        try:
            idx = lst.index(entry)
            return lst, idx
        except ValueError:
            return None, -1

    def _on_move_up(self, *_):
        lst, idx = self._get_selected_in_cat()
        if lst is None or idx <= 0:
            return
        lst[idx], lst[idx-1] = lst[idx-1], lst[idx]
        self._mark_dirty()
        self._refresh_cat_view()
        # Re-select same entry
        rows = self._cat_lb.get_children()
        if idx-1 < len(rows):
            self._on_cat_entry_activated(self._cat_lb, rows[idx-1])

    def _on_move_down(self, *_):
        lst, idx = self._get_selected_in_cat()
        if lst is None or idx < 0 or idx >= len(lst)-1:
            return
        lst[idx], lst[idx+1] = lst[idx+1], lst[idx]
        self._mark_dirty()
        self._refresh_cat_view()
        rows = self._cat_lb.get_children()
        if idx+1 < len(rows):
            self._on_cat_entry_activated(self._cat_lb, rows[idx+1])

    def _on_sort_cat_col(self, btn, col_idx):
        """Sort current category by col_idx (0=title, 1=author, 2=author+title).
        Repeat click on same column toggles asc/desc."""
        if not self._sel_cat:
            self._set_status("Select a category first.", warn=True)
            return
        cat = self._sel_cat
        prev_col, prev_asc = self._cat_sort_state.get(cat, (None, True))
        asc = not prev_asc if col_idx == prev_col else True
        self._cat_sort_state[cat] = (col_idx, asc)
        rev = not asc
        lst = self._sections.get(cat, [])
        if col_idx == 0:
            lst.sort(key=lambda e: e["title"].lower(), reverse=rev)
            col_name = "title"
        elif col_idx == 1:
            lst.sort(key=lambda e: e["author"].lower(), reverse=rev)
            col_name = "author"
        else:
            lst.sort(key=lambda e: (e["author"].lower(), e["title"].lower()), reverse=rev)
            col_name = "author+title"
        # Update sort button labels to show active sort + direction.
        # Popover sort buttons use standard Gtk.Button(label=...) — get_child()
        # returns a Gtk.Label directly; fallback to set_label() for safety.
        short_labels = {0: "Title", 1: "Author", 2: "A+T"}
        for i, b in self._cat_sort_btns.items():
            arrow = (" \u25b2" if asc else " \u25bc") if i == col_idx else ""
            child = b.get_child()
            if isinstance(child, Gtk.Label):
                child.set_text(f"\u21c5 {short_labels[i]}{arrow}")
            else:
                b.set_label(f"\u21c5 {short_labels[i]}{arrow}")
        self._sel_entry = None
        self._sel_row_widget = None
        self._refresh_cat_view()
        self._mark_dirty()
        direction = "A\u2192Z" if asc else "Z\u2192A"
        self._set_status(f"Sorted '{cat}' by {col_name} {direction}")

    def _on_remove(self, *_):
        """Move selected entry to top of Unsorted (from either panel)."""
        # Accept selection from right panel OR left panel (browse mode)
        if not self._sel_entry:
            self._set_status("Select an entry first.", warn=True)
            return

        entry      = self._sel_entry["entry"]
        source_cat = self._sel_entry["source_cat"]
        entry_id   = id(entry)

        # Already unsorted — nothing to do
        already_unsorted = (
            source_cat is None
            and any(id(e) == entry_id for e in self._unsorted)
        )
        if already_unsorted:
            self._set_status(f"'{entry['title'][:40]}' is already unsorted.", warn=True)
            self._sel_entry = None
            return

        dlg = Gtk.MessageDialog(
            transient_for=self,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text=f"Unassign '{entry['title']}'?")
        dlg.format_secondary_text(
            "This moves it back to the top of Unsorted.\n"
            "It will NOT be removed from your PICO-8 favourites.")
        resp = dlg.run()
        dlg.destroy()

        if resp != Gtk.ResponseType.YES:
            return

        # Remove from source by id
        if source_cat is None:
            self._sections["UNSORTED"] = [
                e for e in self._sections.get("UNSORTED", []) if id(e) != entry_id]
        else:
            self._sections[source_cat] = [
                e for e in self._sections.get(source_cat, []) if id(e) != entry_id]

        # Prepend to top of _unsorted
        self._unsorted.insert(0, entry)

        self._sel_entry      = None
        self._sel_row_widget = None
        self._sel_cat        = None
        self._cat_title_lbl.set_text("SELECT A CATEGORY")
        self._cat_count_lbl.set_text("")
        self._refresh_unsorted_view()
        self._refresh_cat_view()
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(f"Moved '{entry['title'][:40]}' back to Unsorted")

    def _on_add_category(self, *_):
        dlg = Gtk.Dialog(title="New Category", transient_for=self,
                         flags=Gtk.DialogFlags.MODAL)
        dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.STOCK_OK,     Gtk.ResponseType.OK)
        box = dlg.get_content_area()
        box.set_margin_top(12); box.set_margin_bottom(12)
        box.set_margin_start(16); box.set_margin_end(16)
        lbl = Gtk.Label(label="Category name:", xalign=0)
        box.pack_start(lbl, False, False, 4)
        entry_widget = Gtk.Entry()
        entry_widget.set_size_request(0, 44)
        entry_widget.connect("activate",            lambda *_: dlg.response(Gtk.ResponseType.OK))
        box.pack_start(entry_widget, False, False, 4)
        dlg.show_all()
        resp = dlg.run()
        name = entry_widget.get_text().strip().upper()
        dlg.destroy()
        if resp == Gtk.ResponseType.OK and name:
            if name not in self._categories:
                self._categories.append(name)
                self._sections[name] = []
                self._rebuild_cat_buttons()
                self._mark_dirty()
                self._set_status(f"Category added: {name}")
            else:
                self._set_status(f"'{name}' already exists — nothing added.", warn=True)

    def _on_rename_category(self, *_):
        """Rename the currently viewed category in-place."""
        if not self._sel_cat:
            self._set_status("Select a category first (click its button).", warn=True)
            return
        old_name = self._sel_cat

        dlg = Gtk.Dialog(title="Rename Category", transient_for=self,
                         flags=Gtk.DialogFlags.MODAL)
        dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.STOCK_OK,     Gtk.ResponseType.OK)
        box = dlg.get_content_area()
        box.set_margin_top(12); box.set_margin_bottom(12)
        box.set_margin_start(16); box.set_margin_end(16)
        lbl = Gtk.Label(label=f"Rename '{old_name}' to:", xalign=0)
        box.pack_start(lbl, False, False, 4)
        entry_widget = Gtk.Entry()
        entry_widget.set_size_request(0, 44)
        entry_widget.set_text(old_name)
        entry_widget.select_region(0, -1)
        entry_widget.connect("activate",
            lambda *_: dlg.response(Gtk.ResponseType.OK))
        box.pack_start(entry_widget, False, False, 4)
        dlg.show_all()
        resp = dlg.run()
        new_name = entry_widget.get_text().strip().upper()
        dlg.destroy()

        if resp != Gtk.ResponseType.OK or not new_name or new_name == old_name:
            return
        if new_name in self._categories:
            self._set_status(f"Category '{new_name}' already exists.", warn=True)
            return

        # Rename in categories list
        idx = self._categories.index(old_name)
        self._categories[idx] = new_name

        # Rename the sections dict key
        self._sections[new_name] = self._sections.pop(old_name, [])
        set_master_category_for_entries(self._filepath, self._sections[new_name], new_name)

        # Migrate sort state to new name so sort memory isn't lost
        if old_name in self._cat_sort_state:
            self._cat_sort_state[new_name] = self._cat_sort_state.pop(old_name)

        self._sel_cat = new_name
        self._cat_title_lbl.set_text(new_name)
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(f"Renamed '{old_name}' -> '{new_name}'")

    def _on_delete_category(self, *_):
        """Delete the currently viewed category. Its entries move to top of Unsorted."""
        if not self._sel_cat:
            self._set_status("Select a category first (click its button).", warn=True)
            return
        cat     = self._sel_cat
        entries = self._sections.get(cat, [])
        count   = len(entries)

        dlg = Gtk.MessageDialog(
            transient_for=self,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text=f"Delete category '{cat}'?")
        dlg.format_secondary_text(
            f"{count} entr{'y' if count == 1 else 'ies'} will move to the top of Unsorted, "
            f"sorted by author A\u2192Z.\n"
            "The category header will be removed from the file on next Save.")
        resp = dlg.run()
        dlg.destroy()

        if resp != Gtk.ResponseType.YES:
            return

        # Sort displaced entries by author A→Z before prepending to Unsorted,
        # so they land in a consistent order rather than whatever order they
        # happened to be in the category.
        sorted_entries = sorted(entries, key=lambda e: e["author"].lower())
        self._unsorted = sorted_entries + self._unsorted
        set_master_category_for_entries(self._filepath, sorted_entries, "UNSORTED")

        # Remove category from state
        self._sections.pop(cat, None)
        self._cat_sort_state.pop(cat, None)
        if cat in self._categories:
            self._categories.remove(cat)

        self._sel_cat        = None
        self._sel_entry      = None
        self._sel_row_widget = None
        self._cat_title_lbl.set_text("SELECT A CATEGORY")
        self._cat_count_lbl.set_text("")
        self._refresh_unsorted_view()
        self._refresh_cat_view()
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(
            f"Deleted '{cat}' — {count} entr{'y' if count == 1 else 'ies'} moved to Unsorted")

    def _on_cat_up(self, *_):
        """Move the currently viewed category one position up in the list."""
        if not self._sel_cat:
            self._set_status("Select a category first (click its button).", warn=True)
            return
        cats = self._categories
        try:
            idx = cats.index(self._sel_cat)
        except ValueError:
            return
        if idx <= 0:
            self._set_status(f"'{self._sel_cat}' is already at the top.", warn=True)
            return
        cats[idx], cats[idx - 1] = cats[idx - 1], cats[idx]
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(f"Moved '{self._sel_cat}' up")

    def _on_cat_down(self, *_):
        """Move the currently viewed category one position down in the list."""
        if not self._sel_cat:
            self._set_status("Select a category first (click its button).", warn=True)
            return
        cats = self._categories
        try:
            idx = cats.index(self._sel_cat)
        except ValueError:
            return
        if idx >= len(cats) - 1:
            self._set_status(f"'{self._sel_cat}' is already at the bottom.", warn=True)
            return
        cats[idx], cats[idx + 1] = cats[idx + 1], cats[idx]
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(f"Moved '{self._sel_cat}' down")

    def _on_delete_game(self, *_):
        """Permanently delete selected entry — removes its line from the file on save."""
        if not self._sel_entry:
            self._set_status("Select an entry first.", warn=True)
            return

        entry      = self._sel_entry["entry"]
        source_cat = self._sel_entry["source_cat"]
        entry_id   = id(entry)

        dlg = Gtk.MessageDialog(
            transient_for=self,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.YES_NO,
            text=f"Permanently delete '{entry['title']}'?")
        dlg.format_secondary_text(
            "This removes the entry line from favourites.txt on next Save.\n"
            "It will disappear from PICO-8 Splore favourites on next launch.\n\n"
            "This cannot be undone (a backup is written before every Save).")
        resp = dlg.run()
        dlg.destroy()

        if resp != Gtk.ResponseType.YES:
            return

        # Remove by id from wherever it lives
        if source_cat is None:
            self._unsorted = [e for e in self._unsorted if id(e) != entry_id]
            self._sections["UNSORTED"] = [
                e for e in self._sections.get("UNSORTED", []) if id(e) != entry_id]
        else:
            self._sections[source_cat] = [
                e for e in self._sections.get(source_cat, []) if id(e) != entry_id]

        self._sel_entry      = None
        self._sel_row_widget = None
        self._refresh_unsorted_view()
        self._refresh_cat_view()
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(f"Deleted '{entry['title'][:40]}' — save to write changes")

    def _on_add_to_favs(self, *_):
        """Move selected entry to CURRENT FAVORITES (cut, not copy)."""
        if not self._sel_entry:
            self._set_status("Select an entry first.", warn=True)
            return
        fav_cat = "CURRENT FAVORITES"
        if fav_cat not in self._categories:
            self._set_status(f"'{fav_cat}' category not found.", warn=True)
            return
        entry      = self._sel_entry["entry"]
        source_cat = self._sel_entry["source_cat"]
        if source_cat == fav_cat:
            self._set_status(f"Already in {fav_cat}.", warn=True)
            return
        self._assign_entry_to(fav_cat)
        # status already set by _assign_entry_to; override with friendlier msg
        self._set_status(f"Starred: '{entry['title'][:40]}' -> {fav_cat}")

    def _on_move_to(self, *_):
        """Open a dialog listing all categories; move selected entry to chosen one."""
        if not self._sel_entry:
            self._set_status("Select an entry first.", warn=True)
            return
        entry      = self._sel_entry["entry"]
        source_cat = self._sel_entry["source_cat"]

        dlg = Gtk.Dialog(title="Move to Category", transient_for=self,
                         flags=Gtk.DialogFlags.MODAL)
        dlg.add_button(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL)
        box = dlg.get_content_area()
        box.set_margin_top(8); box.set_margin_bottom(8)
        box.set_margin_start(12); box.set_margin_end(12)

        lbl = Gtk.Label(
            label=f"Move '{entry['title'][:48]}' to:", xalign=0)
        lbl.set_margin_bottom(6)
        box.pack_start(lbl, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_size_request(480, 300)
        lb = Gtk.ListBox()
        lb.set_selection_mode(Gtk.SelectionMode.SINGLE)

        chosen = [None]

        for cat in self._categories:
            if cat == source_cat or cat == "UNSORTED":
                continue
            row = Gtk.ListBoxRow()
            row._cat = cat
            count = len(self._sections.get(cat, []))
            lbl_row = Gtk.Label(
                label=f"{cat}  ({count})", xalign=0)
            lbl_row.set_margin_top(12); lbl_row.set_margin_bottom(12)
            lbl_row.set_margin_start(8)
            row.add(lbl_row)
            lb.add(row)

        def on_row_activated(lb, row):
            chosen[0] = row._cat
            dlg.response(Gtk.ResponseType.OK)

        lb.connect("row-activated", on_row_activated)
        scroll.add(lb)
        box.pack_start(scroll, True, True, 0)
        dlg.show_all()
        resp = dlg.run()
        target = chosen[0]
        dlg.destroy()

        if resp != Gtk.ResponseType.OK or not target:
            return
        self._assign_entry_to(target)
        self._set_status(f"Moved '{entry['title'][:40]}' -> {target}")

    # ── BBS link opener ───────────────────────────────────────────────────────
    def _open_bbs(self, url):
        """Open a Lexaloffle BBS URL in the system browser via xdg-open.
        URL must start with BBS_ALLOWED_PREFIX — guards against a corrupted
        favourites.txt constructing an arbitrary URL.
        """
        if not url.startswith(BBS_ALLOWED_PREFIX):
            self._set_status("Blocked: URL is not a Lexaloffle BBS link.", warn=True)
            return
        try:
            subprocess.Popen(["xdg-open", url],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            self._set_status(f"Opening: {url}")
        except Exception as ex:
            self._show_error(f"Could not open browser:\n{ex}")

    # ── Auto-sort (keyword suggestion + BBS tag fetch) ───────────────────────
    def _on_auto_sort(self, *_):
        """Scan unsorted entries for suggestions via keyword rules and/or live
        BBS tag lookup. Shows a scrollable checkbox dialog — all pre-checked.
        'Fetch BBS Tags' button runs a background thread (3 workers, urllib only)
        and updates suggestions live via GLib.idle_add without blocking the UI.
        """
        pool = list(self._unsorted) + self._sections.get("UNSORTED", [])
        if not pool:
            self._set_status("No unsorted entries to suggest for.", warn=True)
            return

        # Initial suggestions from keyword rules only (instant, no network)
        # suggestions_map: entry id → (entry, cat, source) where source is
        # "keyword" or "bbs". BBS results override keyword results.
        suggestions_map = {}
        for e in pool:
            cat = auto_suggest_category(e, self._categories)
            if cat:
                suggestions_map[id(e)] = (e, cat, "keyword")

        # ── Build dialog ──────────────────────────────────────────────────────
        dlg = Gtk.Dialog(title="Auto-Sort Suggestions",
                         transient_for=self,
                         flags=Gtk.DialogFlags.MODAL)
        dlg.set_default_size(560, 420)

        # Header bar with fetch button
        hbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        hbar.set_margin_top(10); hbar.set_margin_start(14); hbar.set_margin_end(14)

        hdr_lbl = Gtk.Label(xalign=0)
        hdr_lbl.set_markup(
            f'<b>{len(pool)} unsorted entr{"y" if len(pool)==1 else "ies"}</b>'
            '  <span foreground="#50506a" size="small">'
            '— check to move, uncheck to skip</span>')
        hbar.pack_start(hdr_lbl, True, True, 0)

        fetch_btn = Gtk.Button(label="\U0001f310 Fetch BBS Tags")
        fetch_btn.get_style_context().add_class("btn-primary")
        fetch_btn.set_size_request(0, 44)
        hbar.pack_start(fetch_btn, False, False, 0)

        dlg.get_content_area().pack_start(hbar, False, False, 0)

        # Progress bar (hidden until fetch starts)
        prog = Gtk.ProgressBar()
        prog.set_margin_start(14); prog.set_margin_end(14)
        prog.set_margin_top(4)
        prog.set_no_show_all(True)
        prog.hide()
        dlg.get_content_area().pack_start(prog, False, False, 0)

        # Scrollable list
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        scroll.set_margin_start(14); scroll.set_margin_end(14)
        scroll.set_margin_top(6)
        lb = Gtk.ListBox()
        lb.set_selection_mode(Gtk.SelectionMode.NONE)
        scroll.add(lb)
        dlg.get_content_area().pack_start(scroll, True, True, 0)

        # Bottom action bar
        dlg.add_button("Apply Checked", Gtk.ResponseType.OK)
        dlg.add_button("Cancel",        Gtk.ResponseType.CANCEL)

        # ── Row builder ───────────────────────────────────────────────────────
        # row_widgets: entry id → (ListBoxRow, CheckButton, sub_label)
        row_widgets = {}

        def _source_badge(source):
            return (
                '<span foreground="#1ebdd1" size="small"> [BBS]</span>'
                if source == "bbs" else
                '<span foreground="#50506a" size="small"> [kw]</span>'
            )

        def _make_row(entry, cat, source):
            row = Gtk.ListBoxRow()
            row.set_activatable(False)
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            hbox.set_margin_top(4); hbox.set_margin_bottom(4)
            hbox.set_margin_start(6); hbox.set_margin_end(6)

            chk = Gtk.CheckButton()
            chk.set_active(True)
            hbox.pack_start(chk, False, False, 0)

            info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
            t = Gtk.Label(label=entry["title"], xalign=0)
            t.get_style_context().add_class("row-title")
            t.set_ellipsize(Pango.EllipsizeMode.END)
            info.pack_start(t, False, False, 0)

            sub = Gtk.Label(xalign=0)
            sub.set_markup(
                f'<span foreground="#6a6a86" size="small">'
                f'{GLib.markup_escape_text(entry["author"])}</span>'
                f'  <span foreground="#ffec27" size="small">'
                f'\u2192 {GLib.markup_escape_text(cat)}</span>'
                + _source_badge(source))
            info.pack_start(sub, False, False, 0)
            hbox.pack_start(info, True, True, 0)

            bbs_btn = Gtk.Button(label="\U0001f517")
            bbs_btn.get_style_context().add_class("btn-link")
            bbs_btn.set_valign(Gtk.Align.CENTER)
            url = bbs_url(entry)
            bbs_btn.connect("clicked", lambda b, u=url: self._open_bbs(u))
            hbox.pack_start(bbs_btn, False, False, 0)

            row.add(hbox)
            return row, chk, sub

        def _rebuild_list():
            """Repopulate lb from suggestions_map. Called on GTK main thread."""
            for w in lb.get_children():
                lb.remove(w)
            row_widgets.clear()
            for e in pool:
                eid = id(e)
                if eid in suggestions_map:
                    _, cat, source = suggestions_map[eid]
                    row, chk, sub = _make_row(e, cat, source)
                    lb.add(row)
                    row_widgets[eid] = (row, chk, sub)

            if not suggestions_map:
                hint_row = Gtk.ListBoxRow()
                hint_row.set_activatable(False)
                hint_row.set_selectable(False)
                hint_lbl = Gtk.Label(xalign=0)
                hint_lbl.set_line_wrap(True)
                hint_lbl.set_margin_top(10); hint_lbl.set_margin_bottom(10)
                hint_lbl.set_margin_start(8); hint_lbl.set_margin_end(8)
                hint_lbl.set_markup(
                    '<span foreground="#ffec27">\U0001f937 Couldn\u2019t figure it out '
                    'from keywords.</span>\n'
                    '<span foreground="#50506a" size="small">'
                    'Try \u201cFetch BBS Tags\u201d above to check Lexaloffle directly, '
                    'or sort these manually.</span>')
                hint_row.add(hint_lbl)
                lb.add(hint_row)

            lb.show_all()
            n = len(suggestions_map)
            hdr_lbl.set_markup(
                f'<b>{n} suggestion{"s" if n != 1 else ""}'
                f' from {len(pool)} unsorted entr{"y" if len(pool)==1 else "ies"}</b>'
                '  <span foreground="#50506a" size="small">'
                '— check to move, uncheck to skip</span>')

        _rebuild_list()

        # ── BBS fetch logic ───────────────────────────────────────────────────
        _fetch_running = [False]

        def _do_fetch(_btn):
            if _fetch_running[0]:
                return
            _fetch_running[0] = True
            fetch_btn.set_sensitive(False)
            prog.show()
            prog.set_fraction(0.0)
            prog.set_text("Fetching BBS tags…")
            prog.set_show_text(True)

            total   = len(pool)
            done    = [0]
            # Watchdog: if the thread goes silent for 30s, re-enable the button
            # so the user is never permanently stuck. Cancelled on normal completion.
            _watchdog_id  = [None]
            _fetch_done   = [False]

            def _watchdog_fire():
                if not _fetch_done[0]:
                    prog.hide()
                    fetch_btn.set_sensitive(True)
                    _fetch_running[0] = False
                    self._set_status(
                        "BBS fetch timed out — partial results kept.", warn=True)
                return False  # do not repeat

            def _worker_batch():
                with ThreadPoolExecutor(max_workers=3) as ex:
                    futures = {
                        ex.submit(fetch_bbs_tags, e["base"]): e
                        for e in pool
                    }
                    for future in as_completed(futures):
                        entry = futures[future]
                        try:
                            tags = future.result()
                        except Exception:
                            tags = []
                        done[0] += 1
                        GLib.idle_add(_on_result, entry, tags, done[0], total)

                GLib.idle_add(_on_fetch_done)

            def _on_result(entry, tags, n, total_count):
                try:
                    frac = n / total_count
                    prog.set_fraction(frac)
                    prog.set_text(f"{n} / {total_count}")

                    if tags:
                        cat = bbs_tags_to_category(tags, self._categories)
                        if cat:
                            eid = id(entry)
                            old = suggestions_map.get(eid)
                            if old is None or old[2] != "bbs":
                                suggestions_map[eid] = (entry, cat, "bbs")
                                if eid in row_widgets:
                                    _, _, sub = row_widgets[eid]
                                    sub.set_markup(
                                        f'<span foreground="#6a6a86" size="small">'
                                        f'{GLib.markup_escape_text(entry["author"])}</span>'
                                        f'  <span foreground="#ffec27" size="small">'
                                        f'\u2192 {GLib.markup_escape_text(cat)}</span>'
                                        + _source_badge("bbs"))
                                else:
                                    _rebuild_list()
                except Exception:
                    pass  # never let a bad result crash the idle callback
                return False  # GLib.idle_add: do not repeat

            def _on_fetch_done():
                try:
                    _fetch_done[0] = True
                    if _watchdog_id[0] is not None:
                        GLib.source_remove(_watchdog_id[0])
                        _watchdog_id[0] = None
                    prog.hide()
                    fetch_btn.set_sensitive(True)
                    _fetch_running[0] = False
                    _rebuild_list()
                    n = len(suggestions_map)
                    self._set_status(
                        f"BBS fetch complete — {n} suggestion{'s' if n!=1 else ''} found")
                except Exception:
                    pass  # UI cleanup must not raise
                return False

            threading.Thread(target=_worker_batch, daemon=True).start()
            # 30s per cart + 10s buffer; minimum 30s for small collections
            timeout_s = max(30, total * 2 + 10)
            _watchdog_id[0] = GLib.timeout_add_seconds(timeout_s, _watchdog_fire)

        fetch_btn.connect("clicked", _do_fetch)

        dlg.show_all()
        prog.hide()  # keep hidden until fetch starts
        resp = dlg.run()
        dlg.destroy()

        if resp != Gtk.ResponseType.OK:
            return

        moved = 0
        for chk, entry, cat in [
            (row_widgets[eid][1], suggestions_map[eid][0], suggestions_map[eid][1])
            for eid in list(suggestions_map)
            if eid in row_widgets
        ]:
            if not chk.get_active():
                continue
            self._sel_entry = {"entry": entry, "source_cat": None}
            self._assign_entry_to(cat)
            moved += 1

        self._sel_entry      = None
        self._sel_row_widget = None
        self._refresh_unsorted_view()
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(
            f"Auto-sort: moved {moved} entr{'y' if moved==1 else 'ies'} to categories")

    # ── Suggest new categories ────────────────────────────────────────────────
    def _on_suggest_categories(self, *_):
        """Scan entries for themes not in existing categories and propose new ones.
        Scope: Unsorted Only or All Entries (toggle at top of dialog).
        BBS tag fetch optional — same threading pattern as auto-sort.
        Shows suggestions as cards with entry previews and name override option.
        Minimum MIN_SUGGEST entries per theme before showing a suggestion.
        """
        if not self._filepath:
            self._set_status("Open a favourites.txt first.", warn=True)
            return

        # ── Dialog ────────────────────────────────────────────────────────────
        dlg = Gtk.Dialog(title="Suggest New Categories",
                         transient_for=self,
                         flags=Gtk.DialogFlags.MODAL)
        dlg.set_default_size(560, 420)
        dlg.add_button("Create Checked", Gtk.ResponseType.OK)
        dlg.add_button("Cancel",         Gtk.ResponseType.CANCEL)

        box = dlg.get_content_area()

        # ── Top bar: scope toggle + fetch button ──────────────────────────────
        top_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        top_bar.set_margin_top(10); top_bar.set_margin_start(14)
        top_bar.set_margin_end(14); top_bar.set_margin_bottom(4)

        scope_lbl = Gtk.Label(label="Scan:", xalign=0)
        scope_lbl.get_style_context().add_class("header-sub")
        top_bar.pack_start(scope_lbl, False, False, 0)

        btn_unsorted = Gtk.Button(label="Unsorted Only")
        btn_unsorted.get_style_context().add_class("btn-cat-active")
        btn_unsorted.set_size_request(0, 44)
        top_bar.pack_start(btn_unsorted, False, False, 0)

        btn_all = Gtk.Button(label="All Entries")
        btn_all.get_style_context().add_class("btn-cat")
        btn_all.set_size_request(0, 44)
        top_bar.pack_start(btn_all, False, False, 0)

        fetch_btn = Gtk.Button(label="\U0001f310 Fetch BBS Tags")
        fetch_btn.get_style_context().add_class("btn-primary")
        fetch_btn.set_size_request(0, 44)
        top_bar.pack_end(fetch_btn, False, False, 0)

        box.pack_start(top_bar, False, False, 0)

        # Progress bar
        prog = Gtk.ProgressBar()
        prog.set_margin_start(14); prog.set_margin_end(14)
        prog.set_margin_top(2)
        prog.set_no_show_all(True); prog.hide()
        box.pack_start(prog, False, False, 0)

        # Status / hint label
        hint_lbl = Gtk.Label(xalign=0)
        hint_lbl.get_style_context().add_class("header-sub")
        hint_lbl.set_margin_start(14); hint_lbl.set_margin_top(2)
        hint_lbl.set_margin_bottom(4)
        box.pack_start(hint_lbl, False, False, 0)

        # Scrollable suggestion list
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        scroll.set_margin_start(14); scroll.set_margin_end(14)
        cards_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        cards_box.set_margin_bottom(6)
        scroll.add(cards_box)
        box.pack_start(scroll, True, True, 0)

        # ── State ─────────────────────────────────────────────────────────────
        _scope       = ["unsorted"]   # "unsorted" or "all"
        # tag_cache: id(entry) → (entry, [tag, ...]) populated by BBS fetch
        _tag_cache   = {}
        # suggestion_widgets: proposed_cat → (check, name_entry, [entry,...])
        _sug_widgets = {}
        _fetch_running = [False]
        _fetch_done    = [False]
        _watchdog_id   = [None]

        def _get_pool():
            if _scope[0] == "unsorted":
                return list(self._unsorted) + self._sections.get("UNSORTED", [])
            else:
                pool = list(self._unsorted) + self._sections.get("UNSORTED", [])
                for cat in self._categories:
                    if cat != "UNSORTED":
                        pool.extend(self._sections.get(cat, []))
                return pool

        def _rebuild_cards():
            """Recompute suggestions and repopulate the cards_box."""
            for w in cards_box.get_children():
                cards_box.remove(w)
            _sug_widgets.clear()

            pool = _get_pool()

            # Keyword suggestions (instant)
            kw_sugs = suggest_new_categories(pool, self._categories)

            # BBS tag suggestions (from cache, if fetch was run)
            bbs_sugs = suggest_new_categories_from_tags(
                {eid: v for eid, v in _tag_cache.items()
                 if any(id(pe) == eid for pe in pool)},
                self._categories) if _tag_cache else {}

            # Merge: BBS wins on count, keyword fills gaps
            merged = dict(kw_sugs)
            for cat, ents in bbs_sugs.items():
                if cat not in merged or len(ents) > len(merged[cat]):
                    merged[cat] = ents

            # Author-collection suggestions — lowest priority, only fills gaps
            author_sugs = suggest_author_categories(pool, self._categories)
            for cat, ents in author_sugs.items():
                if cat not in merged:
                    merged[cat] = ents

            if not merged:
                empty = Gtk.Label(
                    label="No new category suggestions found.\n"
                          "Try fetching BBS tags or adding more entries.",
                    xalign=0)
                empty.get_style_context().add_class("header-sub")
                empty.set_margin_top(12); empty.set_margin_start(8)
                cards_box.pack_start(empty, False, False, 0)
                hint_lbl.set_markup(
                    '<span foreground="#50506a">No suggestions — try Fetch BBS Tags</span>')
                cards_box.show_all()
                return

            n = len(merged)
            hint_lbl.set_markup(
                f'<span foreground="#1ebdd1"><b>{n} suggestion'
                f'{"s" if n != 1 else ""}</b></span>'
                f'  <span foreground="#50506a" size="small">'
                f'— uncheck to skip, rename inline</span>')

            for proposed_cat, ents in sorted(merged.items()):
                # Card frame
                card_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                card_frame.get_style_context().add_class("panel")
                card_frame.set_margin_top(2); card_frame.set_margin_bottom(2)

                # Row 1: checkbox + auto name + count
                row1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                row1.set_margin_top(8); row1.set_margin_start(10)
                row1.set_margin_end(10)

                chk = Gtk.CheckButton()
                chk.set_active(True)
                row1.pack_start(chk, False, False, 0)

                name_entry = Gtk.Entry()
                name_entry.set_text(proposed_cat)
                name_entry.set_size_request(0, 44)
                name_entry.get_style_context().add_class("btn-secondary")
                row1.pack_start(name_entry, True, True, 0)

                count_lbl = Gtk.Label(
                    label=f"{len(ents)} entr{'y' if len(ents)==1 else 'ies'}")
                count_lbl.get_style_context().add_class("header-sub")
                row1.pack_start(count_lbl, False, False, 0)

                card_frame.pack_start(row1, False, False, 0)

                # Row 2: entry preview (up to 4 titles)
                preview_titles = [e["title"][:28] for e in ents[:4]]
                if len(ents) > 4:
                    preview_titles.append(f"+ {len(ents)-4} more")
                preview_lbl = Gtk.Label(
                    label="  \u00b7  ".join(preview_titles), xalign=0)
                preview_lbl.get_style_context().add_class("row-meta")
                preview_lbl.set_ellipsize(Pango.EllipsizeMode.END)
                preview_lbl.set_margin_start(10); preview_lbl.set_margin_bottom(8)
                preview_lbl.set_margin_end(10)
                card_frame.pack_start(preview_lbl, False, False, 0)

                cards_box.pack_start(card_frame, False, False, 0)
                _sug_widgets[proposed_cat] = (chk, name_entry, ents)

            cards_box.show_all()

        # ── Scope toggle handlers ──────────────────────────────────────────────
        def _set_scope(new_scope):
            _scope[0] = new_scope
            if new_scope == "unsorted":
                btn_unsorted.get_style_context().remove_class("btn-cat")
                btn_unsorted.get_style_context().add_class("btn-cat-active")
                btn_all.get_style_context().remove_class("btn-cat-active")
                btn_all.get_style_context().add_class("btn-cat")
            else:
                btn_all.get_style_context().remove_class("btn-cat")
                btn_all.get_style_context().add_class("btn-cat-active")
                btn_unsorted.get_style_context().remove_class("btn-cat-active")
                btn_unsorted.get_style_context().add_class("btn-cat")
            _rebuild_cards()

        btn_unsorted.connect("clicked", lambda *_: _set_scope("unsorted"))
        btn_all.connect("clicked",      lambda *_: _set_scope("all"))

        # ── BBS fetch ─────────────────────────────────────────────────────────
        def _do_fetch(*_):
            if _fetch_running[0]:
                return
            _fetch_running[0] = True
            fetch_btn.set_sensitive(False)
            prog.show()
            prog.set_fraction(0.0)
            prog.set_show_text(True)

            pool   = _get_pool()
            total  = len(pool)
            done   = [0]

            def _worker():
                with ThreadPoolExecutor(max_workers=3) as ex:
                    futures = {ex.submit(fetch_bbs_tags, e["base"]): e for e in pool}
                    for future in as_completed(futures):
                        entry = futures[future]
                        try:
                            tags = future.result()
                        except Exception:
                            tags = []
                        done[0] += 1
                        _tag_cache[id(entry)] = (entry, tags)
                        GLib.idle_add(_on_result, done[0], total)
                GLib.idle_add(_on_done)

            def _on_result(n, tot):
                try:
                    prog.set_fraction(n / tot)
                    prog.set_text(f"{n} / {tot}")
                except Exception:
                    pass
                return False

            def _on_done():
                try:
                    _fetch_done[0] = True
                    if _watchdog_id[0] is not None:
                        GLib.source_remove(_watchdog_id[0])
                        _watchdog_id[0] = None
                    prog.hide()
                    fetch_btn.set_sensitive(True)
                    _fetch_running[0] = False
                    _rebuild_cards()
                except Exception:
                    pass
                return False

            def _watchdog():
                if not _fetch_done[0]:
                    prog.hide()
                    fetch_btn.set_sensitive(True)
                    _fetch_running[0] = False
                    hint_lbl.set_markup(
                        '<span foreground="#ffec27">BBS fetch timed out — '
                        'keyword results shown</span>')
                return False

            threading.Thread(target=_worker, daemon=True).start()
            timeout_s = max(30, total * 2 + 10)
            _watchdog_id[0] = GLib.timeout_add_seconds(timeout_s, _watchdog)

        fetch_btn.connect("clicked", _do_fetch)

        # Initial build
        _rebuild_cards()
        dlg.show_all()
        prog.hide()
        resp = dlg.run()
        dlg.destroy()

        if resp != Gtk.ResponseType.OK:
            return

        # ── Apply: create checked categories and move entries ─────────────────
        created = 0
        moved   = 0
        for proposed_cat, (chk, name_entry, ents) in _sug_widgets.items():
            if not chk.get_active():
                continue
            final_name = name_entry.get_text().strip().upper()
            if not final_name:
                continue
            # Create category if it doesn't exist
            if final_name not in self._categories:
                self._categories.append(final_name)
                self._sections[final_name] = []
                created += 1
            # Move entries
            for entry in ents:
                # Find where the entry currently lives
                source_cat = None
                for cat, cat_entries in self._sections.items():
                    if any(id(e) == id(entry) for e in cat_entries):
                        source_cat = cat if cat != "UNSORTED" else None
                        break
                self._sel_entry = {"entry": entry, "source_cat": source_cat}
                self._assign_entry_to(final_name)
                moved += 1

        self._sel_entry      = None
        self._sel_row_widget = None
        self._refresh_unsorted_view()
        self._rebuild_cat_buttons()
        self._mark_dirty()
        self._set_status(
            f"Created {created} categor{'y' if created==1 else 'ies'}, "
            f"moved {moved} entr{'y' if moved==1 else 'ies'}")

    def _on_find_duplicates(self, *_):
        """Scan all loaded entries for exact-base or author+title duplicate
        groups and show a resolve-per-group dialog (keep-latest/keep-both)."""
        if not self._filepath:
            self._set_status("Open a favourites.txt first.", warn=True)
            return
        all_entries = list(self._unsorted)
        for entries in self._sections.values():
            all_entries.extend(entries)
        groups = find_duplicate_groups(all_entries)
        if not groups:
            self._set_status("No duplicates found.")
            return

        dlg = Gtk.Dialog(
            title=f"Duplicates \u2014 {len(groups)} group{'s' if len(groups) != 1 else ''}",
            transient_for=self, flags=Gtk.DialogFlags.MODAL)
        dlg.set_default_size(480, 420)
        dlg.add_button("Close", Gtk.ResponseType.CLOSE)
        box = dlg.get_content_area()
        box.set_margin_top(8); box.set_margin_bottom(8)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_size_request(460, 380)
        rows_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        rows_box.set_margin_start(8); rows_box.set_margin_end(8)
        scroll.add(rows_box)
        box.pack_start(scroll, True, True, 0)

        def _resolve(group, keep_both):
            if keep_both:
                self._set_status("Kept both \u2014 no changes made.")
                return
            keep = group[0]
            for e in group[1:]:
                eid = id(e)
                self._unsorted = [x for x in self._unsorted if id(x) != eid]
                for cat in list(self._sections.keys()):
                    self._sections[cat] = [x for x in self._sections[cat] if id(x) != eid]
            self._mark_dirty()
            self._refresh_unsorted_view()
            self._refresh_cat_view()
            self._rebuild_cat_buttons()
            self._update_total_count()
            self._set_status(f"Removed {len(group)-1} duplicate(s) of '{keep['title'][:40]}'")

        for group in groups:
            entries = group["entries"]
            row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            title  = entries[0]["title"][:48]
            author = entries[0]["author"][:30]
            lbl = Gtk.Label(
                label=f"{title}  \u2014  {len(entries)} copies (by {author})", xalign=0)
            lbl.set_ellipsize(Pango.EllipsizeMode.END)
            lbl.get_style_context().add_class("row-title")
            row.pack_start(lbl, False, False, 0)

            if group["kind"] == "revision":
                keep_label = "Keep Newest, Remove Rest"
            else:
                keep_label = "Keep First, Remove Rest"
                note = Gtk.Label(
                    label="Different BBS IDs \u2014 no revision order, verify before removing",
                    xalign=0)
                note.get_style_context().add_class("row-meta")
                note.set_ellipsize(Pango.EllipsizeMode.END)
                row.pack_start(note, False, False, 0)

            btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            b_latest = Gtk.Button(label=keep_label)
            b_latest.get_style_context().add_class("btn-danger")
            b_latest.set_size_request(0, 40)
            b_latest.connect("clicked", lambda w, g=entries: _resolve(g, False))
            b_both = Gtk.Button(label="Keep Both")
            b_both.get_style_context().add_class("btn-secondary")
            b_both.set_size_request(0, 40)
            b_both.connect("clicked", lambda w, g=entries: _resolve(g, True))
            btn_row.pack_start(b_latest, True, True, 0)
            btn_row.pack_start(b_both, True, True, 0)
            row.pack_start(btn_row, False, False, 0)
            rows_box.pack_start(row, False, False, 0)
            rows_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 0)

        dlg.show_all()
        dlg.run()
        dlg.destroy()

    def _on_reload(self, *_):
        """Re-parse favourites.txt from disk, discarding unsaved changes."""
        if not self._filepath:
            self._set_status("No file open.", warn=True)
            return
        dlg = Gtk.MessageDialog(
            transient_for=self, flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Reload file and discard unsaved changes?")
        dlg.format_secondary_text(
            "Re-reads favourites.txt from disk, exactly as it was after the "
            "last Save. Any moves, renames, or new categories made since "
            "then will be lost.")
        resp = dlg.run()
        dlg.destroy()
        if resp != Gtk.ResponseType.YES:
            return
        # Reset to the fixed default baseline before reloading — merging
        # against live (possibly-dirty) self._categories would let an
        # unsaved "Add Category" survive a reload, defeating the point.
        self._categories = list(DEFAULT_CATEGORIES)
        path = self._filepath
        self._load_file(path)
        self._set_status(f"Reloaded {os.path.basename(path)} \u2014 unsaved changes discarded")

    def _on_export_master(self, *_):
        """Export the master category JSON for transfer to another device."""
        if not self._filepath:
            self._set_status("Open a favourites.txt first.", warn=True)
            return
        dlg = Gtk.FileChooserDialog(
            title="Export Master List", transient_for=self,
            action=Gtk.FileChooserAction.SAVE)
        dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.STOCK_SAVE,   Gtk.ResponseType.OK)
        dlg.set_current_name("favourites-master-export.json")
        resp = dlg.run()
        dest = dlg.get_filename()
        dlg.destroy()
        if resp != Gtk.ResponseType.OK or not dest:
            return
        try:
            count = export_master_list(self._filepath, dest)
            self._set_status(f"Exported {count} slug(s) to {os.path.basename(dest)}")
        except Exception as ex:
            self._show_error(f"Export failed:\n{ex}")

    def _on_import_master(self, *_):
        """Import + merge a master category JSON from another device."""
        if not self._filepath:
            self._set_status("Open a favourites.txt first.", warn=True)
            return
        dlg = Gtk.FileChooserDialog(
            title="Import Master List", transient_for=self,
            action=Gtk.FileChooserAction.OPEN)
        dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.STOCK_OPEN,   Gtk.ResponseType.OK)
        resp = dlg.run()
        src = dlg.get_filename()
        dlg.destroy()
        if resp != Gtk.ResponseType.OK or not src:
            return
        try:
            count = import_merge_master_list(self._filepath, src)
            self._set_status(
                f"Merged {count} slug(s) from imported list. "
                "Reload the file to apply recovered categories.")
        except Exception as ex:
            self._show_error(f"Import failed:\n{ex}")

    # ── Config persistence ────────────────────────────────────────────────────
    def _load_config(self):
        try:
            if os.path.isfile(CONFIG_FILE):
                with open(CONFIG_FILE, encoding="utf-8") as f:
                    cfg = json.load(f)
                self._last_path = cfg.get("last_path")
        except Exception:
            self._last_path = None

    def _save_config(self):
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump({"last_path": self._last_path}, f)
        except Exception:
            pass

    # ── Dirty / unsaved changes tracking ─────────────────────────────────────
    def _mark_dirty(self):
        self._dirty = True
        title = self.get_title()
        if not title.startswith("*"):
            self.set_title("* " + title)

    def _clear_dirty(self):
        self._dirty = False
        title = self.get_title()
        if title.startswith("* "):
            self.set_title(title[2:])

    def _update_total_count(self):
        total = sum(len(v) for v in self._sections.values()) + len(self._unsorted)
        cats  = len([c for c in self._categories if self._sections.get(c)])
        self._total_lbl.set_text(f"{total} favourites  ·  {cats} categories")

    # ── File operations ───────────────────────────────────────────────────────
    def _check_dirty(self):
        """If unsaved changes exist, prompt. Returns True if OK to proceed."""
        if not self._dirty:
            return True
        dlg = Gtk.MessageDialog(
            transient_for=self,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.NONE,
            text="You have unsaved changes.")
        dlg.format_secondary_text("Save before opening a new file?")
        dlg.add_button("Save",     Gtk.ResponseType.YES)
        dlg.add_button("Discard",  Gtk.ResponseType.NO)
        dlg.add_button("Cancel",   Gtk.ResponseType.CANCEL)
        resp = dlg.run()
        dlg.destroy()
        if resp == Gtk.ResponseType.YES:
            self._on_save(None)
            # If save failed, _dirty is still True — don't proceed
            return not self._dirty
        if resp == Gtk.ResponseType.NO:
            return True
        return False  # Cancel — abort the open

    def _on_delete_event(self, win, event):
        """Intercept window close — warn if unsaved changes."""
        if self._dirty:
            dlg = Gtk.MessageDialog(
                transient_for=self,
                flags=Gtk.DialogFlags.MODAL,
                message_type=Gtk.MessageType.WARNING,
                buttons=Gtk.ButtonsType.NONE,
                text="You have unsaved changes.")
            dlg.format_secondary_text("Quit without saving?")
            dlg.add_button("Save & Quit",  Gtk.ResponseType.YES)
            dlg.add_button("Quit Anyway",  Gtk.ResponseType.NO)
            dlg.add_button("Cancel",       Gtk.ResponseType.CANCEL)
            resp = dlg.run()
            dlg.destroy()
            if resp == Gtk.ResponseType.YES:
                self._on_save(None)
                # Only quit if save succeeded (dirty cleared); keep open if it failed
                if not self._dirty:
                    Gtk.main_quit()
                    return False
                return True  # Save failed — keep window open
            if resp == Gtk.ResponseType.NO:
                Gtk.main_quit()
                return False
            return True  # Cancel — keep window open
        Gtk.main_quit()
        return False

    def _on_open(self, *_):
        if not self._check_dirty():
            return
        dlg = Gtk.FileChooserDialog(
            title="Open PICO-8 favourites.txt",
            transient_for=self,
            action=Gtk.FileChooserAction.OPEN)
        dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.STOCK_OPEN,   Gtk.ResponseType.OK)
        # Start in last known directory if available
        if self._last_path:
            dlg.set_filename(self._last_path)
        elif os.path.isfile(DEFAULT_FAV):
            dlg.set_filename(DEFAULT_FAV)
        f = Gtk.FileFilter(); f.set_name("Text files (*.txt)"); f.add_pattern("*.txt")
        dlg.add_filter(f)
        resp = dlg.run()
        path = dlg.get_filename()
        dlg.destroy()
        if resp != Gtk.ResponseType.OK or not path:
            return
        self._load_file(path)

    def _on_open_default(self, *_):
        if not self._check_dirty():
            return
        self._load_file(DEFAULT_FAV)

    def _load_file(self, path):
        """Parse and load a favourites.txt. Called by both open handlers and auto-open."""
        try:
            sections, cat_order, unsorted = parse_favourites(path)
        except Exception as ex:
            self._show_error(f"Could not parse file:\n{ex}")
            return False

        # ── Recover categories stripped by PICO-8 (master JSON reconcile) ──────
        # PICO-8 only ever prepends favourites.txt with no header; a stray
        # manual edit or a fresh re-export can also drop # category headers.
        # Anything sitting in Unsorted gets checked against the last-known
        # category recorded in favourites.txt.master.json.
        pool_unsorted = list(unsorted) + list(sections.pop("UNSORTED", []))
        known_cats = [c for c in cat_order if c != "UNSORTED"]
        for c in self._categories:
            if c not in known_cats:
                known_cats.append(c)
        sections, pool_unsorted, recovered = reconcile_stripped_categories(
            path, sections, pool_unsorted, known_cats)
        unsorted = pool_unsorted

        # ── Duplicate detection ───────────────────────────────────────────────
        # Collect all slugs across every section + unsorted
        all_entries = list(unsorted)
        for entries in sections.values():
            all_entries.extend(entries)
        seen_slugs = {}
        dup_slugs  = set()
        for e in all_entries:
            slug = e["slug"]
            if slug in seen_slugs:
                dup_slugs.add(slug)
            seen_slugs[slug] = e

        if dup_slugs:
            dlg = Gtk.MessageDialog(
                transient_for=self,
                flags=Gtk.DialogFlags.MODAL,
                message_type=Gtk.MessageType.WARNING,
                buttons=Gtk.ButtonsType.NONE,
                text=f"{len(dup_slugs)} duplicate entr{'y' if len(dup_slugs)==1 else 'ies'} found.")
            dup_titles = ", ".join(
                seen_slugs[s]["title"][:30] for s in list(dup_slugs)[:5])
            dlg.format_secondary_text(
                f"Duplicates: {dup_titles}\n\n"
                "Auto-remove keeps the first occurrence in each category.\n"
                "You can also remove them manually after loading.")
            dlg.add_button("Auto-Remove", Gtk.ResponseType.YES)
            dlg.add_button("Keep All",    Gtk.ResponseType.NO)
            resp = dlg.run()
            dlg.destroy()
            if resp == Gtk.ResponseType.YES:
                seen = set()
                for cat in list(sections.keys()):
                    deduped = []
                    for e in sections[cat]:
                        if e["slug"] not in seen:
                            seen.add(e["slug"])
                            deduped.append(e)
                    sections[cat] = deduped
                deduped_u = []
                for e in unsorted:
                    if e["slug"] not in seen:
                        seen.add(e["slug"])
                        deduped_u.append(e)
                unsorted = deduped_u

        self._filepath  = path
        self._sections  = sections
        self._cat_order = cat_order
        self._unsorted  = unsorted
        # Track which slugs were unsorted at open time for NEW indicator
        self._new_slugs = {e["slug"] for e in unsorted}

        # Merge file categories with defaults (file order first, then defaults).
        # "UNSORTED" is never a clickable category button — handled separately.
        merged = [c for c in cat_order if c != "UNSORTED"]
        for c in self._categories:
            if c not in merged and c != "UNSORTED":
                merged.append(c)
        self._categories = merged

        if "UNSORTED" not in self._sections:
            self._sections["UNSORTED"] = []

        self._sel_entry      = None
        self._sel_row_widget = None
        self._sel_cat        = None
        self._cat_title_lbl.set_text("SELECT A CATEGORY")
        self._cat_count_lbl.set_text("")

        self._rebuild_cat_buttons()
        self._refresh_unsorted_view()
        self._refresh_cat_view()
        self._save_btn.set_sensitive(True)
        self._update_total_count()
        self._clear_dirty()

        # Persist last opened path
        self._last_path = path
        self._save_config()

        total = sum(len(v) for v in self._sections.values()) + len(self._unsorted)
        uns   = len(self._sections.get("UNSORTED", [])) + len(self._unsorted)
        recovered_note = f"  ·  {recovered} recovered" if recovered else ""
        self._set_status(
            f"Loaded: {os.path.basename(path)}  ·  "
            f"{uns} unsorted  ·  {total} total{recovered_note}")
        return False  # GLib.idle_add expects False to not repeat

    def _on_save(self, *_):
        if not self._filepath:
            self._set_status("No file open.", warn=True)
            return
        try:
            backup = write_favourites(
                self._filepath, self._categories,
                self._sections, self._unsorted)
            # Full master-JSON resync — safety net for moves not already
            # persisted incrementally (e.g. Auto-Sort's checkbox apply).
            for cat, entries in self._sections.items():
                if cat != "UNSORTED" and entries:
                    set_master_category_for_entries(self._filepath, entries, cat)
            self._update_total_count()
            self._clear_dirty()
            self._set_status(f"Saved ✓  —  backup: {os.path.basename(backup)}")
        except Exception as ex:
            self._show_error(f"Save failed:\n{ex}")

    # ── Helpers ───────────────────────────────────────────────────────────────
    def _set_status(self, msg, warn=False):
        self._status_lbl.set_text(msg)
        ctx = self._status_lbl.get_style_context()
        if warn:
            ctx.remove_class("status-msg")
            ctx.add_class("status-warn")
        else:
            ctx.remove_class("status-warn")
            ctx.add_class("status-msg")

    def _show_error(self, msg):
        dlg = Gtk.MessageDialog(
            transient_for=self, flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK, text=msg)
        dlg.run(); dlg.destroy()

# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    win = FavSorterWindow()
    win.show_all()
    Gtk.main()
PYEOF

    chmod +x "$GUI_SCRIPT"
    log_ok "GUI script written: ${GUI_SCRIPT}"
}

# ── Install ───────────────────────────────────────────────────────────────────
do_install() {
    log_section "Installing PICO-8 Favourites Sorter"

    if [[ -f "$GUI_SCRIPT" ]]; then
        log_warn "Already installed. Use Repair (option 2) to refresh."
        press_enter
        return
    fi

    _rollback_begin "install"

    install_gui_deps
    write_gui_icon
    write_gui_script
    write_gui_desktop

    _rollback_end

    echo ""
    log_ok "Installation complete."
    echo ""
    echo -e "  GUI script : ${CYAN}${GUI_SCRIPT}${NC}"
    echo -e "  Desktop    : ${CYAN}${GUI_DESKTOP}${NC}"
    echo ""
    echo -e "  Launch via the applications menu or:"
    echo -e "  ${BOLD}python3 ${GUI_SCRIPT}${NC}"
    echo ""
    press_enter
}

# ── Repair ────────────────────────────────────────────────────────────────────
do_repair() {
    log_section "Repairing PICO-8 Favourites Sorter"
    _rollback_begin "repair"

    install_gui_deps
    write_gui_icon
    write_gui_script
    write_gui_desktop

    _rollback_end
    log_ok "Repair complete — all files regenerated from this script."
    press_enter
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
    log_section "Uninstalling PICO-8 Favourites Sorter"

    if ! confirm "This will remove all installed files. Continue?"; then
        log_warn "Uninstall cancelled."
        return
    fi

    [[ -f "$GUI_SCRIPT" ]]  && rm -f "$GUI_SCRIPT"  && log_ok "Removed: $GUI_SCRIPT"
    [[ -f "$GUI_DESKTOP" ]] && rm -f "$GUI_DESKTOP" && log_ok "Removed: $GUI_DESKTOP"
    [[ -f "$GUI_ICON" ]]    && rm -f "$GUI_ICON"    && log_ok "Removed: $GUI_ICON"

    update-desktop-database "$GUI_DESKTOP_DIR" 2>/dev/null || true
    gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true

    [[ -d "$STATE_DIR" ]] && rm -rf "$STATE_DIR" && log_ok "Removed state dir: $STATE_DIR"

    # Dependencies kept — shared with cava-manager / script-launcher-manager
    log_info "python3-gi / GTK3 deps are kept (shared with other tools)."

    echo ""
    log_ok "PICO-8 Favourites Sorter fully uninstalled."
    echo ""
    exit 0
}

# ── Restore from backup ───────────────────────────────────────────────────────
do_restore() {
    log_section "Restore favourites.txt from Backup"

    local FAV_FILE="${HOME}/.lexaloffle/pico-8/favourites.txt"
    local BAK_FILE="${FAV_FILE}.bak"

    if [[ ! -f "$BAK_FILE" ]]; then
        log_warn "No backup found at: ${BAK_FILE}"
        log_info "A backup is created automatically each time you Save in the GUI."
        press_enter
        return
    fi

    echo ""
    echo -e "  ${CYAN}Backup file:${NC}  ${BAK_FILE}"
    echo -e "  ${CYAN}Live file:${NC}    ${FAV_FILE}"
    echo ""
    echo -e "  Backup size : $(wc -l < "$BAK_FILE") lines"
    if [[ -f "$FAV_FILE" ]]; then
        echo -e "  Live size   : $(wc -l < "$FAV_FILE") lines"
    else
        log_warn "Live favourites.txt not found — restore will create it."
    fi
    echo ""

    if ! confirm "Replace live favourites.txt with the backup?"; then
        log_warn "Restore cancelled."
        press_enter
        return
    fi

    # Safety: back up the current live file before overwriting
    if [[ -f "$FAV_FILE" ]]; then
        local SAFETY="${FAV_FILE}.pre-restore"
        cp "$FAV_FILE" "$SAFETY"
        log_info "Current live file saved to: ${SAFETY}"
    fi

    cp "$BAK_FILE" "$FAV_FILE"
    log_ok "Restored: ${BAK_FILE} -> ${FAV_FILE}"
    echo ""
    log_info "Restart PICO-8 for changes to take effect in Splore."
    press_enter
}

# ── Main menu ─────────────────────────────────────────────────────────────────
main_menu() {
    _check_partial_state

    while true; do
        clear
        echo ""
        echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}${BOLD}  PICO-8 Favourites Sorter  v${SCRIPT_VERSION}${NC}"
        echo -e "${CYAN}${BOLD}  Manager Script${NC}"
        echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
        echo ""
        gui_status
        echo ""
        echo -e "  ${CYAN}1)${NC}  Install"
        echo -e "  ${CYAN}2)${NC}  Repair  (regenerate GUI from this script)"
        echo -e "  ${CYAN}3)${NC}  Launch GUI"
        echo -e "  ${CYAN}4)${NC}  Restore favourites.txt from backup"
        echo -e "  ${CYAN}5)${NC}  Uninstall"
        echo -e "  ${CYAN}6)${NC}  Exit"
        echo ""
        read -rp "$(echo -e "${CYAN}  Choose [1-6]: ${NC}")" CHOICE

        case "$CHOICE" in
            1) do_install   ;;
            2) do_repair    ;;
            3)
                if [[ -f "$GUI_SCRIPT" ]]; then
                    python3 "$GUI_SCRIPT" &
                    log_ok "PICO-8 Favourites Sorter launched."
                    sleep 1
                else
                    log_warn "Not installed. Run Install (option 1) first."
                    press_enter
                fi
                ;;
            4) do_restore   ;;
            5) do_uninstall ;;
            6)
                echo ""
                echo "  Goodbye!"
                echo ""
                exit 0
                ;;
            *) log_warn "Invalid choice. Enter 1-6." ; sleep 1 ;;
        esac
    done
}

# ── Entry point ───────────────────────────────────────────────────────────────
refuse_root
main_menu
