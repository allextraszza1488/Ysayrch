#!/usr/bin/env bash
# pacman wrappers. Source after common.sh.

_pac_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Install packages that are not already present. Never a partial upgrade.
# pacman -Q is unprivileged, so a no-op (everything already installed)
# does not need sudo.
pacman_needed() {
  (( $# > 0 )) || fail "pacman_needed: no packages given"
  local missing=() p
  for p in "$@"; do
    pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if ((${#missing[@]} == 0)); then
    say "already installed: $*"
    return 0
  fi
  say "installing: ${missing[*]}"
  _pac_root pacman -S --needed --noconfirm "${missing[@]}"
}

# Build and install paru from the AUR if it isn't already on PATH. Runs
# unprivileged (makepkg refuses root) -- install.sh itself already runs as
# the real user, so no sudo/su wrapping needed here; makepkg's own final
# `pacman -U` shells out to sudo internally same as _pac_root does elsewhere.
ensure_paru() {
  command -v paru >/dev/null 2>&1 && { say "paru already installed"; return 0; }
  say "paru missing -- bootstrapping from AUR"
  pacman_needed base-devel git cargo
  local tmp
  tmp=$(mktemp -d)
  git clone --quiet https://aur.archlinux.org/paru.git "$tmp"
  ( cd "$tmp" && makepkg -si --noconfirm )
  rm -rf "$tmp"
  command -v paru >/dev/null 2>&1 || fail "paru build finished but binary still not on PATH"
}

# Same contract as pacman_needed but for AUR packages, via paru.
aur_needed() {
  (( $# > 0 )) || fail "aur_needed: no packages given"
  local missing=() p
  for p in "$@"; do
    pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if ((${#missing[@]} == 0)); then
    say "already installed (AUR): $*"
    return 0
  fi
  ensure_paru
  say "installing (AUR): ${missing[*]}"
  paru -S --needed --noconfirm "${missing[@]}"
}

# Uncomment the [multilib] stanza in /etc/pacman.conf if it is still hashed
# out. Idempotent: grep before sed. -Syu runs only on the transition from
# disabled -> enabled, because the sync databases have to agree with the new
# repo list. A bare -Sy is a partial upgrade and is not used.
enable_multilib_if_needed() {
  local conf=/etc/pacman.conf

  if grep -q '^\[multilib\]' "$conf"; then
    say "multilib already enabled"
    return 0
  fi

  grep -q '^#\[multilib\]' "$conf" \
    || fail "no #[multilib] section in $conf — cannot enable it"

  say "enabling multilib in $conf"
  backup_file "$conf"
  # Exact ^#[multilib]$ so [multilib-testing] stays commented.
  _pac_root sed -i \
    '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/{s/^#//}' \
    "$conf"

  grep -q '^\[multilib\]' "$conf" \
    || fail "sed ran but [multilib] is still commented in $conf"

  say "pacman -Syu (multilib just enabled; databases must agree)"
  _pac_root pacman -Syu --noconfirm
}
