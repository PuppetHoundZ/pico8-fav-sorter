# PICO-8 `favourites.txt` — Complete Reference

> Documented from hands-on analysis of a real favourites file on MustardOS (muOS)
> running on an Anbernic RG Cube XX-H with PICO-8 Splore, plus real-world
> observations from building the PICO-8 Favourites Sorter (muOS Edition).

---

## What is `favourites.txt`?

`favourites.txt` is the plain-text database PICO-8 Splore uses to store your
favourited carts. It is human-readable and hand-editable. Splore reads it on
launch and writes it whenever you favourite or unfavourite a cart.

### File location

| Environment                   | Path                                                  |
| ----------------------------- | ----------------------------------------------------- |
| muOS (runtime bind-mount)     | `/run/muos/storage/save/pico8/favourites.txt`         |
| muOS SD card (direct)         | `/mnt/mmc/MUOS/save/pico8/favourites.txt`             |
| Standard Linux / Raspberry Pi | `~/.lexaloffle/pico-8/favourites.txt`                 |
| macOS                         | `~/Library/Application Support/pico-8/favourites.txt` |
| Windows                       | `%APPDATA%\pico-8\favourites.txt`                     |

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

## ⚠️ Category-strip on save (confirmed behaviour)

This is the single most important thing to know if you're editing this file
by hand or building a tool around it:

**PICO-8 Splore rewrites the entire file whenever it saves a new
favourite/unfavourite — and that rewrite can strip every category header,
collapsing the file back down to one flat unsorted list, while
preserving the entries' relative order.**

What's preserved across a Splore-triggered rewrite:
- Every entry line (all 6 columns), and their **relative order**.

What's *not* reliably preserved:
- Category headers (`# === NAME ===` blocks) — Splore's own save path does
  not always re-derive and re-emit them from whatever internal state it
  keeps, so a save can silently flatten a carefully organised file back to
  "everything unsorted."

### Practical implications

- **Any external tool that organises this file must assume its
  organisation can be wiped by PICO-8 itself at any time**, not just by
  user error. Do not treat "zero category headers on load" as "the user
  wants a flat list" — treat it as a signal to attempt recovery.
- Because entry **order** survives even when headers don't, order is a
  usable recovery signal: if you have a prior known-good snapshot (a
  backup, or your own persistent record) that maps each entry's slug to a
  category, you can reconstruct categorisation for a stripped file by
  slug lookup, independent of position.
- PICO-8's own automatic timestamped backups (`.bak_YYYYMMDD_HHMMSS`) are
  taken **before** a save, so if PICO-8 strips categories on save N, the
  backup for save N was written pre-strip — but the backup for save N+1
  captures the *already-stripped* state. A backup-only recovery strategy
  needs to walk backups newest-first looking for the most recent one that
  still has category headers, since the very newest backup can itself be
  post-strip.
