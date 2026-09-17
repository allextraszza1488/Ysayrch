#!/bin/bash
# -----------------------------------------------------------------------------
# Runs one power action with a fuzzel Yes/No confirm first. Called by
# power-confirm-menu.sh after the user picks Logout/Restart/Shutdown from
# its list -- deliberately independent of the old power-menu.sh (removed,
# it had no confirm step).
#
# Usage: confirm-power-action.sh poweroff|reboot|logout
#
# logout: drops a marker tty1-gate.sh looks for on the next getty respawn
# (real login: prompt instead of autologin, consumed after one use), then
# ends the WHOLE session via `loginctl terminate-user` -- not
# `hyprctl ... hl.dsp.exit()` (tried first, then abandoned): that only asks
# Hyprland to quit, and any client that doesn't handle its Wayland display
# vanishing gracefully survives as an orphan (confirmed live: LibreWolf
# hung as a zombie holding its profile lock AND its audio stream, which is
# why music kept playing and a fresh SUPER+B failed with "already
# running"). terminate-user kills the session's whole process tree via its
# systemd scope regardless of how individual apps behave.
# -----------------------------------------------------------------------------
set -euo pipefail

action=${1:?usage: confirm-power-action.sh poweroff|reboot|logout}
case "$action" in
  poweroff) label="Shutdown" ;;
  reboot)   label="Restart" ;;
  logout)   label="Logout" ;;
  *) echo "confirm-power-action: unknown action '$action'" >&2; exit 1 ;;
esac

# fuzzel exits non-zero on Escape; || true so set -e doesn't abort before
# the "declined" branch below can run.
choice=$(printf 'Yes\nNo' | fuzzel --dmenu --prompt "$label> " || true)
[ "$choice" = "Yes" ] || exit 0

if [ "$action" = "logout" ]; then
  touch "$HOME/.config/hypr/tty1-logout-requested"
  loginctl terminate-user "$(whoami)"
else
  systemctl "$action"
fi
