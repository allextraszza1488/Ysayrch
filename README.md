# arch-skeleton

You partition. This script is **after** a booted Arch.

```bash
# as your user, on the new install
git clone <this repo> ~/arch-skeleton   # or copy from PERSONAL stick
cd ~/arch-skeleton
./install.sh --host f3nt-desktop        # omit --host on a random box
```

Does **not** touch disks. Never p5/p6/p7.

Then reboot (or login tty1). `start-hyprland` runs on tty1. Look is **alpenflage**; `toggle-look.sh` / your existing keybind cycles alpenflage / tigerstripe / gyaru (gyaru is just a color look now, not an ollama command).

`--without local-ai` if you don't want the 14B pulls (~18G).
