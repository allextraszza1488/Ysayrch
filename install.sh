#!/usr/bin/env bash
# arch-skeleton installer skeleton.
# Run as yourself, not root — modules sudo internally.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/detect.sh
source "$ROOT/lib/detect.sh"
# shellcheck source=lib/pac.sh
source "$ROOT/lib/pac.sh"
# shellcheck source=lib/rootdev.sh
source "$ROOT/lib/rootdev.sh"

ALL_MODULES=(
  00-preflight
  10-hypr-stack
  20-gpu
  30-dots
  35-nvim
  40-look
  50-snapshots
  60-suspend
  70-tuning
  80-security
  90-steam
  91-local-ai
)

HOST=""
PROFILE=""
UNDO=0
WITH=()
WITHOUT=()

usage() {
  cat <<EOF
usage: $0 [options]

  --probe           print hardware key=value lines (also: curl detect.sh | bash)
  --host NAME       host profile name (laptop/desktop/hostname)
  --with X,Y        force-include modules (name or NN-name)
  --without X,Y     exclude modules
  --profile NAME    source bootstrap/NAME-profile.sh (e.g. lite)
  --undo            restore every file recorded in \$MANIFEST_FILE
  -h, --help        this text

Do not run as root. Modules sudo internally when they touch /etc or pacman.
EOF
}

canonical_module() {
  local raw=${1,,}
  raw=${raw// /}
  case "$raw" in
    preflight|00-preflight|00) printf '00-preflight\n' ;;
    hypr-stack|hypr|10-hypr-stack|10) printf '10-hypr-stack\n' ;;
    gpu|20-gpu|20) printf '20-gpu\n' ;;
    dots|30-dots|30) printf '30-dots\n' ;;
    nvim|35-nvim|35) printf '35-nvim\n' ;;
    look|40-look|40) printf '40-look\n' ;;
    snapshots|50-snapshots|50) printf '50-snapshots\n' ;;
    suspend|60-suspend|60) printf '60-suspend\n' ;;
    tuning|70-tuning|70) printf '70-tuning\n' ;;
    security|80-security|80) printf '80-security\n' ;;
    steam|90-steam|90) printf '90-steam\n' ;;
    local-ai|91-local-ai|91|ollama) printf '91-local-ai\n' ;;
    *) fail "unknown module: $1 (try: ${ALL_MODULES[*]})" ;;
  esac
}

