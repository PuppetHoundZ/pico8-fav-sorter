# PICO-8 `favourites.txt` — Complete Reference

> Documented from hands-on analysis of a real favourites file on MustardOS (muOS)  
> running on an Anbernic RG Cube XX-H with PICO-8 Splore.

---

## What is `favourites.txt`?

`favourites.txt` is the plain-text database PICO-8 Splore uses to store your
favourited carts. It is human-readable and hand-editable. Splore reads it on
launch and writes it whenever you favourite or unfavourite a cart.

### File location

| Environment | Path |
|---|---|
| muOS (runtime bind-mount) | `/run/muos/storage/save/pico8/favourites.txt` |
| muOS SD card (direct) | `/mnt/mmc/MUOS/save/pico8/favourites.txt` |
| Standard Linux / Raspberry Pi | `~/.lexaloffle/pico-8/favourites.txt` |
| macOS | `~/Library/Application Support/pico-8/favourites.txt` |
| Windows | `%APPDATA%\pico-8\favourites.txt` |

---

## File structure

The file has two types of content: **section headers** and **entry lines**.
Everything else (blank lines, comment lines starting with `#`) is ignored by
PICO-8 and can be used freely for your own annotations.

```
# ============================================================
# CATEGORY NAME
# ============================================================

# https://www.lexaloffle.com/bbs/?pid=nightcrawl
|nightcrawl-2         |nightcrawl           |1794   |achie72          |                     |nightcrawl
```

---

## Section headers

A category block always uses exactly this three-line pattern:

```
# ============================================================
# CATEGORY NAME
# ============================================================
```

Rules:
- The divider lines must have **three or more** `=` characters after `# `.
- The category name line must start with `# ` followed by an **uppercase letter**.
- Category names are case-sensitive. `# Roguelikes` would not be recognised the
  same as `# ROGUELIKES`.
- An empty category (header with no entries below it) is valid and survives a
  save/reload cycle — Splore writes it back out on next save.

---

## Entry lines

Each favourited cart is stored as a single pipe-delimited line:

```
|col1                 |col2                 |col3   |col4             |col5                 |col6
```

### Named cart example
```
|nightcrawl-2         |nightcrawl           |1794   |achie72          |                     |nightcrawl
```

### Numeric (legacy) cart example
```
|49232                |49234                |1794   |bridgs           |                     |just one boss
```

### Column breakdown

| Column | Field | Example (named) | Example (numeric) | Notes |
|---|---|---|---|---|
| 1 | **Versioned slug** | `nightcrawl-2` | `49232` | Cart identifier + revision, or legacy post ID |
| 2 | **Base slug / cart ID** | `nightcrawl` | `49234` | Base name without revision, or cart post ID |
| 3 | **PICO-8 version** | `1794` | `1794` | Version of PICO-8 that wrote this entry |
| 4 | **Author** | `achie72` | `bridgs` | BBS username of the cart author |
| 5 | *(blank)* | | | Always empty in practice; reserved field |
| 6 | **Display title** | `nightcrawl` | `just one boss` | Human-readable title shown in Splore |

---

## The slug and revision number

The **versioned slug** (column 1) takes the form `cartname-N` where `N` is the
upload revision:

```
nightcrawl-2    →  base name: nightcrawl,  revision: 2
bunbunsamurai-13 → base name: bunbunsamurai, revision: 13
```

- The revision increments every time the author uploads a new version of the cart.
- PICO-8 Splore always fetches the **latest** version regardless of which revision
  is stored here — the number is informational only.
- The revision number in the slug is **independent** of the version number in the
  title (e.g. `cab ride 1.2`). The slug revision counts uploads; the title version
  is whatever the developer chose to display.

### Numeric slugs (legacy format)

Older carts that predate the named-slug system use bare numbers in both columns:

```
|49232                |49234                |1794   |bridgs           |                     |just one boss
```

- Column 1 is the BBS **thread ID**.
- Column 2 is the BBS **cart/post ID**.
- The BBS URL for these uses column 2: `https://www.lexaloffle.com/bbs/?pid=49234`

---

