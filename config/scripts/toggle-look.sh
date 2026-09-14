#!/bin/bash
# -----------------------------------------------------------------------------
# Swaps the active "look" and reloads everything that shows it.
# Bound to SUPER+SHIFT+T.
#
# Reaches: hyprland borders/glow, kitty colours, wallpaper, fuzzel, btop.
# Still does NOT reach: waybar, mako -- both need a live-reload/restart step
# this script doesn't do yet, so they keep hardcoded colours for now.
# -----------------------------------------------------------------------------
set -euo pipefail

LOOKS_DIR=$HOME/.config/hypr/looks
# hyprland.lua dofile()s this on every reload; this script overwrites it
STATE=$HOME/.config/hypr/look-state.lua
# plain text file holding just the current look's name
MARKER=$HOME/.config/hypr/current-look

current=$(cat "$MARKER" 2>/dev/null || echo "0xyc")

# 0xyc (hacky dark) → mdmamph (wife) → diyetlyser (junkyard) → 0xyc
case "$current" in
  0xyc)       next="mdmamph" ;;
  mdmamph)    next="diyetlyser" ;;
  diyetlyser) next="0xyc" ;;
  # leftovers from the old names
  tigerstripe|alpenflage|gyaru) next="0xyc" ;;
  *)          next="0xyc" ;;
esac

# hyprland picks this up on the reload below
cp "$LOOKS_DIR/$next.lua" "$STATE"
echo "$next" > "$MARKER"

export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"
# re-reads hyprland.lua, which re-reads look-state.lua
hyprctl reload

# kitty.conf includes this file; only NEW kitty windows pick it up
cp $HOME/.config/kitty/looks/"$next".conf \
   $HOME/.config/kitty/active-look.conf

# fuzzel: no daemon to reload, next launch just picks up the rewritten file.
# btop: always spawned fresh (CTRL+ALT+Delete), same deal, no reload needed.
"$HOME/.config/fuzzel/apply-look.sh" "$next"
"$HOME/.config/btop/apply-look.sh" "$next"

# parse the recipe with real Lua rather than grepping Lua syntax with sed
wallpaper=$(lua5.4 -e "io.write(dofile('$LOOKS_DIR/$next.lua').wallpaper)")

# If a look's wallpaper field is a directory, pick one file at random.
# File paths are used as-is. Palettes do not sample the image.
if [ -d "$wallpaper" ]; then
  wallpaper=$(find "$wallpaper" -maxdepth 1 -type f 2>/dev/null | shuf -n1 || true)
fi

if [ -z "$wallpaper" ]; then
  echo "toggle-look: no wallpaper file resolved for '$next' -- leaving the current wallpaper alone" >&2
else
  # hyprpaper has no reload command, so its config is rewritten and it is restarted
  cat > $HOME/.config/hypr/hyprpaper.conf <<EOF2
preload = $wallpaper
wallpaper {
    monitor =
    path = $wallpaper

    fit_mode = cover

}
EOF2

  # ---------------------------------------------------------------------------
  # Start the NEW hyprpaper BEFORE killing the old one. Kill-then-start left a
  # visible gap with no wallpaper daemon at all. Overlapping means there is
  # never a moment with zero instances running.
  # ---------------------------------------------------------------------------
  old_pids=$(pgrep -x hyprpaper || true)
  hyprpaper &
  new_pid=$!
  disown
  sleep 0.3
  # only the OLD pids, never the one just started
  for pid in $old_pids; do
    kill "$pid" 2>/dev/null || true
  done
fi

# mako shows this; || true so a missing notification daemon is not fatal
notify-send "Look" "Switched to $next" 2>/dev/null || true
