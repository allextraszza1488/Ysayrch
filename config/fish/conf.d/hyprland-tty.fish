# Bare archinstall: no display manager. Login on tty1 -> Hyprland.
# Skip if a DM already started a session.
if status is-login
    and test -z "$DISPLAY"
    and test -z "$WAYLAND_DISPLAY"
    and test (tty) = /dev/tty1
    exec start-hyprland
end
