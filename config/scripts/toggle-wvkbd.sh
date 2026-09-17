#!/bin/bash
# -----------------------------------------------------------------------------
# Shows/hides the on-screen keyboard. Bound to the "kbd" button on the
# mouse nav bar -- does NOT auto-show with that bar, it eats real screen
# space so it only appears when actually asked for.
#
# Package: wvkbd-deskintl (AUR) -- prebuilt desktop-style full layout.
# Binary name assumed as `wvkbd-deskintl`; not yet installed/verified live,
# confirm with `which wvkbd-deskintl` after `paru -S wvkbd-deskintl`.
# -----------------------------------------------------------------------------
set -euo pipefail

if pgrep -x wvkbd-deskintl >/dev/null 2>&1; then
  pkill -x wvkbd-deskintl
else
  wvkbd-deskintl &
  disown
fi
