#!/bin/bash
# -----------------------------------------------------------------------------
# Regenerates fuzzel.ini's [colors] block from the active look's kitty
# palette (background/foreground/cursor/color0-15) -- reuses the already
# hand-tuned per-look colors instead of inventing a second palette format.
#
# Called by toggle-look.sh as: apply-look.sh <look-name>
#
# Fuzzel has no running daemon to reload -- it's launched fresh on every
# invocation (SUPER+D, SUPER+Tab, SUPER+Space, etc.), so rewriting the file
# is enough; the next launch just picks it up. No restart/signal needed.
# -----------------------------------------------------------------------------
set -euo pipefail

look=${1:?usage: apply-look.sh <look-name>}
kitty_conf="$HOME/.config/kitty/looks/$look.conf"
fuzzel_ini="$HOME/.config/fuzzel/fuzzel.ini"

if [ ! -f "$kitty_conf" ]; then
  echo "apply-look(fuzzel): no kitty look file for '$look', leaving fuzzel.ini as-is" >&2
  exit 0
fi

field() { awk -v k="$1" '$1==k {print $2; exit}' "$kitty_conf" | tr -d '#'; }

bg=$(field background)
fg=$(field foreground)
cursor=$(field cursor)
dim=$(field color8)
accent2=$(field color3)

# fuzzel.ini wants 8-digit RGBA; kitty's look files are 6-digit RGB.
bg="${bg}f5"
fg_a="${fg}ff"
matchcolor="${cursor}ff"
selection="${dim}cc"
selection_text="${fg}ff"
selection_match="${accent2}ff"
border="${cursor}ff"

# "match" is an awk builtin function name -- using it as a -v variable name
# fails with "cannot use gawk builtin `match' as variable name", caught by
# testing this against all three looks before wiring it into toggle-look.sh.
awk -v bg="$bg" -v fg="$fg_a" -v matchcolor="$matchcolor" -v sel="$selection" \
    -v seltext="$selection_text" -v selmatch="$selection_match" -v border="$border" '
  /^\[colors\]/          { print; in_colors=1; next }
  /^\[/ && !/^\[colors\]/ { in_colors=0 }
  in_colors && /^background=/       { print "background=" bg; next }
  in_colors && /^text=/             { print "text=" fg; next }
  in_colors && /^match=/            { print "match=" matchcolor; next }
  in_colors && /^selection=/        { print "selection=" sel; next }
  in_colors && /^selection-text=/   { print "selection-text=" seltext; next }
  in_colors && /^selection-match=/  { print "selection-match=" selmatch; next }
  in_colors && /^border=/           { print "border=" border; next }
  { print }
' "$fuzzel_ini" > "$fuzzel_ini.tmp"
mv "$fuzzel_ini.tmp" "$fuzzel_ini"
