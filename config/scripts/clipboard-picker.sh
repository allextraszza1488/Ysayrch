#!/bin/bash
# -----------------------------------------------------------------------------
# Clipboard history picker: fuzzel over cliphist's stored entries.
# Bound to SUPER+CTRL+V. Depends on the wl-paste --watch cliphist store
# watchers started in hyprland.lua's AUTOSTART block (text + image).
# -----------------------------------------------------------------------------
set -euo pipefail

chosen=$(cliphist list | fuzzel --dmenu --prompt "clip> ")

[ -z "$chosen" ] && exit 0

echo "$chosen" | cliphist decode | wl-copy
