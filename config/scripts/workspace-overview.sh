#!/bin/bash
# -----------------------------------------------------------------------------
# Workspace overview: fuzzel list of every existing workspace and the windows
# on it, current workspace marked. Pick a workspace line to switch to it, or
# a window line to focus that window directly (switches workspace too).
# Bound to SUPER+SPACE in hyprland.lua.
#
# Text-based, not a real thumbnail grid -- that needs a Hyprland plugin
# (hyprexpo or similar), a new dependency with its own update-breakage risk.
# This stays in the same toolkit as window-switcher.sh/shortcuts-hub.sh.
#
# Display and lookup are built from the SAME indexed array on purpose --
# window-switcher.sh had a real bug once from building those two off
# different filtered lists, so this avoids that shape entirely.
# -----------------------------------------------------------------------------
set -euo pipefail

export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

icon_for() {
  case "${1,,}" in
    kitty)               printf '' ;; # nf-dev-terminal
    firefox|librewolf)   printf '' ;; # nf-fa-firefox
    btop)                printf '' ;; # nf-md-chart_areaspline
    thunar)              printf '' ;; # nf-fa-folder_open
    imv)                 printf '' ;; # nf-fa-picture_o
    qbittorrent)         printf '' ;; # nf-fa-download
    *)                   printf '' ;; # nf-fa-window_maximize
  esac
}

active_ws=$(hyprctl activeworkspace -j | jq '.id')
clients=$(hyprctl clients -j | jq '[.[] | select(.mapped==true)]')
# "existing" workspaces -- same notion SUPER+[/] already uses (e-1/e+1)
workspaces=$(hyprctl workspaces -j | jq 'sort_by(.id)')

# One flat array: a "ws" entry per workspace, immediately followed by that
# workspace's "win" entries. Array index == the line number shown in fuzzel,
# and is exactly what gets looked up again on selection.
entries=$(jq -n --argjson ws "$workspaces" --argjson cl "$clients" '
  [ $ws[] | . as $w |
    ( {kind:"ws", wsid:$w.id, address:null, class:null, title:null},
      ($cl[] | select(.workspace.id == $w.id) |
        {kind:"win", wsid:$w.id, address:.address, class:.class, title:.title})
    )
  ]')

count=$(echo "$entries" | jq 'length')
[ "$count" -eq 0 ] && exit 0

list=""
for ((i = 0; i < count; i++)); do
  row=$(echo "$entries" | jq -c ".[$i]")
  kind=$(echo "$row" | jq -r '.kind')
  wsid=$(echo "$row" | jq -r '.wsid')
  if [ "$kind" = "ws" ]; then
    marker=""
    [ "$wsid" -eq "$active_ws" ] && marker="  (current)"
    list+="$i: > Workspace $wsid$marker"$'\n'
  else
    class=$(echo "$row" | jq -r '.class')
    title=$(echo "$row" | jq -r '.title')
    list+="$i:     $(icon_for "$class") $class — $title"$'\n'
  fi
done
list="${list%$'\n'}"

# || true: fuzzel exits non-zero on Escape, which under set -e would abort
# before the empty-check below runs (same pattern as the other fuzzel scripts).
chosen=$(echo "$list" | fuzzel --dmenu --prompt "workspace> " || true)
[ -z "$chosen" ] && exit 0

idx=$(echo "$chosen" | grep -oE '^[0-9]+')
[ -z "$idx" ] && exit 0

sel=$(echo "$entries" | jq -c ".[$idx]")
kind=$(echo "$sel" | jq -r '.kind')

if [ "$kind" = "ws" ]; then
  wsid=$(echo "$sel" | jq -r '.wsid')
  hyprctl eval "hl.dispatch(hl.dsp.focus({workspace = $wsid}))"
else
  addr=$(echo "$sel" | jq -r '.address')
  { [ -z "$addr" ] || [ "$addr" = "null" ]; } && exit 0
  hyprctl eval "hl.dispatch(hl.dsp.focus({window = \"address:$addr\"}))"
fi
