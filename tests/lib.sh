# shellcheck shell=bash
# Helpers for the suites; tests/run.sh sets REPO, TESTS and WORK (a fresh temp folder per suite).
set -uo pipefail

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; }
skip() { echo "  SKIP  $*"; }
# check NAME CMD...   passes when CMD succeeds
check() { local n=$1; shift; if "$@" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi; }
# refute NAME CMD...  passes when CMD fails
refute() { local n=$1; shift; if "$@" >/dev/null 2>&1; then fail "$n"; else pass "$n"; fi; }
# needs TOOL...       skips the rest of the suite when a tool is missing
needs() { local t; for t; do command -v "$t" >/dev/null 2>&1 || { skip "whole suite: no $t here"; exit 0; }; done; }
# has FILE REGEX
has() { grep -qE -- "$2" "$1"; }
