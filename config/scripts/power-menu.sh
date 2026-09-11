#!/bin/bash
# -----------------------------------------------------------------------------
# Logout / reboot / shutdown picker. Bound to SUPER+SHIFT+P.
# Suspend is deliberately absent: it hard-hangs this machine until
# ~/arch-setup/fix-suspend-hang.sh has been run.
# -----------------------------------------------------------------------------
set -euo pipefail

# hyprctl needs this and it is not inherited from the compositor
export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

# three options, one per line, piped into fuzzel as a menu. || true: fuzzel
# exits non-zero on Escape, which under set -e would abort before the case
# statement's own "escaped out, do nothing" branch ever ran.
choice=$(printf 'Logout\nReboot\nShutdown' | fuzzel --dmenu --prompt "power> " || true)

case "$choice" in
  # exits the compositor; eval because dispatchers with arguments parse as Lua
  Logout)   hyprctl eval "hl.dispatch(hl.dsp.exit())" ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
  # escaped out of the menu: do nothing
  *) exit 0 ;;
esac