split_csv() {
  local csv=$1
  local IFS=,
  # shellcheck disable=SC2086
  set -- $csv
  local p
  for p in "$@"; do
    p=${p#"${p%%[![:space:]]*}"}
    p=${p%"${p##*[![:space:]]}"}
    [[ -n "$p" ]] && printf '%s\n' "$p"
  done
}

in_list() {
  local needle=$1; shift
  local x
  for x in "$@"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      bash "$ROOT/lib/detect.sh" --probe
      exit 0
      ;;
    --host)
      [[ $# -ge 2 ]] || fail "--host needs a name"
      HOST=$2
      shift 2
      ;;
    --host=*)
      HOST=${1#*=}
      shift
      ;;
    --with)
      [[ $# -ge 2 ]] || fail "--with needs a module list"
      while IFS= read -r m; do
        WITH+=("$(canonical_module "$m")")
      done < <(split_csv "$2")
      shift 2
      ;;
    --with=*)
      while IFS= read -r m; do
        WITH+=("$(canonical_module "$m")")
      done < <(split_csv "${1#*=}")
      shift
      ;;
    --without)
      [[ $# -ge 2 ]] || fail "--without needs a module list"
      while IFS= read -r m; do
        WITHOUT+=("$(canonical_module "$m")")
      done < <(split_csv "$2")
      shift 2
      ;;
    --without=*)
      while IFS= read -r m; do
        WITHOUT+=("$(canonical_module "$m")")
      done < <(split_csv "${1#*=}")
      shift
      ;;
    --profile)
      [[ $# -ge 2 ]] || fail "--profile needs a name"
      PROFILE=$2
      shift 2
      ;;
    --profile=*)
      PROFILE=${1#*=}
      shift
      ;;
    --undo)
      UNDO=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ -n "$PROFILE" ]]; then
  pf="$ROOT/bootstrap/${PROFILE}-profile.sh"
  if [[ ! -f "$pf" ]]; then
    warn "no bootstrap/ in this repo — ignoring --profile $PROFILE"
    PROFILE=""
  fi
fi
if [[ -n "$PROFILE" ]]; then
  [[ -f "$pf" ]] || fail "unknown profile: $PROFILE (expected $pf)"
  # shellcheck source=/dev/null
  source "$pf"
  _canon=()
  for m in "${WITHOUT[@]+"${WITHOUT[@]}"}"; do
    _canon+=("$(canonical_module "$m")")
  done
  WITHOUT=("${_canon[@]+"${_canon[@]}"}")
  unset _canon
fi

if [[ "$(id -u)" -eq 0 ]]; then
  fail "do not run as root — rerun as yourself; modules sudo internally"
fi

do_undo() {
  [[ -f "$MANIFEST_FILE" ]] || fail "no manifest at $MANIFEST_FILE"
  say "restoring from $MANIFEST_FILE"
  local lines=() orig bak newest
  mapfile -t lines < "$MANIFEST_FILE"
  local i
  for ((i=${#lines[@]}-1; i>=0; i--)); do
    [[ -n "${lines[i]}" ]] || continue
    orig=${lines[i]%%$'\t'*}
    bak=${lines[i]#*$'\t'}
    if [[ "$bak" == "$orig" || ! -e "$bak" ]]; then
      newest=$(ls -1t -- "$orig".bak.* 2>/dev/null | head -n1 || true)
      bak=$newest
    fi
    if [[ -z "$bak" || ! -e "$bak" ]]; then
      warn "no backup found for $orig — skipping"
      continue
    fi
    say "restore $bak -> $orig"
    if [[ -w "$(dirname -- "$orig")" ]]; then
      cp -a -- "$bak" "$orig"
    else
      sudo cp -a -- "$bak" "$orig"
    fi
  done
  say "undo complete"
}

# --- helpers for real module bodies ----------------------------------------

same_file() {
  [[ -e "$1" && -e "$2" && "$1" -ef "$2" ]]
}

# Copy $1 -> $2. Skip if they already resolve to the same inode (self-link
# when this repo IS ~/.config) or if contents already match.
install_file() {
  local src=$1 dest=$2
  mkdir -p "$(dirname -- "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if same_file "$src" "$dest"; then
      say "skip (same file): $dest"
      return 0
    fi
    if [[ -f "$src" || -L "$src" ]] && [[ -f "$dest" || -L "$dest" ]] \
       && cmp -s -- "$src" "$dest"; then
      say "skip (identical): $dest"
      return 0
    fi
  fi
  cp -a -- "$src" "$dest"
  say "copied $src -> $dest"
}

install_link() {
  local src=$1 dest=$2
  mkdir -p "$(dirname -- "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if same_file "$src" "$dest"; then
      say "skip (same file): $dest"
      return 0
    fi
  fi
  ln -sfn -- "$src" "$dest"
  say "linked $dest -> $src"
}

# Runtime-state files that toggle-look.sh owns after first install (see
# config/hypr/.gitignore, config/kitty/.gitignore). A plain install_tree
# copy compares repo-vs-live content and overwrites on any difference --
# which clobbers whatever look you've since toggled to, since the repo's
# committed copy stops matching the moment you switch looks. Treat these
# the same way run_40_look already treats look-state.lua/current-look:
# leave alone once they exist.
#
# Bare filenames, not "hypr/foo" -- install_tree is always called with an
# app's own subdirectory as $src (e.g. "config/hypr", not "config"), so
# $rel is already relative to that subdir. A "hypr/"-prefixed entry could
# never match and the guard was silently dead code (caught by ultrareview).
RUNTIME_STATE_FILES=(
  look-state.lua
  current-look
  hyprpaper.conf
  active-look.conf
  fuzzel.ini
)

is_runtime_state() {
  local rel=$1 s
  for s in "${RUNTIME_STATE_FILES[@]}"; do
    [[ "$rel" == "$s" ]] && return 0
  done
  return 1
}

# Recurse files and symlinks under $1 into $2, using install_file.
install_tree() {
  local src=$1 dest=$2
  local f rel
  [[ -d "$src" ]] || return 0
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    if is_runtime_state "$rel" && [[ -e "$dest/$rel" || -L "$dest/$rel" ]]; then
      say "skip (runtime state, already exists): $dest/$rel"
      continue
    fi
    install_file "$f" "$dest/$rel"
  done < <(find "$src" \( -type f -o -type l \) -print0)
}

enable_now() {
  local unit=$1
  if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    say "$unit already enabled"
    return 0
  fi
  say "enable --now $unit"
  sudo systemctl enable --now "$unit"
}

run_00_preflight() {
  say "00-preflight (detect only)"
  echo "  user=$(real_user) home=$(real_home)"
  echo "  root_device=$(root_device)"
  echo "  root_fs=$(detect_root_fs)  bootloader=$(detect_bootloader)  chassis=$(detect_chassis)"
  echo "  nproc=$(detect_nproc)  nvidia=$(_bool has_nvidia) amd=$(_bool has_amd) intel=$(_bool has_intel)"
  if [[ -n "$HOST" ]]; then
    echo "  --host $HOST (apply host overlay from host/$HOST if present)"
  fi
}

run_10_hypr_stack() {
  say "10-hypr-stack"
  local pkgs=(
    hyprland xdg-desktop-portal-hyprland waybar hyprpaper lua jq libnotify
    fuzzel mako grim slurp wl-clipboard cliphist pipewire pipewire-pulse wireplumber
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd librewolf kitty fish curl
    neovim tree-sitter-cli btop fastfetch thunar gvfs
  )
  say "pacman_needed: ${pkgs[*]}"
  pacman_needed "${pkgs[@]}"

  # mouse-nav's on-screen keyboard (toggle-wvkbd.sh) -- AUR-only, no repo
  # equivalent ships the same deskintl full-layout build.
  aur_needed wvkbd-deskintl

  # video/render/input: direct DRM buffer access (hyprpaper, screenshots,
  # anything doing its own GBM allocation instead of going through the
  # compositor). Without these, Hyprland itself can still start -- it goes
  # through the DRM master fd systemd-logind hands the seat -- but a second
  # process trying to allocate its own GBM buffer gets a silent
  # DRM_IOCTL_MODE_CREATE_DUMB: Permission denied and just doesn't render,
  # no crash. Caught live: hyprpaper started, logged EGL/GBM errors, never
  # showed a wallpaper, no error visible anywhere else.
  local u grp missing=()
  u=$(real_user)
  for grp in video render input; do
    getent group "$grp" >/dev/null 2>&1 || continue
    id -nG "$u" | grep -qw "$grp" || missing+=("$grp")
  done
  if ((${#missing[@]} > 0)); then
    say "adding $u to: ${missing[*]}"
    sudo usermod -aG "$(IFS=,; echo "${missing[*]}")" "$u"
    warn "group membership needs a fresh login to take effect"
  else
    say "$u already in video/render/input"
  fi
}

run_20_gpu() {
  say "20-gpu"
  local pkgs=()
  if has_nvidia; then
    pkgs+=(nvidia-open-dkms nvidia-utils nvidia-settings)
    echo "  nvidia: nvidia-open-dkms (Blackwell needs the open modules, not proprietary)"
  fi
  if has_amd; then
    pkgs+=(mesa vulkan-radeon libva-mesa-driver)
    echo "  amd: mesa + vulkan-radeon"
  fi
  if has_intel; then
    pkgs+=(mesa vulkan-intel intel-media-driver)
    echo "  intel: mesa + vulkan-intel"
  fi
  if ((${#pkgs[@]} == 0)); then
    say "no PCI [0300]/[0302] GPU detected — skipping driver packages"
    return 0
  fi
  say "pacman_needed: ${pkgs[*]}"
  pacman_needed "${pkgs[@]}"
}

run_30_dots() {
  say "30-dots"
  local dest_cfg dest_bin src_cfg name
  dest_cfg="$(real_home)/.config"
  dest_bin="$(real_home)/.local/bin"
  src_cfg="$ROOT/config"

  [[ -d "$src_cfg" ]] || fail "config/ missing at $src_cfg"

  mkdir -p "$dest_cfg" "$dest_bin"

  for name in "$src_cfg"/*; do
    [[ -e "$name" ]] || continue
    if [[ -d "$name" ]]; then
      install_tree "$name" "$dest_cfg/$(basename -- "$name")"
    else
      install_file "$name" "$dest_cfg/$(basename -- "$name")"
    fi
  done

  if [[ -n "$HOST" ]]; then
    local overlay="$ROOT/host/$HOST"
    if [[ ! -d "$overlay" ]]; then
      fail "unknown host profile: $HOST (expected $overlay)"
    fi
    if [[ -d "$overlay/hypr" ]]; then
      say "applying host overlay $HOST -> $dest_cfg/hypr"
      install_tree "$overlay/hypr" "$dest_cfg/hypr"
    fi
  fi

  if [[ -x "$dest_cfg/hypr/start-hyprland" ]]; then
    install_link "$dest_cfg/hypr/start-hyprland" "$dest_bin/start-hyprland"
  elif [[ -x "$src_cfg/hypr/start-hyprland" ]]; then
    install_link "$src_cfg/hypr/start-hyprland" "$dest_bin/start-hyprland"
  else
    warn "start-hyprland not found — not linking into $dest_bin"
  fi

  # Scripts live in ~/.config/scripts (hyprland.lua calls them there) and
  # also on PATH: screenshot-watch.service ExecStart=%h/.local/bin/...
  local s
  if [[ -d "$dest_cfg/scripts" ]]; then
    for s in "$dest_cfg/scripts"/*.sh; do
      [[ -e "$s" ]] || continue
      chmod +x "$s"
      install_link "$s" "$dest_bin/$(basename -- "$s")"
    done
    if [[ -f "$dest_cfg/scripts/screenshot-watch.service" ]]; then
      install_link "$dest_cfg/scripts/screenshot-watch.service" \
        "$dest_cfg/systemd/user/screenshot-watch.service"
      # Linking the unit into place is not enough -- caught live: grim/slurp
      # saved screenshots fine, but with nothing ever `enable --now`'d, the
      # clipboard-copy watcher just never ran and nobody noticed until a
      # screenshot's path wasn't on the clipboard.
      systemctl --user daemon-reload
      if systemctl --user is-active --quiet screenshot-watch.service; then
        say "screenshot-watch.service already running"
      else
        say "enable --now --user screenshot-watch.service"
        systemctl --user enable --now screenshot-watch.service
      fi
    fi
  fi

  local fontsrc="$ROOT/extras/fonts"
  if [[ -d "$fontsrc" ]]; then
    mkdir -p "$(real_home)/.local/share/fonts"
    install_tree "$fontsrc" "$(real_home)/.local/share/fonts"
    fc-cache -f "$(real_home)/.local/share/fonts" >/dev/null 2>&1 || true
  fi

  # fish is the shell config.fish's tty1-exec guard runs in -- without this
  # the guard never fires (login shell stays whatever `useradd` set) and
  # tty1 just sits at a fish-less prompt instead of launching Hyprland.
  local u
  u=$(real_user)
  if [[ "$(getent passwd "$u" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    say "chsh -s /usr/bin/fish $u"
    sudo chsh -s /usr/bin/fish "$u"
  else
    say "login shell already fish"
  fi

  # tty1 autologin, so a LUKS passphrase at boot is the only prompt --
  # not a display manager, matches the existing tty1-launches-Hyprland setup.
  local getty_dir=/etc/systemd/system/getty@tty1.service.d
  local getty_conf="$getty_dir/autologin.conf"
  if [[ -f "$getty_conf" ]] && grep -q -- "--autologin $u " "$getty_conf" 2>/dev/null; then
    say "tty1 autologin already configured for $u"
  else
    say "configuring tty1 autologin for $u"
    sudo mkdir -p "$getty_dir"
    printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin %s --noclear %%I $TERM\n' "$u" \
      | sudo tee "$getty_conf" >/dev/null
    sudo systemctl daemon-reload
  fi
}

run_35_nvim() {
  say "35-nvim"
  local home lazypath out
  home=$(real_home)
  lazypath="$home/.local/share/nvim/lazy/lazy.nvim"

  # nvim's own init.lua bootstrap only checks fs_stat(lazypath) -- if a
  # prior run got interrupted mid-clone, the dir exists but is incomplete,
  # and every future launch skips re-cloning forever. Detect and repair
  # that instead of leaving it broken (caught live: exactly this state).
  if [[ -d "$lazypath" && ! -f "$lazypath/lua/lazy/init.lua" ]]; then
    warn "incomplete lazy.nvim clone at $lazypath -- removing"
    rm -rf "$lazypath"
  fi

  say "bootstrapping lazy.nvim + syncing plugins"
  if ! out=$(nvim --headless "+Lazy! sync" +qa 2>&1); then
    warn "$out"
    fail "nvim/lazy.nvim bootstrap failed"
  fi
  [[ -f "$lazypath/lua/lazy/init.lua" ]] || fail "lazy.nvim still missing after bootstrap"
}

run_40_look() {
  say "40-look"
  local dest_state dest_marker src
  dest_state="$(real_home)/.config/hypr/look-state.lua"
  dest_marker="$(real_home)/.config/hypr/current-look"
  src="$ROOT/config/hypr/looks/0xyc.lua"
  [[ -f "$src" ]] || fail "missing look recipe $src"

  if [[ -e "$dest_state" ]]; then
    say "look-state.lua already exists — not overwriting"
  else
    mkdir -p "$(dirname -- "$dest_state")"
    cp -a -- "$src" "$dest_state"
    say "seeded $dest_state from looks/0xyc.lua"
  fi
  if [[ -e "$dest_marker" ]]; then
    say "current-look marker already exists — not overwriting"
  else
    printf '0xyc\n' > "$dest_marker"
    say "wrote $dest_marker"
  fi

  local wpsrc="$ROOT/config/wallpapers"
  local wpdest="$(real_home)/Pictures/wallpapers"
  if [[ -d "$wpsrc" ]]; then
    mkdir -p "$wpdest"
    local f
    for f in "$wpsrc"/*; do
      [[ -e "$f" ]] || continue
      local destf="$wpdest/$(basename -- "$f")"
      if [[ -e "$destf" ]]; then
        say "wallpaper $(basename -- "$f") already exists — not overwriting"
      else
        cp -a -- "$f" "$destf"
        say "seeded $destf"
      fi
    done
  fi
}

run_50_snapshots() {
  say "50-snapshots"
  local fs boot pkgs
  fs=$(detect_root_fs)
  boot=$(detect_bootloader)
  echo "  root_fs=$fs  bootloader=$boot  root_device=$(root_device)"
  # refuse_foreign_disk exists for a module that takes an explicit disk-path
  # argument to operate on; nothing below touches any device other than the
  # live root itself, so there's no separate target to check here. Calling
  # it with root_device()'s own output (as this line used to) was a no-op --
  # canon == root by construction, the fail branch could never trigger.
  if [[ "$fs" != btrfs ]]; then
    say "not btrfs — skipping snapper (forced on by --with)"
    return 0
  fi
  pkgs=(snapper snap-pac)
  if [[ "$boot" == *grub* ]]; then
    pkgs+=(grub-btrfs inotify-tools)
    if [[ "${SKIP_LINUX_LTS:-0}" != 1 ]]; then
      pkgs+=(linux-lts linux-lts-headers)
    fi
  fi
  say "pacman_needed: ${pkgs[*]}"
  pacman_needed "${pkgs[@]}"

  if [[ -f /etc/snapper/configs/root ]]; then
    say "snapper config 'root' already exists"
  else
    say "snapper -c root create-config /"
    sudo snapper -c root create-config /
    backup_file /etc/snapper/configs/root
    sudo sed -i -e "s/^ALLOW_USERS=.*/ALLOW_USERS=\"$(real_user)\"/" \
      /etc/snapper/configs/root
  fi

  enable_now snapper-timeline.timer
  enable_now snapper-cleanup.timer

  if [[ "$boot" == *grub* ]]; then
    local unit
    unit=$(systemctl list-unit-files --no-legend 'grub-btrfsd*' | awk '{print $1}' | head -1)
    if [[ -n "$unit" ]]; then
      enable_now "$unit"
    else
      warn "no grub-btrfsd unit found — snapshot boot entries only after grub-mkconfig"
    fi
  else
    say "bootloader is $boot — not enabling grub-btrfsd"
  fi
}

run_60_suspend() {
  say "60-suspend"
  local boot param=mem_sleep_default=s2idle
  boot=$(detect_bootloader)
  echo "  nvidia=$(_bool has_nvidia)  bootloader=$boot"
  has_nvidia || { say "no NVIDIA — skip s2idle pin"; return 0; }

  if [[ "$boot" == *grub* ]]; then
    local g=/etc/default/grub
    [[ -f "$g" ]] || { warn "$g missing"; return 0; }
    if grep -q "$param" "$g"; then
      say "already has $param"
      return 0
    fi
    grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$g" || { warn "no GRUB_CMDLINE_LINUX_DEFAULT"; return 0; }
    backup_file "$g"
    sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ $param\"/" "$g"
    say "grub-mkconfig"
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  elif [[ "$boot" == *systemd-boot* ]]; then
    local e
    shopt -s nullglob
    for e in /boot/loader/entries/*.conf; do
      grep -q "$param" "$e" && continue
      backup_file "$e"
      sudo sed -i "/^options / s/\$/ $param/" "$e"
      say "patched $e"
    done
    shopt -u nullglob
  else
    warn "unknown bootloader — add $param yourself"
  fi
}

run_70_tuning() {
  say "70-tuning"
  local n conf rconf overlay
  n=$(detect_nproc)
  conf=/etc/makepkg.conf
  if grep -Eq "^MAKEFLAGS=\"-j${n}\"" "$conf"; then
    say "MAKEFLAGS already -j${n}"
  else
    say "set MAKEFLAGS=-j${n} in $conf"
    backup_file "$conf"
    if grep -q '^MAKEFLAGS=' "$conf"; then
      sudo sed -i "s/^MAKEFLAGS=.*/MAKEFLAGS=\"-j${n}\"/" "$conf"
    elif grep -q '^#MAKEFLAGS=' "$conf"; then
      sudo sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j${n}\"/" "$conf"
    else
      printf 'MAKEFLAGS="-j%s"\n' "$n" | sudo tee -a "$conf" >/dev/null
    fi
  fi

  say "pacman_needed: pacman-contrib reflector"
  pacman_needed pacman-contrib reflector

  enable_now paccache.timer

  rconf=/etc/xdg/reflector/reflector.conf
  overlay=""
  if [[ -n "$HOST" && -f "$ROOT/host/$HOST/reflector.conf" ]]; then
    overlay="$ROOT/host/$HOST/reflector.conf"
  fi
  if [[ -n "$overlay" ]]; then
    if [[ -f "$rconf" ]] && cmp -s -- "$overlay" "$rconf"; then
      say "reflector.conf already matches host overlay"
    else
      say "install reflector.conf from host/$HOST"
      [[ -f "$rconf" ]] && backup_file "$rconf"
      sudo mkdir -p "$(dirname -- "$rconf")"
      sudo cp -- "$overlay" "$rconf"
    fi
  else
    say "no host overlay for reflector --country; leaving $rconf as-is"
  fi

  enable_now reflector.timer
}

run_80_security() {
  say "80-security"
  pacman_needed ufw clamav arch-audit

  if sudo ufw status | grep -q "Status: active"; then
    say "ufw already active"
  else
    say "ufw: default deny incoming, allow outgoing, enable"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw --force enable
  fi

  # `ufw enable` sets ENABLED=yes in /etc/ufw/ufw.conf and loads rules for
  # this boot, but on Arch that does NOT imply the systemd unit is enabled
  # -- caught live: rules were "on" by ufw's own config yet ufw.service was
  # disabled+inactive, so a reboot would have come up with no firewall at
  # all despite ufw.conf claiming otherwise.
  enable_now ufw.service

  enable_now clamav-freshclam.service

  local dest_unit dest_timer
  dest_unit="$(real_home)/.config/systemd/user/home-scan.service"
  dest_timer="$(real_home)/.config/systemd/user/home-scan.timer"
  install_file "$ROOT/extras/security/home-scan.service" "$dest_unit"
  install_file "$ROOT/extras/security/home-scan.timer" "$dest_timer"

  systemctl --user daemon-reload
  if systemctl --user is-enabled --quiet home-scan.timer 2>/dev/null; then
    say "home-scan.timer already enabled"
  else
    say "enable --now --user home-scan.timer"
    systemctl --user enable --now home-scan.timer
  fi
}

run_90_steam() {
  say "90-steam"
  enable_multilib_if_needed
  pacman_needed steam
}

run_91_local_ai() {
  say "91-local-ai (on-demand ollama; not enabled at boot)"
  local dest_share dest_unit unit_src uuid
  dest_share="$(real_home)/.local/share/arch-skeleton/ollama"
  dest_unit="$(real_home)/.config/systemd/user/ollama.service"
  mkdir -p "$dest_share" "$(dirname -- "$dest_unit")"

  if has_nvidia; then
    pacman_needed ollama ollama-cuda
  else
    pacman_needed ollama
  fi
  sudo systemctl disable --now ollama.service 2>/dev/null || true

  install_file "$ROOT/extras/ollama/ollama.user.service" "$dest_unit"
  if has_nvidia && command -v nvidia-smi >/dev/null; then
    uuid=$(nvidia-smi -L 2>/dev/null | head -1 | sed -n 's/.*UUID: \([^)]*\).*/\1/p')
    if [[ -n "$uuid" ]]; then
      mkdir -p "$(real_home)/.config/systemd/user/ollama.service.d"
      printf '[Service]\nEnvironment=CUDA_VISIBLE_DEVICES=%s\n' "$uuid" \
        > "$(real_home)/.config/systemd/user/ollama.service.d/gpu.conf"
      say "pinned ollama to $uuid"
    fi
  fi

  install_file "$ROOT/extras/ollama/Modelfile" "$dest_share/Modelfile"

  systemctl --user daemon-reload
  systemctl --user start ollama.service
  local ok=0 i
  for i in $(seq 1 60); do
    if curl -fsS --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 0.5
  done
  if [[ "$ok" -ne 1 ]]; then
    warn "ollama API did not come up — skip pull; later: systemctl --user start ollama"
    return 0
  fi

  say "pull qwen3:14b (work f3nt)"
  ollama pull qwen3:14b
  ollama create f3nt -f "$dest_share/Modelfile"
  systemctl --user stop ollama.service
  say "after reboot: tty1 -> start-hyprland (0xyc)"
}

run_module() {
  case "$1" in
    00-preflight)  run_00_preflight ;;
    10-hypr-stack) run_10_hypr_stack ;;
    20-gpu)        run_20_gpu ;;
    30-dots)       run_30_dots ;;
    35-nvim)       run_35_nvim ;;
    40-look)       run_40_look ;;
    50-snapshots)  run_50_snapshots ;;
    60-suspend)    run_60_suspend ;;
    70-tuning)     run_70_tuning ;;
    80-security)   run_80_security ;;
    90-steam)      run_90_steam ;;
    91-local-ai)   run_91_local_ai ;;
    *) fail "internal: no runner for $1" ;;
  esac
}

