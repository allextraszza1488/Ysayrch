#!/usr/bin/env bash
# One-shot restore onto a bare, already-booted Arch install (base system only,
# nothing else set up). Run this AS YOURSELF from this repo's rebuild/ dir,
# with a personal-*.tar.zst + pkglist-explicit.txt next to it (copy them here
# from the PERSONAL stick's rebuild/ folder first).
#
# What this does NOT do: partition, format, or touch any disk. That's you,
# by hand, before this ever runs — same rule as install.sh itself.
set -euo pipefail

[[ "$(id -u)" -ne 0 ]] || { echo "run as yourself, not root — this sudos internally where needed" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

TAR="$(ls -t "$HERE"/personal-*.tar.zst 2>/dev/null | head -1)"
PKGLIST="$HERE/pkglist-explicit.txt"
HOST="${1:-}"

[[ -n "$TAR" ]]      || { echo "no personal-*.tar.zst next to restore.sh — copy it from the PERSONAL stick's rebuild/ first" >&2; exit 1; }
[[ -f "$PKGLIST" ]]  || { echo "no pkglist-explicit.txt next to restore.sh" >&2; exit 1; }

echo "== 1/3: installing packages from $PKGLIST =="
echo "   (some names may have moved since the list was made — pacman will say so, not silently skip)"
sudo pacman -S --needed - < "$PKGLIST"

echo "== 2/3: extracting $TAR into \$HOME =="
sha256sum -c "$TAR.sha256" 2>/dev/null || echo "   (no/failed checksum file — continuing anyway, verify by hand if this matters)"
tar --zstd -xf "$TAR" -C "$HOME"

echo "== 3/3: running install.sh${HOST:+ --host $HOST} =="
( cd "$REPO" && ./install.sh ${HOST:+--host "$HOST"} )

echo
echo "done. reboot or start Hyprland from tty1 to see it."
echo "note: ollama models / Steam library / VMs were never in the tar — re-pull/re-install those separately if you use them."
