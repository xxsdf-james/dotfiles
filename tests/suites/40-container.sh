# shellcheck shell=bash
# A live session's restore in a throwaway Ubuntu container, as a normal user: the README's chezmoi
# install from get.chezmoi.io, then init and apply from a copy of this repo's files (uncommitted
# edits count; a copy, so :Z relabels the copy and not the repo). A plain podman container, not
# distrobox: distrobox shares the real $HOME. Needs podman and the network (VPN up, because of the
# kill switch); skipped without them.
# From the claude-test folder's b1-step7-test-container.sh (2026-10-31), which found 7a352d4.
. "$TESTS/lib.sh"
needs podman
IMAGE=docker.io/library/ubuntu:26.04
podman info >/dev/null 2>&1 || { skip "whole suite: podman doesn't run here (sandbox?)"; exit 0; }
# K5: with the kill switch on and no VPN, the pull fails; that used to end the suite with no result.
podman image exists "$IMAGE" || podman pull -q "$IMAGE" >/dev/null 2>&1 \
  || { skip "whole suite: can't pull $IMAGE (no network: kill switch on and no VPN up?)"; exit 0; }

# Runs inside the container: as root to add a live session's tools, then as the user.
cat >"$WORK/inner.sh" <<'INNER'
set -uo pipefail
if [[ $(id -u) = 0 ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq curl git ca-certificates bash-completion >/dev/null || exit 3
  id ubuntu >/dev/null 2>&1 || useradd -m ubuntu
  exec runuser -u ubuntu -- bash /t/inner.sh
fi
cd "$HOME"
pass() { echo "  PASS  $*"; }; fail() { echo "  FAIL  $*"; }
check() { local n=$1; shift; if "$@" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi; }
curl -fsLS -o /tmp/chezmoi-install.sh https://get.chezmoi.io && sh /tmp/chezmoi-install.sh -b "$HOME/.local/bin" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"
check "chezmoi installed from get.chezmoi.io" chezmoi --version
mkdir -p ~/.local/share/chezmoi && cp -r /src/.chezmoiroot /src/home ~/.local/share/chezmoi/
chezmoi init --no-tty --promptChoice "Machine role=personal" \
  --promptChoice "Install level (dotfiles-only for live sessions)=dotfiles-only" \
  --promptString "Git email (personal: GitHub no-reply address)=test@example.invalid" >/dev/null 2>&1
check "chezmoi apply" chezmoi apply --no-tty
check "chezmoi diff empty" test -z "$(chezmoi diff --no-pager)"
if chezmoi doctor 2>&1 | grep -E '^\s*(error|failed)'; then fail "chezmoi doctor has errors"; else pass "chezmoi doctor: no errors"; fi
check "dotfiles-only: no Brewfiles" test ! -e ~/.homebrew
check "git email from the prompt" test "$(git config --global user.email)" = test@example.invalid
check "git hooks set (git present)" test "$(git -C ~/.local/share/chezmoi config core.hooksPath)" = .githooks
out=$(bash -i -c 'echo "EDITOR=${EDITOR-}"; echo "COMPLETION=${BASH_COMPLETION_VERSINFO:-none}"' 2>&1 \
  | grep -vE 'cannot set terminal process group|no job control in this shell')
if grep -qiE 'error|not found|no such file|syntax' <<<"$out"; then
  fail "interactive bash starts clean"; printf '%s\n' "$out" | sed 's/^/        /'
else pass "interactive bash starts clean"; fi
check "no nvim, so no EDITOR (bcbd2e6)" grep -qx 'EDITOR=' <<<"$out"
check "bash-completion loaded (7a352d4)" grep -qx 'COMPLETION=[0-9]*' <<<"$out"
INNER
mkdir -p "$WORK/src" && tar -C "$REPO" -cf - .chezmoiroot home | tar -C "$WORK/src" -xf -
podman run --rm -v "$WORK/src:/src:ro,Z" -v "$WORK/inner.sh:/t/inner.sh:ro,Z" "$IMAGE" bash /t/inner.sh </dev/null
rc=$?
((rc == 3)) && fail "apt-get in the container failed (network? VPN up?)"
exit 0
