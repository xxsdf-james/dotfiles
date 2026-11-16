# shellcheck shell=bash
# drive-sync against a fake Drive: two local folders in $WORK. No Google, no token, no systemctl.
# Origin: claude-test W4, 2026-11-16 (36 checks there before the move).
. "$TESTS/lib.sh"
needs rclone realpath
v=$(rclone version | sed -n '1s/^rclone v\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
read -r maj min <<<"$v"
(( maj > 1 || (maj == 1 && min >= 66) )) || { skip "whole suite: rclone $maj.$min < 1.66"; exit 0; }

T="$WORK"
# An executable copy under the same name: the chezmoi source has no exec bit, and systemd-analyze checks it.
mkdir -p "$T/src"; cp "$REPO/home/private_dot_local/bin/executable_drive-sync" "$T/src/"; chmod +x "$T/src/executable_drive-sync"
S="$T/src/executable_drive-sync"
export XDG_STATE_HOME="$T/state" XDG_CONFIG_HOME="$T/config"
L="$T/local" R="$T/remote"
# A fake notify-send for the whole suite: records calls, never touches the real desktop.
mkdir -p "$T/bin"; printf '#!/bin/sh\necho "$*" >> "%s/notified"\n' "$T" > "$T/bin/notify-send"; chmod +x "$T/bin/notify-send"
export PATH="$T/bin:$PATH" DRIVE_SYNC_NOTIFY=1
run() { bash "$S" --local "$L" --remote "$R" --no-systemctl "$@" >"$T/out" 2>&1; }
tree() { (cd "$1" && find . -type f | sort); }

mkdir -p "$L" "$R"
echo pw > "$L/portable.kdbx"; mkdir -p "$L/obsidian/v/.obsidian"
echo note > "$L/obsidian/v/a.md"; echo '{}' > "$L/obsidian/v/.obsidian/workspace.json"
echo cfg > "$L/obsidian/v/.obsidian/app.json"; echo junk > "$L/x.tmp"
echo from-work > "$R/work.txt"

# 1. dry run of the first sync changes nothing
before_l="$(tree "$L")" before_r="$(tree "$R")"
run --resync; rc=$?
check "1 dry-run resync exits 0" test $rc -eq 0
check "1 dry run: local unchanged" test "$(tree "$L")" = "$before_l"
check "1 dry run: remote unchanged" test "$(tree "$R")" = "$before_r"

# 2. normal sync before any first sync is refused with a hint
run --yes; rc=$?
check "2 sync before resync fails" test $rc -ne 0
check "2 ... and says to run --resync" grep -q -- '--resync' "$T/out"

# 3. first sync makes both sides identical (minus filtered files)
run --resync --yes; rc=$?
check "3 resync exits 0" test $rc -eq 0
check "3 kdbx reached remote" test -f "$R/portable.kdbx"
check "3 note reached remote" test -f "$R/obsidian/v/a.md"
check "3 app.json reached remote" test -f "$R/obsidian/v/.obsidian/app.json"
check "3 remote file reached local" test -f "$L/work.txt"
check "3 workspace.json filtered" test ! -e "$R/obsidian/v/.obsidian/workspace.json"
check "3 *.tmp filtered" test ! -e "$R/x.tmp"

# 4. edits and new files go both ways; deletes go across
sleep 1.1
echo edited > "$L/obsidian/v/a.md"; echo new > "$R/obsidian/v/b.md"; rm "$R/work.txt"
run --yes; rc=$?
check "4 sync exits 0" test $rc -eq 0
check "4 local edit reached remote" grep -qx edited "$R/obsidian/v/a.md"
check "4 remote new file reached local" test -f "$L/obsidian/v/b.md"
check "4 remote delete reached local" test ! -e "$L/work.txt"

# 5. a plain dry run after setup changes nothing
sleep 1.1; echo dry > "$L/dry.md"; before_r="$(tree "$R")"
run; check "5 dry run leaves remote unchanged" test "$(tree "$R")" = "$before_r"
rm "$L/dry.md"

# 6. same file edited on both sides: both copies kept and reported
sleep 1.1
echo laptop > "$L/portable.kdbx"; echo work > "$R/portable.kdbx"
run --yes; rc=$?
check "6 conflict sync exits 0" test $rc -eq 0
check "6 no plain portable.kdbx overwritten silently" test "$(ls "$L" | grep -c '^portable.kdbx.conflict')" -ge 2
check "6 conflict copies listed in output" grep -q 'CONFLICT COPIES' "$T/out"
check "6 both versions kept locally" bash -c "cat '$L'/portable.kdbx.conflict* | grep -qx laptop && cat '$L'/portable.kdbx.conflict* | grep -qx work"

# 7. path guards
bash "$S" --local "$HOME" --remote "$R" >"$T/out" 2>&1; check "7 refuses ~" test $? -ne 0
bash "$S" --local / --remote "$R" >"$T/out" 2>&1; check "7 refuses /" test $? -ne 0
bash "$S" --local "" --remote "$R" >"$T/out" 2>&1; check "7 refuses empty" test $? -ne 0
bash "$S" --local relative --remote "$R" >"$T/out" 2>&1; check "7 refuses relative path" test $? -ne 0
bash "$S" --local "$L" --remote "gdrive:" >"$T/out" 2>&1; check "7 refuses a whole drive" test $? -ne 0

# 8. missing rclone remote: clear message, nothing created, error in the log (the timer has no terminal)
bash "$S" --local "$T/new" --remote "nosuchremote:Sync" --yes >"$T/out" 2>&1; rc=$?
check "8 missing remote fails" test $rc -ne 0
check "8 ... says to run rclone config" grep -q 'rclone config' "$T/out"
check "8 ... creates no local folder" test ! -e "$T/new"
check "8 ... logs the error" grep -q "ERROR: rclone remote 'nosuchremote:' not found" "$XDG_STATE_HOME/drive-sync/sync.log"

# 9. dry run with a missing local folder creates nothing
bash "$S" --local "$T/absent" --remote "$R" >"$T/out" 2>&1
check "9 dry run doesn't create local folder" test ! -e "$T/absent"

# 10. timer: dry run writes nothing; --yes writes units in the scratch config only
run --install-timer
check "10 dry-run timer writes nothing" test ! -e "$XDG_CONFIG_HOME/systemd/user/drive-sync.timer"
run --install-timer --yes
check "10 service unit written" test -f "$XDG_CONFIG_HOME/systemd/user/drive-sync.service"
check "10 timer unit written" grep -q 'OnUnitActiveSec=15min' "$XDG_CONFIG_HOME/systemd/user/drive-sync.timer"
check "10 service runs the script with --yes" grep -q -- "executable_drive-sync --yes --local $L --remote $R" "$XDG_CONFIG_HOME/systemd/user/drive-sync.service"
if command -v systemd-analyze >/dev/null; then
  systemd-analyze --user verify "$XDG_CONFIG_HOME/systemd/user/drive-sync.service" "$XDG_CONFIG_HOME/systemd/user/drive-sync.timer" >"$T/out" 2>&1
  rc=$?
  # Fail only on errors about our units; a machine without a user systemd (sandbox, CI runner) skips.
  if (( rc == 0 )); then pass "10 systemd-analyze verify clean"
  elif grep -qE 'drive-sync\.(service|timer)' "$T/out"; then fail "10 systemd-analyze verify: $(grep -m1 -E 'drive-sync\.(service|timer)' "$T/out")"
  else skip "10 systemd-analyze verify (no user systemd here: $(head -n1 "$T/out"))"; fi
fi

# 11. changed filters are refused without --resync
sed -i 's/^- \*\.tmp$/- *.temp/' "$XDG_STATE_HOME/drive-sync/filters.txt"
run --yes; check "11 changed filters need --resync" grep -q 'filters changed' "$T/out"

# 13. a script whose filter header comment changed (W5 fix: the header was renamed in the move)
sed -i 's/^- \*\.temp$/- *.tmp/' "$XDG_STATE_HOME/drive-sync/filters.txt"   # undo 11: back to the real rules
run --resync --yes                                                               # rclone re-hashes the restored file
sed 's/^# drive-sync filters (written by drive-sync;/# drive-sync filters (a renamed header;/' "$S" > "$T/drive-sync-renamed"
grep -q 'a renamed header' "$T/drive-sync-renamed" || fail "13 setup: header not renamed"
bash "$T/drive-sync-renamed" --local "$L" --remote "$R" --no-systemctl --yes >"$T/out" 2>&1; rc=$?
check "13 renamed header comment: sync exits 0" test $rc -eq 0
refute "13 ... and no 'filters changed' error" grep -q 'filters changed' "$T/out"
refute "13 ... and the file on disk is unchanged" grep -q 'a renamed header' "$XDG_STATE_HOME/drive-sync/filters.txt"

# 14. notifications: a failed sync and conflict copies notify; the hint names the fix
check "14 conflict copies notified (from 6)" grep -q 'conflict copies' "$T/notified"
: > "$T/notified"; rm -rf "$XDG_STATE_HOME/drive-sync/bisync"   # listings gone: bisync must refuse
run --yes; rc=$?
check "14 sync without listings fails" test $rc -ne 0
check "14 failure notified" grep -q 'sync failed' "$T/notified"
check "14 ... with the resync hint" grep -q 'resync' "$T/notified"
: > "$T/notified"
bash "$S" --local "$T/new2" --remote "nosuchremote:Sync" --yes >"$T/out" 2>&1
check "14 missing remote notified" grep -q 'error' "$T/notified"

# 12. a log is kept
check "12 log file written" test -s "$XDG_STATE_HOME/drive-sync/sync.log"

