# CONTEXT for whoever (human or agent) works on this repo next

Written by Claude, 2026-09-09, after a long session that ended in this repo's
creation. Read this before writing any code. If you're an agent: this is not
a description of what to build — it's the reasoning trail so you don't
re-derive (or re-break) things that are already settled.

## What this repo is FOR

The user has a real machine (Arch on part of a shared NVMe, dual-boot with
another Linux install) and wants a **maximally portable, partition-agnostic
skeleton** that turns an already-installed, already-booted bare Arch system
into their actual desktop: Hyprland + the packages + their dotfiles. Nothing
in this repo should ever partition, format, mount, or otherwise touch block
devices. That is now entirely the user's own job, done by hand via
`archinstall` (or manually) from a Ventoy stick carrying live ISOs. This repo
starts **after** that point: base Arch is installed and booted, this repo's
job is everything from "pacstrap-level base exists" onward.

**Why this split happened**: see "The disk-wipe blocker" below. Short
version — the previous repo (`~/arch-hypr`) tried to also own partitioning,
and its whole-disk approach is fundamentally incompatible with this
particular machine's layout (Arch shares one physical disk with another
Linux install that must never be touched). Rather than teach that installer
to be partition-scoped (real work, and still risky to get subtly wrong on a
shared disk), the user decided to keep partitioning entirely manual and
under their own control, and have tooling (this repo) own only the part
after that — which is also the part that's actually finished, proven,
reusable, and safe regardless of partition layout.

## Where the code in this repo came from

- `install.sh`, `lib/common.sh`, `lib/detect.sh`, `lib/pac.sh`, and
  `host/f3nt-desktop/` are copied as-is from `~/arch-hypr` (commit
  `ae5a7cb`, 2026-09-06). This is **proven working code** — `install.sh` is
  what actually succeeded end-to-end on a Samsung laptop (Intel-only,
  4-core), run directly against a base system the user had installed
  manually via `archinstall`. That was the *only* path that worked cleanly
  that night; two other custom bootstrap scripts (now deliberately excluded,
  see below) both hit real problems during that live session.
- `config/` is copied fresh from the user's **real, live** `~/.config` on
  2026-09-09 (not from arch-hypr's slightly older checked-out copy) —
  hypr, kitty, fish, waybar, fuzzel, nvim, nvim-fm, scripts, reference,
  assets. This is the current, authoritative source of "what the user
  actually runs."
- **Deliberately NOT carried over from arch-hypr**: `bootstrap/` in its
  entirety (`live-install.sh`, `one-shot-install.sh`, `lite-profile.sh`) and
  `lib/liveiso.sh`. All of that is whole-disk partitioning/wiping logic —
  out of scope for this repo, permanently, by design.
- **Correction (still 2026-09-09)**: `lib/rootdev.sh` was *also* initially
  left out under that same reasoning, which was wrong — `install.sh` itself
  `source`s it (line 14) and won't run without it. Unlike the bootstrap
  scripts, `rootdev.sh` doesn't partition or wipe anything; it's a read-only
  safety guard — `root_device()` asks `findmnt` what's actually mounted at
  `/` right now, and `refuse_foreign_disk()` hard-fails any caller that
  points it at a device that isn't that live root. That's exactly the kind
  of partition-agnostic, host-agnostic safety check this repo wants more of,
  not less — it was added back. If you're auditing this repo for
  correctness, that's the kind of mistake to watch for: something looking
  disk-related at a glance isn't automatically wipe logic.

## The disk-wipe blocker (why arch-hypr's installers are dead to us now)

Read this if you're ever tempted to resurrect disk automation here — the
reasoning still applies.

Real machine layout (Kingston NVMe, 1.8T, GPT):

| Part | Size | FS | Role |
|---|---|---|---|
| nvme0n1p1 | 777G | btrfs `@` | **this Arch** `/` |
| nvme0n1p2 | 1.3G | vfat | **this Arch** ESP, GRUB |
| nvme0n1p5 | 100G | ext4 | **other linux** `/` — never touch |
| nvme0n1p6 | 1G | vfat | **other linux** ESP (systemd-boot) — never touch |
| nvme0n1p7 | 983G | LUKS | **other linux** data — never touch |

Both `bootstrap/live-install.sh` and `bootstrap/one-shot-install.sh` in
arch-hypr call `sgdisk --zap-all "$TARGET"` and require `$TARGET` to be a
**whole disk** (they explicitly `fail` if given a partition). There is no
code path in either script that replaces only p1+p2 while leaving other
partitions on the same physical disk alone. Pointed at the real
`/dev/nvme0n1`, either script would destroy the other Linux install's
partition table instantly. This was verified by reading the actual
partitioning code, not inferred — it's a certainty, not a guess.

That's the whole reason this repo exists as a separate, disk-operation-free
thing. If partitioning tooling is ever wanted again, it needs to be built
from scratch as explicitly partition-scoped (operate on a partition the user
already created, never touch anything else on the disk), and audited harder
than this session had time for.

## What was tested tonight, and what's still an open question

A full VM test (QEMU, UEFI/OVMF, virtio disk, KVM-accelerated) of
`one-shot-install.sh` was run end-to-end on a throwaway virtual disk — this
is unrelated to any real hardware, just to see the install flow work. Two
things came out looking broken:

1. **No systemd-boot entry got created** — `loader/entries/` was empty and
   `loader.conf` had no `default` line, even though the script clearly
   writes one (a sed-templated chroot script, see `one-shot-install.sh`
   around line 561 in arch-hypr if it still matters to you).
2. **Copied dotfiles came out as 0-byte files** — right names, right
   permissions, right *original* mtimes, but empty content, across every
   file checked (hyprland.lua, waybar config, kitty conf, look-state.lua,
   start-hyprland).

**Important caveat, don't skip this**: after the install finished, it was
tested by `kill -9`-ing the QEMU process instead of a clean shutdown. That's
equivalent to a hard power cut. btrfs won't corrupt from that, but
recently-written *data* for small files can be lost while their *metadata*
(name, permissions, old mtime) survives — which is exactly the symptom
observed. **This was never re-tested with a clean shutdown**, so it's
genuinely unknown whether these are real bugs in arch-hypr's installer or
artifacts of the abrupt kill. Since `bootstrap/` isn't coming into this repo
anyway, this doesn't block anything here — but don't cite it as "install.sh
is known to corrupt dotfiles" without re-testing, because that specific
claim was never confirmed. (`install.sh`, the file that *did* get carried
into this repo, is a different code path from `one-shot-install.sh` and
wasn't the thing under test — it's the thing that worked on the Samsung
laptop.)

## Design goal for this repo, going forward

Make `install.sh` (and the packages/config/dotfiles logic it drives) work
correctly regardless of:
- partition layout, filesystem choice, LUKS or not (none of this repo's
  business — by the time it runs, the system is already booted)
- which machine it's running on (host-specific bits like monitor pins or
  `reflector --country` belong under `host/<name>/`, applied only when
  asked for — `host/f3nt-desktop/` is the existing example, real values for
  this machine, kept as a working reference)
