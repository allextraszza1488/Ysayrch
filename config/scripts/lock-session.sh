#!/bin/bash
# -----------------------------------------------------------------------------
# Locks the session without touching it: nothing closes, music keeps
# playing, windows stay exactly as they are -- hyprlock just draws a
# password overlay on top until you type it. Distinct from Logout, which
# actually ends the session (see confirm-power-action.sh).
#
# Needs `hyprlock` installed (extra/hyprlock, official repo, no AUR/build
# needed): sudo pacman -S hyprlock
# -----------------------------------------------------------------------------
set -euo pipefail

export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

# already locked -- don't stack a second instance on top
pgrep -x hyprlock >/dev/null 2>&1 && exit 0

exec hyprlock
