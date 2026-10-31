# shellcheck shell=bash
# The dotfiles applied with chezmoi into a throwaway HOME, as a live session would (personal,
# dotfiles-only), from a copy of this repo (uncommitted edits included).
# Then the run_onchange_ scripts: one apply without a desktop session and without git (SSH, a
# container, a fresh Ubuntu), then one from a desktop with git. B1a found that the first apply
# recorded the GNOME script as done although it had skipped, so the settings never loaded.
# dconf is a fake here (tests/fakes/dconf): nothing touches this machine's GNOME settings.
. "$TESTS/lib.sh"
needs chezmoi tar

H="$WORK/home" src="$WORK/home/.local/share/chezmoi"
export FAKE="$WORK/fake"; mkdir -p "$H" "$src" "$FAKE"
tar -C "$REPO" -cf - .chezmoiroot home | tar -C "$src" -xf -
hookspath() { git -C "$src" config --local core.hooksPath 2>/dev/null; }

# PATH without git or dconf (a live session); then with git and the fake dconf (a desktop).
bare="$WORK/bin-bare" desk="$WORK/bin-desktop"; mkdir -p "$bare" "$desk"
for t in bash sh chezmoi; do ln -s "$(command -v $t)" "$bare/$t"; ln -s "$(command -v $t)" "$desk/$t"; done
ln -s "$TESTS/fakes/dconf" "$desk/dconf"
command -v git >/dev/null && ln -s "$(command -v git)" "$desk/git"
cz() {  # cz bare|desktop ARGS: chezmoi with nothing from this machine's environment
  local p=$bare dbus=(); [[ $1 == desktop ]] && p=$desk dbus=(DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent)
  shift
  out=$(env -i HOME="$H" PATH="$p" TERM=dumb FAKE="$FAKE" TMPDIR="${TMPDIR:-/tmp}" "${dbus[@]}" chezmoi --no-tty "$@" 2>&1); rc=$?
}

cz bare init --promptChoice "Machine role=personal" \
  --promptChoice "Install level (dotfiles-only for live sessions)=dotfiles-only" \
  --promptString "Git email (personal: GitHub no-reply address)=test@example.invalid"
check "init with the prompts given as flags" test $rc = 0
[[ $rc = 0 ]] || { printf '%s\n' "$out" | sed 's/^/        /'; exit 1; }

cz bare apply
check "apply, no desktop and no git: exit 0" test $rc = 0
[[ $rc = 0 ]] || printf '%s\n' "$out" | sed 's/^/        /'
refute "apply, no desktop: GNOME settings not loaded" test -e "$FAKE/dconf.log"
refute "apply, no git: hooks not set" hookspath
check ".bashrc and .bashrc.d" test -f "$H/.bashrc" -a -d "$H/.bashrc.d"
# shellcheck disable=SC2088  # a label, not a path
check "~/.config is private, 700 (dceb925)" test "$(stat -c %a "$H/.config")" = 700
check "dotfiles-only: no Brewfiles" test ! -e "$H/.homebrew"
check "personal: mullvad-wg installed, executable" test -x "$H/.local/bin/mullvad-wg"
check "git email from the prompt" has "$H/.config/git/config" 'email = test@example.invalid'

cz desktop apply
check "apply again from a desktop with git: exit 0" test $rc = 0
[[ $rc = 0 ]] || printf '%s\n' "$out" | sed 's/^/        /'
check "GNOME settings load now, after the skipped first apply (B1a)" has "$FAKE/dconf.log" '^dconf load /'
if command -v git >/dev/null; then
  check "git hooks set now, after the skipped first apply (B1a)" test "$(hookspath)" = .githooks
else
  skip "git hooks after a skipped apply: no git here"
fi
cz desktop apply
check "third apply: GNOME settings not loaded again" test "$(cat "$FAKE/dconf.log" 2>/dev/null | wc -l)" = 1
cz desktop diff --no-pager
check "chezmoi diff empty" test $rc = 0 -a -z "$out"

# A new interactive shell with these dotfiles, on this machine's bash and /etc.
sh_out=$(env -i HOME="$H" PATH=/usr/bin:/bin TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" \
  bash -i -c 'echo "EDITOR=${EDITOR-}"; echo "NVIM=$(command -v nvim)"' 2>&1 \
  | grep -vE 'cannot set terminal process group|no job control in this shell')
if grep -qiE 'error|not found|no such file|syntax' <<<"$sh_out"; then
  fail "interactive bash starts clean"; printf '%s\n' "$sh_out" | sed 's/^/        /'
else
  pass "interactive bash starts clean"
fi
# nvim may come from brew, which .bashrc.d puts on PATH: ask the shell itself.
if grep -qx 'NVIM=' <<<"$sh_out"; then want=EDITOR=; else want=EDITOR=nvim; fi
check "EDITOR is nvim only where nvim is installed (bcbd2e6): $want" grep -qx "$want" <<<"$sh_out"