plan_modules() {
  local m planned=()
  local fs nvidia
  fs=$(detect_root_fs)
  nvidia=$(_bool has_nvidia)

  for m in "${ALL_MODULES[@]}"; do
    case "$m" in
      50-snapshots)
        [[ "$fs" == btrfs ]] || continue
        ;;
      60-suspend)
        [[ "$nvidia" == 1 ]] || continue
        ;;
      91-local-ai)
        # Opt-in only: `ollama pull` is a real multi-GB download and you
        # want to pick the moment, not have it happen on every rebuild.
        continue
        ;;
    esac
    planned+=("$m")
  done

  for m in "${WITH[@]}"; do
    in_list "$m" "${planned[@]+"${planned[@]}"}" || planned+=("$m")
  done

  local filtered=()
  for m in "${planned[@]}"; do
    in_list "$m" "${WITHOUT[@]+"${WITHOUT[@]}"}" && continue
    filtered+=("$m")
  done

  # Keep ALL_MODULES order even if --with added a skipped module.
  planned=()
  for m in "${ALL_MODULES[@]}"; do
    in_list "$m" "${filtered[@]+"${filtered[@]}"}" && planned+=("$m")
  done
  printf '%s\n' "${planned[@]+"${planned[@]}"}"
}

if [[ "$UNDO" -eq 1 ]]; then
  do_undo
  exit 0
fi

mapfile -t PLAN < <(plan_modules)

echo "arch-skeleton plan${HOST:+ (host=$HOST)}${PROFILE:+ (profile=$PROFILE)}:"
if ((${#PLAN[@]} == 0)); then
  echo "  (no modules — everything excluded?)"
  exit 0
fi
for m in "${PLAN[@]}"; do
  echo "  $m"
done
echo

for m in "${PLAN[@]}"; do
  run_module "$m"
done

say "done"
