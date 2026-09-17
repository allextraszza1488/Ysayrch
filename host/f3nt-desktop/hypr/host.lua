-- host/f3nt-desktop overlay. Loaded via pcall(dofile) from hyprland.lua.
-- Deliberately NOT pinned to a specific output (DP-1 vs DP-4 vs whatever a
-- fresh install enumerates) -- was hardcoded to DP-1 before, but the cable
-- kept moving between the iGPU and the NVIDIA card, and the two never
-- agreed on numbering. Also relevant: a GPU-passthrough setup for the
-- 5070 Ti is a live possibility (2 cables now), which would change which
-- adapter owns which output again. Match on mode/scale instead, whichever
-- output it lands on; re-pin to a real `output` value once the reinstalled
-- box's actual enumeration (and passthrough plan, if it happens) is known.
hl.monitor({
  -- 120 not the panel's 199.99: measured 26.2W vs 29.8W idle, 60Hz saved nothing more
  mode = "2560x1440@120.00",
  position = "auto",
  scale = "1",
})
