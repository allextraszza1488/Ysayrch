#!/bin/bash
# -----------------------------------------------------------------------------
# Runs one power action with a fuzzel Yes/No confirm first. Called by
# power-confirm-menu.sh after the user picks Restart/Shutdown from its list.
#
# Usage: confirm-power-action.sh poweroff|reboot
# -----------------------------------------------------------------------------
set -euo pipefail

action=${1:?usage: confirm-power-action.sh poweroff|reboot}
case "$action" in
  poweroff) label="Shutdown" ;;
  reboot)   label="Restart" ;;
  *) echo "confirm-power-action: unknown action '$action'" >&2; exit 1 ;;
esac

# fuzzel exits non-zero on Escape; || true so set -e doesn't abort before
# the "declined" branch below can run.
choice=$(printf 'Yes\nNo' | fuzzel --dmenu --prompt "$label> " || true)
[ "$choice" = "Yes" ] || exit 0

systemctl "$action"
