#!/bin/bash
# -----------------------------------------------------------------------------
# Reports whether workspace N is the active one, as waybar custom-module
# JSON ({"text":"N","class":"active"|""}). Polled every second by each of
# the mouse nav bar's ws1..ws9 buttons so the current one stays highlighted.
# -----------------------------------------------------------------------------
set -euo pipefail

export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)"

n=${1:?usage: ws-state.sh N}
active=$(hyprctl activeworkspace -j | jq -r '.id')

if [ "$active" = "$n" ]; then
  printf '{"text":"%s","class":"active"}\n' "$n"
else
  printf '{"text":"%s","class":""}\n' "$n"
fi
