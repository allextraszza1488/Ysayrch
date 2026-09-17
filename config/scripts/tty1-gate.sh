#!/bin/bash
# -----------------------------------------------------------------------------
# Runs as root, in place of a bare `agetty --autologin admin` in
# /etc/systemd/system/getty@tty1.service.d/autologin.conf. Normal boot/crash
# respawns still autologin as before; the ONE difference is a marker file
# the mouse-nav bar's Logout button drops right before it exits Hyprland
# (confirm-power-action.sh, "logout" case) -- if present, this consumes it
# and shows a real login: prompt exactly once instead of autologin.
#
# Marker lives under the user's home, not /run/user/1000: that directory is
# torn down by logind when the session ends (Linger=no on this account),
# which would race with -- and likely lose to -- this script trying to read
# it right after that same session's teardown.
#
# NOT wired in yet: this file alone changes nothing. See the systemd
# override edit that has to accompany it (root-owned file, not something
# this script or any agent should touch -- do that part yourself).
# -----------------------------------------------------------------------------
set -euo pipefail

MARKER="/home/admin/.config/hypr/tty1-logout-requested"

if [ -e "$MARKER" ]; then
  rm -f "$MARKER"
  exec /usr/bin/agetty --noclear tty1 "$TERM"
else
  exec /usr/bin/agetty --autologin admin --noclear tty1 "$TERM"
fi