- GPU vendor (already handled reasonably well by `lib/detect.sh`'s PCI
  class `[0300]`/`[0302]` probe — carried over, should still be fine)

Concretely, this probably means: audit `install.sh` for anywhere it still
assumes something about the current partition layout, disk device name, or
bootloader, and strip/parameterize those. It currently expects to be run
post-base-install rather than doing the base install itself, which is the
right shape — the Samsung laptop run proved that shape works.

## Standing rules that apply to this repo too

- **Naming**: no hash-suffixed directory/repo/file names anywhere. Short,
  plausible names; a plain numeric suffix like `123` only if there's an
  actual collision.
- **Never touch nvme0n1p5/p6/p7** (see table above) — this applies to any
  code in this repo, forever, even though the repo shouldn't be touching
  disks at all in the first place.
- **`~/arch-hypr` still exists, untouched** — it's not deleted, just no
  longer the active plan. `~/Downloads/arch-vm/` (the QEMU demo VM from
  tonight — disk image, screenshots, helper scripts) also still exists,
  preserved on request, not to be deleted; it's slated to be copied to a
  personal-backup USB stick by Grok at some point, separately from this
  work.
- Two USB sticks are in play for the *actual* real-machine reinstall
  (unrelated to this repo directly, but useful background): a PERSONAL
  stick (compact history/dotfiles backup) and an INSTALL stick (live Arch
  ISO + arch-hypr, likely superseded by whatever this repo becomes). The
  user manages both of those themselves alongside Grok.

## Update, 2026-09-09 later that night: cross-check with Grok's independent read

Grok read this file cold and wrote its own audit to `CONTEXT-grok.md`
(separate file, same directory) without seeing Claude's fix below first.
Worth noting where two independent reads landed:

- **Agreed independently**: `lib/rootdev.sh` was missing and `install.sh`
  won't run without it — same bug, same root cause (safety guard, not
  disk-wipe logic), found by both reads separately. Already fixed in this
  repo (see git log). Strong signal this one's real.
