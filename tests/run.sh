#!/usr/bin/env bash
# Every test in this repo, behind one command (backlog M3 K2, 2026-10-31).
#
# Usage:  tests/run.sh [suite...]     e.g. tests/run.sh system mullvad-wg
# Suites are the files in tests/suites/; name them without the number. No names: all of them.
#
# Runs where the repo is: the working clone, or a VM after `chezmoi init --branch next`
# (~/.local/share/chezmoi/tests/run.sh). Needs no git (a fresh Ubuntu has none), no root, and
# no network, except the container suite. Changes nothing outside one temp folder.
# Each check prints PASS, FAIL or SKIP; a SKIP says what was missing. Exit 1 if any check failed.
# The lines from "==> results" down are what goes into the pull request.
set -uo pipefail

tests="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
repo=$(dirname "$tests")
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

suites=()
for f in "$tests"/suites/*.sh; do
  name=$(basename "$f" .sh); name=${name#[0-9][0-9]-}
  if (($#)) && [[ " $* " != *" $name "* ]]; then continue; fi
  suites+=("$f")
done
((${#suites[@]})) || { echo "no such suite: $*" >&2; ls "$tests/suites" >&2; exit 2; }

summary=() failed=0
for f in "${suites[@]}"; do
  name=$(basename "$f" .sh); name=${name#[0-9][0-9]-}
  echo "==> $name"
  mkdir -p "$work/$name"
  out=$(REPO=$repo TESTS=$tests WORK=$work/$name bash "$f" 2>&1); rc=$?
  printf '%s\n' "$out"
  p=$(grep -c '^  PASS' <<<"$out"); x=$(grep -c '^  FAIL' <<<"$out"); s=$(grep -c '^  SKIP' <<<"$out")
  if ((rc != 0 && x == 0)); then echo "  FAIL  suite stopped early (exit $rc)"; x=1; fi
  ((x)) && failed=1
  summary+=("$(printf '%-12s %3d passed, %d failed, %d skipped' "$name" "$p" "$x" "$s")")
done

echo "==> results ($(uname -n), $(. /etc/os-release && echo "$PRETTY_NAME"), $(date -u '+%F %H:%M UTC'))"
printf '  %s\n' "${summary[@]}"
if [[ -r $repo/.git/HEAD ]]; then
  echo "  repo: $(cat "$repo/.git/HEAD")$(git -C "$repo" rev-parse --short HEAD 2>/dev/null | sed 's/^/ at /')"
fi
exit $failed
