#!/bin/bash
# -----------------------------------------------------------------------------
# Mousewheel over the taskbar module on the mouse nav bar: cycles focus
# through open windows instead of scrolling nothing. next = wheel up,
# prev = wheel down (matches waybar's on-scroll-up/on-scroll-down split).
# -----------------------------------------------------------------------------
set -euo pipefail

# hyprctl needs this and it is not inherited from the compositor
export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

dir=${1:?usage: taskbar-cycle.sh next|prev}

mapfile -t addrs < <(hyprctl clients -j | jq -r '.[].address')
n=${#addrs[@]}
[ "$n" -gt 0 ] || exit 0

active=$(hyprctl activewindow -j | jq -r '.address // empty')

idx=-1
for i in "${!addrs[@]}"; do
  if [ "${addrs[$i]}" = "$active" ]; then idx=$i; break; fi
done
[ "$idx" -ge 0 ] || idx=0

if [ "$dir" = "next" ]; then
  target=$(( (idx + 1) % n ))
else
  target=$(( (idx - 1 + n) % n ))
fi

# NOT `hyprctl dispatch focuswindow address:...` -- this build's dispatch
# is Lua-expression-only (confirmed live). hl.dsp.focus's error message
# itself lists accepted keys: direction, monitor, window, urgent_or_last,
# last -- and "window" wants the classic "address:0x..." selector string.
hyprctl dispatch "hl.dsp.focus({window=\"address:${addrs[$target]}\"})"
