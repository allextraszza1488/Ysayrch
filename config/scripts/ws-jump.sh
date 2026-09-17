#!/bin/bash
# -----------------------------------------------------------------------------
# Switches to workspace N. Used by the mouse nav bar's numbered buttons and
# the "+" (add-workspace.sh, which computes N itself).
#
# NOT `hyprctl dispatch workspace N` -- this Hyprland build's dispatch is
# Lua-expression-only now (confirmed live: classic "dispatch workspace N"
# syntax errors with a Lua parse failure). Same reason power-menu.sh already
# uses `hyprctl eval "hl.dispatch(hl.dsp.exit())"` instead of `dispatch exit`.
# This is also why waybar's native hyprland/workspaces click silently does
# nothing here -- it still sends the old classic syntax.
# -----------------------------------------------------------------------------
set -euo pipefail

# hyprctl needs this and it is not inherited from the compositor
export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

n=${1:?usage: ws-jump.sh N}
hyprctl dispatch "hl.dsp.focus({workspace=$n})"
