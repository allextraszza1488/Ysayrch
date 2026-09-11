#!/usr/bin/env bash
# Compact personal backup. No Steam, no Ollama blobs, no VMs, no ISOs.
# Refreshed 2026-09-10 from Grok's original (~/Proj/rebuild/pack-personal.sh on
# the pre-migration f3nt home, now read-only at /mnt/oldarch/@/home/f3nt/Proj).
# Paths made username-agnostic; include list updated for the post-migration
# home layout (no more ~/Proj or ~/arch-hypr — ~/somwhere replaces both).
set -euo pipefail
DEST="${1:-$HOME/somwhere/rebuild}"
STAMP="$(date +%Y%m%d)"
OUT="$DEST/personal-${STAMP}.tar.zst"

mkdir -p "$DEST"
pacman -Qqe > "$DEST/pkglist-explicit.txt"
pacman -Qq  > "$DEST/pkglist-all.txt"

cd "$HOME"

# only tar paths that actually exist on this machine right now
include=()
for p in Pictures somwhere .gitconfig .bash_history \
         .local/share/fonts .local/share/fish .config .grok .claude \
         .ollama/history; do
  [[ -e "$p" ]] && include+=("$p")
done

tar --zstd -cf "$OUT" \
  --exclude='.config/arch-iso' \
  --exclude='somwhere/rebuild/personal-*.tar.zst' \
  --exclude='somwhere/rebuild/*.tar.zst' \
  --exclude='somwhere/iso' \
  --exclude='somwhere/mountd' \
  --exclude='.grok/downloads' \
  --exclude='.grok/bundled' \
  --exclude='.grok/vendor' \
  --exclude='.grok/marketplace-cache' \
  --exclude='.claude/plugins' \
  --exclude='.claude/cache' \
  "${include[@]}"

sha256sum "$OUT" | tee "$OUT.sha256"
cp -v "$DEST/../rebuild/NEVER-TOUCH.txt" "$DEST/../rebuild/README.md" "$DEST/" 2>/dev/null || true
ls -lh "$OUT"
echo "ok: $OUT"
echo "plug PERSONAL stick and: cp $OUT $OUT.sha256 $DEST/pkglist-explicit.txt /run/media/\$USER/<stick>/rebuild/"
