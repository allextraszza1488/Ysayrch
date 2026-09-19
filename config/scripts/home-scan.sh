#!/bin/bash
# -----------------------------------------------------------------------------
# Runs the weekly ClamAV home scan and notifies via mako at start and finish,
# so it's visible instead of a silent background job. Driven by the user
# service scripts/home-scan.service (see extras/security/ for the timer).
# -----------------------------------------------------------------------------
set -uo pipefail

LOG="$HOME/.local/state/home-scan.log"
mkdir -p "$(dirname "$LOG")"

notify-send -a "ClamAV" "Weekly scan starting" "Scanning $HOME ..."

clamscan -r --infected --exclude-dir="^$HOME/.cache" --log="$LOG" "$HOME"
code=$?

infected=$(grep -m1 "^Infected files:" "$LOG" | awk '{print $3}')

if [ "$code" -eq 1 ]; then
    notify-send -u critical -a "ClamAV" "Weekly scan finished" "${infected:-some} infected file(s) found — see $LOG"
elif [ "$code" -eq 0 ]; then
    notify-send -a "ClamAV" "Weekly scan finished" "No infections found."
else
    notify-send -u critical -a "ClamAV" "Weekly scan failed" "clamscan exited $code — see $LOG"
fi

# Let the real exit code through -- an infection or scan error should show
# up as a failed systemd unit (systemctl --user --failed), not just a toast
# you might have missed. Clean run (0) is the only "success" case.
exit "$code"
