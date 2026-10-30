# History: plain bash history, searched with fzf.
# Ctrl+R  fuzzy history search (Ctrl+/ shows the full command, Ctrl+Y copies it)
# Ctrl+T  insert a file path      Alt+C  cd into a folder

HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth   # skip duplicates and commands starting with a space
shopt -s histappend      # several terminals append instead of overwriting

if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
    export FZF_CTRL_R_OPTS="
      --preview 'echo {}' --preview-window up:3:hidden:wrap
      --bind 'ctrl-/:toggle-preview'
      --bind 'ctrl-y:execute-silent(echo -n {2..} | wl-copy)+abort'
      --color header:italic
      --header 'CTRL-Y copies the command'"
    eval "$(fzf --bash)"
fi
