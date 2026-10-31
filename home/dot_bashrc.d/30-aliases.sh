# Aliases. cat, grep and ls stay the standard tools; use bat and eza by name.

if command -v eza >/dev/null 2>&1; then
    alias l='eza -a --icons'
    alias la='eza -la --icons'
    alias lt='eza -la --tree --level=2 --icons'
fi

# Trash from the terminal with GNOME's built-in gio (same Trash as Files).
# gio trash --list | --restore trash:///NAME | --empty
alias trash='gio trash'
