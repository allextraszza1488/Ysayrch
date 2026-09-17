#!/bin/bash
# -----------------------------------------------------------------------------
# "+" button on the mouse nav bar: jumps to the first free workspace id,
# computed from live state (highest existing id + 1) rather than a fixed
# guess, so it can't collide with a workspace that already exists.
# -----------------------------------------------------------------------------
set -euo pipefail

# hyprctl needs this and it is not inherited from the compositor
export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

highest=$(hyprctl workspaces -j | jq '[.[].id] | max // 0')
"$HOME/.config/scripts/ws-jump.sh" "$((highest + 1))"
