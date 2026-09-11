#!/bin/bash
# -----------------------------------------------------------------------------
# Clipboard history picker: fuzzel over cliphist's stored entries.
# Bound to SUPER+CTRL+V. Depends on the wl-paste --watch cliphist store
# watchers started in hyprland.lua's AUTOSTART block (text + image).
# -----------------------------------------------------------------------------
set -euo pipefail

# || true: fuzzel exits non-zero on Escape/cancel, which under set -e would
# abort right here -- silently equivalent in outcome to the exit-0 below,
# but for the wrong reason, and it skipped the check entirely (caught by
# ultrareview). Neutralize the exit status, let the explicit check below run.
chosen=$(cliphist list | fuzzel --dmenu --prompt "clip> " || true)

[ -z "$chosen" ] && exit 0

echo "$chosen" | cliphist decode | wl-copy
