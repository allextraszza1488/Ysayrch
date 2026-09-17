# Autologin on tty1 (set up by install.sh) drops straight into a fish
# login shell -- exec into Hyprland immediately so the only prompt after
# the LUKS passphrase is the desktop itself, not a bare shell.
if status is-login; and test (tty) = /dev/tty1
    exec start-hyprland
end

if status is-interactive
    # Modern CLI replacements, falling back cleanly if not installed yet
    # (sudo bash ~/arch-setup/install-cli-tools.sh installs all of these).
    if type -q eza
        alias ls='eza --group-directories-first --icons'
        alias ll='eza -l --group-directories-first --icons'
        alias la='eza -la --group-directories-first --icons'
        alias dir='eza -la --group-directories-first --icons'  # Windows/DOS muscle memory
        alias tree='eza --tree --icons'
    else
        alias ll='ls -lh --color=auto'
        alias la='ls -lah --color=auto'
        alias dir='ls -lah --color=auto'
    end
    # `type -q X and Y` looked right but isn't: fish only treats `and` as a
    # job-separator when it starts a new statement (after `;` or a newline),
    # not just because it's the next word on the line. Written inline like
    # that, the whole line becomes ONE call to `type` with everything after
    # it -- including `--cmd`/`--fish` -- passed as literal arguments, which
    # `type` then rejects as unknown flags. Confirmed by reproducing it
    # directly in `fish -c` before writing this fix. `if`/`end` has no such
    # ambiguity.
    if type -q bat
        alias cat='bat --paging=never'
    end
    if type -q zoxide
        zoxide init fish --cmd cd | source
    end
    if type -q fzf
        fzf --fish | source
    end

    # Look-aware prompt colors, read once per shell start (not on every
    # prompt draw -- an awk+file read per keypress would add up). A shell
    # open across a SUPER+SHIFT+T toggle keeps its old colors until the next
    # new window, same caveat kitty.conf's own header already documents.
    function _look_color -a key
        awk -v k="$key" '$1==k {print $2; exit}' ~/.config/kitty/active-look.conf 2>/dev/null | string trim -c '#'
    end
    set -g LOOK_FG (_look_color foreground)
    set -g LOOK_DIM (_look_color color8)
    set -g LOOK_ACCENT (_look_color cursor)
    functions -e _look_color

    set -g fish_greeting ""

    # ~/.config/fastfetch/config.jsonc — small builtin logo, no image
    fastfetch
    echo ""
end
fish_add_path $HOME/.local/bin

# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<
