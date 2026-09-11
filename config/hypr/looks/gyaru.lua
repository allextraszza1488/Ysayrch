-- "gyaru" look: same shape as alpenflage/tigerstripe, except "wallpaper" here
-- points at a folder, not a file -- toggle-look.sh picks one at random from it
-- each time you switch into this look.
return {
  border_active   = { "rgba(c23d9dee)", "rgba(6b3fa0ee)" },
  border_inactive = "rgba(1d1021ee)",
  glow_active     = "rgba(c23dc2a6)",
  glow_inactive   = "rgba(6b3fa033)",
  wallpaper       = os.getenv("HOME") .. "/Pictures/wallpapers/Desk",
}
