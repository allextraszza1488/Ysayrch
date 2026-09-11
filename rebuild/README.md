# rebuild — the actual "reinstall onto a bare Arch" kit

Two scripts, meant to be run by hand, by you, never by an agent:

- **`pack-personal.sh`** — run on the machine you're backing up. Tars the stuff
  that actually matters (`Pictures`, `somwhere`, dotfiles, `.config`, `.claude`,
  `.grok`, fonts/fish data) into `personal-YYYYMMDD.tar.zst`, skips the huge
  re-downloadable stuff (Steam, Ollama model blobs, VM disks, ISOs) on purpose.
  Also drops `pkglist-explicit.txt`/`pkglist-all.txt` next to it. Copy the
  output onto a USB stick yourself afterward.
- **`restore.sh [host]`** — run on a bare, already-booted Arch (base system
  only — this never partitions/formats, same rule as `install.sh`). Put a
  `personal-*.tar.zst` + `pkglist-explicit.txt` next to it first, then it
  installs the package list, extracts your personal tar into `$HOME`, and
  runs this repo's `install.sh` for you. One command, matches the promise:
  bare Arch in, your desktop out.

## History

This replaces an earlier version of the same idea that a Grok session built
on 2026-09-09 as `~/Proj/rebuild/{pack-personal,copy-to-personal,write-sticks}.sh`
(that home no longer exists live — it's on the read-only old-disk mount at
`/mnt/oldarch/@/home/f3nt/Proj/rebuild/` if you want the originals). That
version already ran once and produced a real backup, now sitting on the
PERSONAL flashdrive's `rebuild/` folder. This version folds the same idea
into arch-skeleton itself (so it's git-tracked, not stranded on a USB stick),
drops the old `f3nt`-specific hardcodes, and adds `restore.sh`, which never
existed before — the old kit only got you to "here's the tar and the
package list," the actual restore was manual steps in a README.

**Never in the tar, re-get separately**: Steam library, Ollama model weights,
VM disk images, ISOs. Same reasoning as before — hundreds of GB of stuff
that's either re-downloadable or shouldn't move via a compact backup.
