#!/bin/bash
# -----------------------------------------------------------------------------
# Swaps the TOP bar between the normal one (~/.config/waybar/config.jsonc,
# vanity text) and the mouse-nav one (~/.config/waybar-mouse/config.jsonc,
# workspaces/taskbar/apps/keyboard/power). Bound to SUPER+SHIFT+M.
#
# This is a REPLACEMENT, not a second bar: only one waybar process ever
# runs at a time, same as before this feature existed. Independent of the
# look-swap system -- not tied to any look, on/off on its own bind.
#
# hyprctl needs HYPRLAND_INSTANCE_SIGNATURE and it is not inherited from
# the compositor (same gotcha toggle-look.sh and power-menu.sh hit) -- the
# hyprland/workspaces and wlr/taskbar IPC modules need this too, or clicks
# render but don't dispatch.
# -----------------------------------------------------------------------------
set -euo pipefail

export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

MOUSE_CONF="$HOME/.config/waybar-mouse/config.jsonc"
MOUSE_STYLE="$HOME/.config/waybar-mouse/style.css"

if pgrep -f "waybar -c $MOUSE_CONF" >/dev/null 2>&1; then
  # switch back to normal: kill the mouse variant, restart the plain bar
  pkill -f "waybar -c $MOUSE_CONF" || true
  # hiding the bar hides the keyboard too, so it can't get stranded on
  # screen with no way back to its own toggle button
  pkill -x wvkbd-deskintl 2>/dev/null || true
  sleep 0.2
  waybar >/dev/null 2>&1 &
  disown
else
  # switch to mouse nav: kill the plain bar, start the mouse variant
  pkill -x waybar 2>/dev/null || true
  sleep 0.2
  waybar -c "$MOUSE_CONF" -s "$MOUSE_STYLE" >/dev/null 2>&1 &
  disown
fi
