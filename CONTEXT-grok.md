# CONTEXT-grok.md

Grok, 2026-09-09, after reading Claude's CONTEXT.md and asking the user.

## What the user said they want (this round)

1. **arch-skeleton** = post-base desktop only (`install.sh` + packages + live dots + `host/`). No partitioning. Plus a **separate** folder `~/f3nt_tmp` with **all extras** (Ollama, gyaru, mesh, sudo-once, EdgeTX, Japanese, drone notes, rebuild kit) and either a y/n ask-script or reminders — **and a complete dump of Grok+Claude context** so a new agent can be pointed at that folder.
2. **First real test is a dry-run on a NEW partition**, not wiping p1. Empty GPT slots 3–4 exist. User will create the partition themselves (`archinstall` custom / manual). Then boot that and run `./install.sh --host f3nt-desktop`.
3. **Gentoo is later**, other disk/partition. This skeleton stays **Arch-only**.
4. Tonight: write this file, dump `~/f3nt_tmp`, **audit `install.sh` (no edits until they say go)**.

## What this repo is (Grok's reading)

Same as Claude: after **the user** has a booted Arch (LUKS or not — not this repo's problem), `install.sh` makes it their Hyprland box. Proven on a Samsung Intel laptop. `config/` is tonight's live `~/.config` (includes kitty CJK `symbol_map`). `host/f3nt-desktop/` is this machine's overlay.

`~/arch-hypr` bootstrap (`sgdisk --zap-all` whole-disk) is **dead for this NVMe**. Do not resurrect it here.

## Disk law (unchanged)

Never touch **nvme0n1p5 / p6 / p7** (Pop root, Pop ESP, Pop LUKS). This Arch today is p1+p2. Dry-run = **new partition the user creates** (likely p3/p4), not zap p1.

`archinstall` defaults to **whole disk**. For the dry-run they **must** pick custom partitioning and only use the new partition + a new ESP slice they created — never "use entire nvme0n1".

## Split of labor

- **Claude:** installer internals, VM tests (`~/Downloads/arch-vm/arch-hypr-demo.qcow2` — do not delete).
- **Grok:** personal USB, extras, this dump, walk the user through sticks/Pop/LUKS by hand.

Grok **never sudo**. User kitty only.

## Audit of `install.sh` (read-only, 2026-09-09)

Blockers / leftovers, **not edited tonight**:

1. **Missing `lib/rootdev.sh`.** `install.sh` still `source`s it (lines 13–14) and calls `root_device` / `refuse_foreign_disk` in 00-preflight and 50-snapshots. Claude excluded that file as "disk logic"; the actual file in `~/arch-hypr/lib/rootdev.sh` is **safety** (refuse anything that isn't this install's `/`). Without it, `install.sh` **fails at source**. Copying that file in (not live-install/one-shot) is the first fix when edits are allowed.
2. **`--profile` still wants `bootstrap/${PROFILE}-profile.sh`.** `bootstrap/` is not in this repo. Using `--profile lite` will fail. Drop the flag or vendor a profile here.
3. **60-suspend, 80-security, 90-steam still print "would …"** — not real. Fine for a first dry-run if user `--without` them or accepts no-ops.
4. **No hardcoded `/dev/nvme0n1p1`** in this copy of `install.sh`. GPU detect uses PCI `[0300]`/`[0302]`. Snapshots key off `findmnt /` + `refuse_foreign_disk` (once rootdev exists). Bootloader detect is grub and/or systemd-boot from `/boot` layout — OK for a dry-run that uses either.
5. **50-snapshots enables grub-btrfsd** only if grub is detected. Good. Do not enable os-prober onto p6.
6. Banner still says `arch-hypr plan` — cosmetic.

## Extras live in `~/f3nt_tmp`

Not in `install.sh`. Optional y/n: `~/f3nt_tmp/ask-extras.sh`. Agent dump: `~/f3nt_tmp/AGENT-DUMP.md`.

## What Grok implemented after Claude's rootdev fix (same night)

User asked: after *their* partitioning, one script, reboot, alpenflage + look toggle + gyaru.

- `10-hypr-stack`: fish, noto-fonts-cjk, curl
- `30-dots`: JP font into `~/.local/share/fonts`, `gyaru-llm` on PATH; fish `gyaru`; tty1 `exec start-hyprland`
- NVIDIA detect in `hyprland.lua` + `start-hyprland` uses PCI `[0300]`/`[0302]` + `10de` (not `vga.*nvidia`)
- `60-suspend`: real `mem_sleep_default=s2idle` on grub or systemd-boot
- `91-local-ai`: ollama (+cuda if NVIDIA), **disable** system unit, user unit **not** enabled at boot, pull `qwen3:14b` + abliterated, `create f3nt` + `gyaru`
- `--profile` missing bootstrap: warn and ignore
- `90-steam` still skip

First test remains a **new partition** (slots 3–4), not wipe p1.

## Do not

- Delete `~/arch-hypr`, `~/Downloads/arch-vm`, PERSONAL stick contents.
- `dd` sda live ISO until user says.
- Merge Gentoo into this repo.
- Agent sudo.