- **Grok caught, Claude missed**: `--profile NAME` (install.sh ~line 156)
  looks for `bootstrap/${PROFILE}-profile.sh`, which doesn't exist in this
  repo (bootstrap/ was deliberately excluded). Passing `--profile lite` (or
  any profile) will hit `fail "unknown profile: ..."`. **Not currently
  fixed** — it's opt-in (only breaks if someone passes `--profile`), so it
  was left as a known issue rather than vendoring a profile file or ripping
  out the flag. Fix before anyone tries `--profile`.
- **Grok confirmed**: `60-suspend`, `80-security`, `90-steam` modules are
  still print-only stubs (not real actions yet) — matches what was already
  suspected from arch-hypr's git history but unconfirmed. Now confirmed.
- **Grok's test-sequencing suggestion, adopted**: rather than the user's
  first real test being a LUKS reformat of the existing p1 (the real Arch
  root, currently in use), do a **dry-run on a brand-new partition first** —
  the disk has two empty GPT slots (3 and 4, cosmetic leftover from an old
  Windows layout). User creates a partition there themselves (custom
  partitioning in `archinstall`, never "use entire disk"), boots that, runs
  `./install.sh --host f3nt-desktop` against it, and only *after* that's
  proven to actually work end-to-end does reformatting the real p1 with
  LUKS become the next step. Meaningfully lower-risk than going straight at
  the live root partition, and cheap to do first.

## If you're Grok

Also read this file. Then ask the user directly what they want from this
repo, and write your own understanding of it to `CONTEXT-grok.md` right next
to this file, before changing anything.

## Update, 2026-09-10: live machine has moved on — read this before trusting anything above as current

A full read-only audit (Claude, three parallel sub-agents: hardware/boot,
repo correctness, security) found that **the hardware table in "The
disk-wipe blocker" section and both "known issues" from the 2026-09-09 Grok
cross-check are stale.** Treat everything above this point as the reasoning
trail that got this repo *created* — accurate history, not current fact.
What's actually true on the live machine right now:

- **Hardware is not the Samsung laptop.** This is a desktop: AMD Ryzen 7
  9700X (8c/16t), discrete NVIDIA RTX 5070 Ti + integrated AMD Radeon
  (Granite Ridge APU) — dual GPU, not Intel-only.
- **The disk migration this repo was built to eventually do has already
  happened and succeeded.** Root is now LUKS-on-`nvme0n1p3` + btrfs
  (`@`/`@home` subvols), boot/ESP on `nvme0n1p4`. The old `nvme0n1p1` (the
  "this Arch" row in the table above) is now just a read-only reference
  mount at `/mnt/oldarch`. `p5/p6/p7` remain untouched, as required — that
  invariant held throughout.
- **Swap is 4G zram** (zstd), not a file or partition.
- **Username is `admin`, not `f3nt`.** `host/f3nt-desktop/` is a naming
  leftover from before a rename/reinstall — the profile still works, the
  name is just historical now.
- **`--profile NAME` is no longer broken** — `install.sh` now warns and
  clears `PROFILE` when `bootstrap/${PROFILE}-profile.sh` is missing,
  instead of hard-failing. The "not currently fixed" note from the
  2026-09-09 Grok cross-check is out of date.
- **Module stub status is mixed, not uniform.** `60-suspend` got a real
  implementation (patches GRUB/systemd-boot for `mem_sleep_default=s2idle`).
  Only `80-security` and `90-steam` are still print-only stubs.

Also fixed same session, worth knowing about if you're reading this to
understand recent history: NVIDIA DKMS had no module built for the running
`linux-lts` kernel (`linux-lts-headers` was missing — now installed, module
built); `hyprland.lua` never actually loaded `host.lua` despite host.lua's
own header claiming it did (`pcall(dofile, ...)` call was missing — now
added, in both the repo and live copies); repo's `hyprpaper.conf` still had
the old `/home/f3nt/...` path baked in (now `/home/admin/...`); `paru/`
(673MB of unreferenced build artifacts) was deleted from the repo; the
`arch-hypr` naming leftover in `install.sh`'s banner/manifest-path and
`lib/common.sh`'s `MANIFEST_FILE` default was renamed to `arch-skeleton`
(the live manifest state dir was moved, not recreated, so `--undo` history
from before this rename still resolves).

**Still open, deliberately not touched this session**: the Hyprland-vs-X11
decision itself (user considering AwesomeWM instead, decided elsewhere,
outcome not in yet) and the bash/Lua GPU-vendor-detection duplication
(`lib/detect.sh` vs `hyprland.lua`'s own `has_nvidia()`) — the latter is
Hyprland-coupled enough that fixing it before that decision lands would be
wasted work if Hyprland gets dropped.
