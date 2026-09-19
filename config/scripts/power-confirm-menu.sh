#!/bin/bash
# -----------------------------------------------------------------------------
# The single power-icon button on both bars: Lock/Restart/Shutdown.
# Lock is non-destructive (nothing closes, just a password overlay) so it
# skips the confirm step; Restart/Shutdown go through confirm-power-action.sh
# for a Yes/No first. No Logout — autologin would just bounce back in.
# -----------------------------------------------------------------------------
set -euo pipefail

# fuzzel exits non-zero on Escape; || true so set -e doesn't abort before
# the "escaped out, do nothing" branch below can run.
choice=$(printf 'Lock\nRestart\nShutdown' | fuzzel --dmenu --prompt "power> " || true)

case "$choice" in
  Lock)     "$HOME/.config/scripts/lock-session.sh" ;;
  Restart)  "$HOME/.config/scripts/confirm-power-action.sh" reboot ;;
  Shutdown) "$HOME/.config/scripts/confirm-power-action.sh" poweroff ;;
  *) exit 0 ;;
esac
