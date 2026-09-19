# Ysayrch

You partition. This script is **after** a booted Arch.

```bash
# as your user, on the new install
git clone <this repo> ~/Ysayrch   # or copy from PERSONAL stick
cd ~/Ysayrch
./install.sh --host f3nt-desktop        # omit --host on a random box
```

Does **not** touch disks — partitioning (LUKS, btrfs, everything) is entirely manual, done before this runs.

Then reboot (or login tty1). `start-hyprland` runs on tty1. Look is **0xyc**; SUPER+SHIFT+T cycles 0xyc / mdmamph / diyetlyser. Wallpapers ship in `config/wallpapers/` (2560×1440). Windows are opaque.

Steam (`90-steam`) and the security module (`80-security`: ufw + clamav + arch-audit) run by default now.

`--with local-ai` to pull the 14B model (~18G) and build the `f3nt` model — opt-in only, does not run by default.