- A more robust recovery approach is to keep your **own** persistent,
  append-only slug → category record outside of `favourites.txt` entirely
  (not subject to PICO-8's rewrite behaviour at all), and prefer that
  record over backup-scanning whenever it has an entry for a given slug.
- Recovery should never write anything back to disk automatically —
  reconstruct the mapping in memory/UI first and let the user confirm
  before it's saved, since a bad reconstruction is itself a data-loss risk.
- A recovery pass should also guard against false positives on files that
  are *legitimately* flat (a fresh install, or a file that was never
  categorised) — e.g. only attempt slug-based reconstruction if a
  meaningful fraction of current entries actually match known slugs from
  the backup/record being consulted.

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

| Column | Field                   | Example (named) | Example (numeric) | Notes                                         |
| ------ | ------------------------ | --------------- | ------------------ | --------------------------------------------- |
| 1      | **Versioned slug**       | `nightcrawl-2`  | `49232`            | Cart identifier + revision, or legacy post ID |
| 2      | **Base slug / cart ID**  | `nightcrawl`    | `49234`             | Base name without revision, or cart post ID   |
| 3      | **PICO-8 version**       | `1794`          | `1794`              | Version of PICO-8 that wrote this entry       |
| 4      | **Author**               | `achie72`       | `bridgs`            | BBS username of the cart author               |
| 5      | *(blank)*                |                 |                     | Always empty in practice; reserved field. Note: some parsers default a missing/blank column 2 back to column 1 as a fallback for the *base slug* field specifically — if you write that kind of fallback, use an explicit "is this key present" check rather than a falsy-value check, since a legitimately blank field and a missing field are not the same thing. |
| 6      | **Display title**        | `nightcrawl`    | `just one boss`     | Human-readable title shown in Splore          |

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
- Different revisions of the same base slug are **not necessarily duplicates in
  the "remove one" sense** — they can be legitimate distinct favourites (e.g. the
  user deliberately kept two revisions). Treat same-base-slug groups as a
  candidate list for *manual* review, not an auto-delete target.

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

| Cart type  | URL pattern                                    | Example           |
| ---------- | ----------------------------------------------- | ------------------ |
| Named slug | `https://www.lexaloffle.com/bbs/?pid=BASENAME` | `?pid=nightcrawl`  |
| Numeric    | `https://www.lexaloffle.com/bbs/?pid=COL2`     | `?pid=49234`       |

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
- If you're building tooling with an internal "UNSORTED" bucket name for your
  own state-management purposes, treat that string as **reserved** end-to-end:
  guard against a user creating, renaming, or retargeting a *real* category to
  that exact name, since it can silently collide with (and overwrite) the
  actual unsorted bucket's contents.

---

## PICO-8 version field (column 3)

The number in column 3 (e.g. `1794`, `1800`, `1807`) is the internal PICO-8
version that saved the entry. It does not affect playback. Common values seen:

| Value  | Approximate PICO-8 release |
| ------ | --------------------------- |
| `1792` | 0.2.5 era                   |
| `1794` | 0.2.6 (most common)         |
| `1795` | 0.2.6b                      |
| `1799` | 0.2.6c                      |
| `1800` | 0.2.6d                      |
| `1807` | 0.2.7+                      |

---

## Editing safely by hand

1. **Always make a backup** before editing. PICO-8 makes timestamped backups
   automatically on save (`.bak_YYYYMMDD_HHMMSS`) — but see
   [Category-strip on save](#️-category-strip-on-save-confirmed-behaviour) above:
   don't assume the newest backup is itself uncorrupted.
2. **Keep the pipe formatting.** Column widths are padded with spaces but the
   widths are not enforced — Splore splits on `|` regardless.
3. **Category names must be uppercase** or they will not be recognised.
4. **Blank lines** between entries and between sections are ignored and harmless.
5. **Do not duplicate entries.** The same slug in two categories will appear twice
   in Splore. PICO-8 does not deduplicate on read.
6. If a cart appears in a named category **and** in unsorted, remove the unsorted
   copy — the categorised one is canonical.
7. **Remove entries by identity, not by value equality**, if you're scripting
   edits. Two entries can be equal-by-value (identical fields) while being
   distinct rows the user intends to keep separately; a value-based `remove()`
   can delete the wrong one, or delete more than intended, silently.
8. **Expect the file to be rewritten out from under you.** If your tool holds
   the file open, cached, or mid-edit, and PICO-8 itself saves in the
   background, don't assume your last-loaded copy is still authoritative —
   re-check the on-disk state (or a change signal) before writing your own
   changes back, or you risk clobbering a legitimate PICO-8-side update.

---

## Duplicate detection

Two entries are duplicates if they share the same **base slug** (column 2 for
named carts, or the same numeric IDs for legacy carts). Title and author alone
are not sufficient — two different carts can have the same display title.

```
# Pseudocode duplicate check
base_slug = col2  # for named; or col1 for numeric
if base_slug seen before → duplicate
```

A second, weaker signal worth surfacing (but not auto-acting on) is **same
author + near-identical title across different base slugs** — this can catch
genuinely distinct carts by the same author with similar names, which are not
true duplicates, so this signal is best treated as an information-only
prompt for manual review rather than something a tool resolves automatically.

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

*Reference compiled June 2026 from direct file analysis and PICO-8 BBS verification,
with additions from real-world tooling experience building an external
`favourites.txt` organiser.*
