# Image defaults, copied so the shell behaves the same off Bluefin.
# Each block runs only if the image hasn't already done it.

# Homebrew (from Bluefin /etc/profile.d/brew.sh, 2026-10-30).
# brew goes at the end of PATH, so system binaries win over brew's.
if [ -z "${HOMEBREW_PREFIX:-}" ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv | grep -Ev '\bPATH=')"
    PATH="$PATH:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"
fi

# Bash completion itself. Fedora loads it from /etc/profile.d/bash_completion.sh;
# Ubuntu loads it from its default ~/.bashrc, which this repo replaces (2026-10-31).
if [ -z "${BASH_COMPLETION_VERSINFO:-}" ] && ! shopt -oq posix \
    && [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# Completions for brew-installed tools
# (from Bluefin /etc/profile.d/brew-bash-completion.sh, 2026-10-30).
# Checks whether brew's own completion is loaded in this shell rather than
# $BREW_BASH_COMPLETION, which Bluefin exports (same nested-shell issue as below).
# Needs brew: with HOMEBREW_PREFIX empty the path would be /etc/bash_completion.d.
if [ -n "${HOMEBREW_PREFIX:-}" ] && ! complete -p brew >/dev/null 2>&1 \
    && [ -d "$HOMEBREW_PREFIX/etc/bash_completion.d" ]; then
    for rc in "$HOMEBREW_PREFIX"/etc/bash_completion.d/*; do
        [ -r "$rc" ] && . "$rc"
    done
    unset rc
fi

# Starship prompt with its built-in defaults, no starship.toml
# (from Bluefin /etc/profile.d/90-bluefin-starship.sh, 2026-10-30).
# Checks for its function rather than $STARSHIP_SHELL: that variable is
# exported, so a nested shell would skip the init and lose the prompt.
if ! declare -F starship_precmd >/dev/null && command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
