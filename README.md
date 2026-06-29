Self-contained — generates all required files on Install:

* pico8-fav-sorter  (GTK3 Python GUI)   → ~/.local/bin/pico8-fav-sorter
* Desktop shortcut + SVG icon           → ~/.local/share/

No companion files required. Distribute and run this single script.

Purpose:
PICO-8 dumps all newly favourited carts at the top of favourites.txt.
This GUI lets you open that file, assign unsorted entries to labelled
category sections (* headers), move/reorder entries within categories,
sort a category A→Z by author, and save back — preserving every line
exactly as PICO-8 wrote it (spacing, pipes, encoding).

Usage:
chmod +x pico8-fav-sorter-manager.sh
./pico8-fav-sorter-manager.sh

Do NOT run as root.
