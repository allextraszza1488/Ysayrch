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

# the two recipes: alpenflage.lua and tigerstripe.lua
LOOKS_DIR=$HOME/.config/hypr/looks
# hyprland.lua dofile()s this on every reload; this script overwrites it
STATE=$HOME/.config/hypr/look-state.lua
# plain text file holding just the current look's name
MARKER=$HOME/.config/hypr/current-look

# no marker yet means first run; assume alpenflage so the first toggle goes to tigerstripe
current=$(cat "$MARKER" 2>/dev/null || echo "alpenflage")

# three looks now, cycle in a fixed order
case "$current" in
  alpenflage)  next="tigerstripe" ;;
  tigerstripe) next="gyaru" ;;
  *)           next="alpenflage" ;;
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

# gyaru's "wallpaper" field is a folder, not a file -- pick one at random.
# `|| true` on the pipeline: under set -euo pipefail, a MISSING folder makes
# find itself fail, which would otherwise abort the whole script right here
# -- after borders/kitty/fuzzel/btop already flipped to gyaru but before
# hyprpaper.conf is touched, a half-applied toggle. An EMPTY (but existing)
# folder doesn't fail, it just leaves $wallpaper blank -- caught explicitly
# below instead, since a blank `path =` line would black-screen hyprpaper.
if [ "$next" = "gyaru" ]; then
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
