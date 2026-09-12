# Two-line prompt: top line is a status bar (user@host + cwd), bottom line
# is the actual input prompt, colored from the active look's kitty palette
# (LOOK_FG/LOOK_DIM/LOOK_ACCENT, set once at shell start in config.fish --
# a shell open across a look toggle keeps its old colors until the next
# new window, same caveat kitty/fuzzel/btop already have).
function fish_prompt
    set -l last_status $status

    set_color $LOOK_DIM 2>/dev/null; or set_color brblack
    echo -n "─ "
    set_color $LOOK_ACCENT 2>/dev/null; or set_color cyan
    echo -n (whoami)
    set_color $LOOK_DIM 2>/dev/null; or set_color brblack
    # not `hostname` -- that binary doesn't exist on this machine (no
    # inetutils/hostname package installed), caught by testing this prompt
    # before shipping it rather than assuming the command exists.
    echo -n "@"(cat /etc/hostname 2>/dev/null)"  "
    set_color $LOOK_FG 2>/dev/null; or set_color normal
    echo -n (prompt_pwd)
    set_color normal
    echo

    if test $last_status -ne 0
        set_color red
        echo -n "✗ "
    else
        set_color $LOOK_ACCENT 2>/dev/null; or set_color green
        echo -n "❯ "
    end
    set_color normal
end
