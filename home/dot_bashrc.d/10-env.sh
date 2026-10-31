# Environment variables.

# Only where nvim is installed (not in a live session); brew's PATH is set in 05.
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
fi
export CALIBRE_USE_DARK_PALETTE=1