## BBS URLs

To find a cart on the Lexaloffle BBS:

| Cart type | URL pattern | Example |
|---|---|---|
| Named slug | `https://www.lexaloffle.com/bbs/?pid=BASENAME` | `?pid=nightcrawl` |
| Numeric | `https://www.lexaloffle.com/bbs/?pid=COL2` | `?pid=49234` |

Strip the `-N` revision suffix from named slugs — `nightcrawl-2` → `?pid=nightcrawl`.

---

## Comment lines and annotations

Any line beginning with `#` that does **not** match the divider or category
name pattern is silently ignored by PICO-8. This makes them safe for annotations:

```
# https://www.lexaloffle.com/bbs/?pid=nightcrawl
|nightcrawl-2         |nightcrawl           |1794   |achie72          |                     |nightcrawl
```

Rules for safe comment lines:
- Must start with `# ` (hash space).
- Must **not** consist of only `=` characters (would be parsed as a divider).
- Must **not** start with an uppercase letter after `# ` (would be parsed as a
  category name — e.g. `# ROGUELIKES` would open a new category).
- URLs are inherently safe because they start with lowercase `h`.

---

## Unsorted entries

Entries that appear **before** the first category header, with no section block
above them, are treated by Splore as unsorted / unfiled:

```
|someentry-0          |someentry            |1794   |someauthor       |                     |some game
|anotherone-1         |anotherone           |1794   |someone          |                     |another game

# ============================================================
# FIRST CATEGORY
# ============================================================
```

- They appear in Splore under no named category.
- When writing the file back out, unsorted entries should come **first**, before
  any category headers, with **no wrapper header of their own**.
- Do not write them under a `# UNSORTED` header — Splore would treat that as a
  real category named "UNSORTED".

---

## PICO-8 version field (column 3)

The number in column 3 (e.g. `1794`, `1800`, `1807`) is the internal PICO-8
version that saved the entry. It does not affect playback. Common values seen:

| Value | Approximate PICO-8 release |
|---|---|
| `1792` | 0.2.5 era |
| `1794` | 0.2.6 (most common) |
| `1795` | 0.2.6b |
| `1799` | 0.2.6c |
| `1800` | 0.2.6d |
| `1807` | 0.2.7+ |

---

## Editing safely by hand

1. **Always make a backup** before editing. PICO-8 makes timestamped backups
   automatically on save (`.bak_YYYYMMDD_HHMMSS`).
2. **Keep the pipe formatting.** Column widths are padded with spaces but the
   widths are not enforced — Splore splits on `|` regardless.
3. **Category names must be uppercase** or they will not be recognised.
4. **Blank lines** between entries and between sections are ignored and harmless.
5. **Do not duplicate entries.** The same slug in two categories will appear twice
   in Splore. PICO-8 does not deduplicate on read.
6. If a cart appears in a named category **and** in unsorted, remove the unsorted
   copy — the categorised one is canonical.

---

## Duplicate detection

Two entries are duplicates if they share the same **base slug** (column 2 for
named carts, or the same numeric IDs for legacy carts). Title and author alone
are not sufficient — two different carts can have the same display title.

```python
# Pseudocode duplicate check
base_slug = col2  # for named; or col1 for numeric
if base_slug seen before → duplicate
```

---

## Category order

Categories appear in Splore in the **order they appear in the file**. You control
the display order simply by reordering the section blocks in the file.

---

## Full annotated example

```
# ============================================================
# ROGUELIKES / DUNGEON CRAWLERS
# ============================================================

# https://www.lexaloffle.com/bbs/?pid=nightcrawl
|nightcrawl-2         |nightcrawl           |1794   |achie72          |                     |nightcrawl

# https://www.lexaloffle.com/bbs/?pid=49234
|49232                |49234                |1794   |bridgs           |                     |just one boss

# https://www.lexaloffle.com/bbs/?pid=dank_tomb
|dank_tomb-0          |dank_tomb            |1794   |krajzeg          |                     |dank tomb 1.1b
```

---

*Reference compiled June 2026 from direct file analysis and PICO-8 BBS verification.*
