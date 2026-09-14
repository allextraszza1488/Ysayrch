# arch-skeleton

You partition. This script is **after** a booted Arch.

```bash
# as your user, on the new install
git clone <this repo> ~/arch-skeleton   # or copy from PERSONAL stick
cd ~/arch-skeleton
./install.sh --host f3nt-desktop        # omit --host on a random box
```

Does **not** touch disks. Never p5/p6/p7.

Then reboot (or login tty1). `start-hyprland` runs on tty1. Look is **0xyc**; SUPER+SHIFT+T cycles 0xyc / mdmamph / diyetlyser. Windows are opaque.

`--without local-ai` if you don't want the 14B pulls (~18G).
