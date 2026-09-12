#!/bin/bash
# -----------------------------------------------------------------------------
# Interactive command-phrase palette: fuzzel over ~/.config/reference/phrases.txt
# ("name | description | command"), types the chosen command into whatever's
# focused. Bound to SUPER+A -- unshifted pair to SUPER+SHIFT+A (shortcuts-hub,
# which only *displays* reference sheets; this one actually inserts a command).
#
# Needs wtype to type into the focused window. Not installed on this machine
# yet (`sudo pacman -S wtype`, official repo, not AUR) -- falls back to
# copying to the clipboard + a notification telling you to paste instead, so
# this still works today, just with one extra keypress until wtype is there.
# -----------------------------------------------------------------------------
set -euo pipefail

PHRASES="$HOME/.config/reference/phrases.txt"
[ -f "$PHRASES" ] || exit 0

# name + description shown in the list; command stays hidden until chosen.
# "|" separated, comments/blank lines skipped.
list=$(grep -vE '^\s*(#|$)' "$PHRASES" | awk -F'\\|' '{gsub(/^ +| +$/, "", $1); gsub(/^ +| +$/, "", $2); print $1 " — " $2}')
[ -z "$list" ] && exit 0

# || true: fuzzel exits non-zero on Escape, which under set -e would abort
# before the empty-check below runs (same pattern fixed elsewhere this session).
chosen=$(echo "$list" | fuzzel --dmenu --prompt "phrase> " || true)
[ -z "$chosen" ] && exit 0

# match the chosen "name — description" back to its line, pull the command
# (3rd "|" field) out of the real data file rather than re-parsing the
# fuzzel-displayed text, same array/lookup-reuse principle as
# window-switcher.sh/workspace-overview.sh.
name=$(echo "$chosen" | sed 's/ — .*//')
# Reconstruct field 3 onward joined by "|" -- some commands (hyprctl ... | jq)
# contain a literal pipe themselves, which a plain $3 would truncate at.
# Caught by testing this against the hypr-clients/hypr-monitors entries
# before wiring this into a real keybind.
command=$(grep -vE '^\s*(#|$)' "$PHRASES" | awk -F'\\|' -v n="$name" '
  { gsub(/^ +| +$/, "", $1); if ($1 == n) {
      cmd = $3
      for (i = 4; i <= NF; i++) cmd = cmd "|" $i
      gsub(/^ +| +$/, "", cmd)
      print cmd
      exit
    }
  }')
[ -z "$command" ] && exit 0

if command -v wtype >/dev/null 2>&1; then
  wtype -- "$command"
else
  printf '%s' "$command" | wl-copy
  notify-send "Phrase copied" "wtype not installed -- paste with ctrl+shift+v" 2>/dev/null || true
fi
