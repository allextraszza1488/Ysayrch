#!/bin/bash
# -----------------------------------------------------------------------------
# Alt-tab replacement: a fuzzel list of open windows, keyboard only.
# Bound to SUPER+Tab in hyprland.lua.
# -----------------------------------------------------------------------------
set -euo pipefail

# hyprctl needs this and a systemd/user service never inherits it
export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

# -----------------------------------------------------------------------------
# Filter ONCE, then use that same filtered array for both the menu and the
# lookup. The previous version numbered a filtered list but looked the address
# up in the UNFILTERED one, so any unmapped window shifted every index and you
# focused the wrong window -- silently, with no error.
#
# Current-workspace windows first, then everything else -- otherwise the
# most likely window you want (something on the workspace you're already
# looking at) could land anywhere in the list.
# -----------------------------------------------------------------------------
active_ws=$(hyprctl activeworkspace -j | jq '.id')
mapped=$(hyprctl clients -j | jq --argjson active "$active_ws" \
  '[.[] | select(.mapped==true)] | sort_by(.workspace.id != $active)')

# fuzzel --dmenu has no real per-line icon support (only its desktop-entry
# launcher mode does) -- a Nerd Font glyph prefix is the practical stand-in,
# same idea as waybar's blackletter glyph substitutions elsewhere in this setup.
icon_for() {
  case "${1,,}" in
    kitty)               printf '' ;; # nf-dev-terminal
    firefox|librewolf)   printf '' ;; # nf-fa-firefox
    btop)                printf '' ;; # nf-md-chart_areaspline
    thunar)               printf '' ;; # nf-fa-folder_open
    imv)                  printf '' ;; # nf-fa-picture_o
    qbittorrent)         printf '' ;; # nf-fa-download
    *)                    printf '' ;; # nf-fa-window_maximize (default)
  esac
}
export -f icon_for

# numbered menu lines, built from the filtered array
list=$(echo "$mapped" | jq -r 'to_entries[] | "\(.key+1)\t\(.value.class)\t\(.value.title)"' | \
  while IFS=$'\t' read -r n class title; do
    printf '%s: %s %s — %s\n' "$n" "$(icon_for "$class")" "$class" "$title"
  done)

# nothing open, nothing to switch to
[ -z "$list" ] && exit 0

# fuzzel returns the whole chosen line. || true: fuzzel exits non-zero on
# Escape, which under set -e would abort before the empty-check below runs
# (caught by ultrareview, same pattern fixed across the other fuzzel scripts).
chosen=$(echo "$list" | fuzzel --dmenu --prompt "window> " || true)

# escaped out of the menu
[ -z "$chosen" ] && exit 0

# pull the leading number back off the chosen line
idx=$(echo "$chosen" | grep -oE '^[0-9]+')

# no leading number means the line was not one of ours
[ -z "$idx" ] && exit 0

# same array the menu came from, so the index still means what it meant
addr=$(echo "$mapped" | jq -r ".[$((idx-1))].address")

# window vanished between listing and choosing
{ [ -z "$addr" ] || [ "$addr" = "null" ]; } && exit 0

# dispatchers with arguments must go through eval; hyprctl dispatch parses as Lua
hyprctl eval "hl.dispatch(hl.dsp.focus({window = \"address:$addr\"}))"
