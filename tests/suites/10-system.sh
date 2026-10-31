# shellcheck shell=bash
# System layer: system/install.sh under --root (a fake / in a temp folder), and the kill switch files.
# The real systemctl hooks are skipped under --root; the VM test covers them.
. "$TESTS/lib.sh"

inst="$REPO/system/install.sh"
r="$WORK/root"
fedora() { mkdir -p "$r/etc"; printf 'ID=bluefin\nID_LIKE="fedora"\n' >"$r/etc/os-release"; }
ubuntu() { mkdir -p "$r/etc"; printf 'ID=ubuntu\nID_LIKE=debian\n' >"$r/etc/os-release"; }
run() { out=$("$inst" --root "$r" "$@" 2>&1); rc=$?; }
said() { grep -qE -- "$1" <<<"$out"; }

fedora
run --role personal;                 check "empty root: diff shows the new files, exit 1" test $rc = 1 -a -n "$(said 'new: +/etc/killswitch.nft' && echo y)"
run --role personal --yes;           check "apply: exit 0" test $rc = 0
check "apply: rules file 644" test "$(stat -c %a "$r/etc/killswitch.nft")" = 644
check "apply: unit file 644" test "$(stat -c %a "$r/etc/systemd/system/killswitch.service")" = 644
check "apply: same content as the repo" cmp -s "$r/etc/killswitch.nft" "$REPO/system/killswitch/files/etc/killswitch.nft"
check "apply: systemctl skipped under --root" said 'skipped under --root: systemctl'
run --role personal;                 check "up to date: exit 0" test $rc = 0
echo "# local edit" >>"$r/etc/killswitch.nft"
run --role personal;                 check "content drift: shown as changed, exit 1" test $rc = 1 -a -n "$(said 'changed: +/etc/killswitch.nft' && echo y)"
run --role personal --yes;           check "content drift: apply restores the file" cmp -s "$r/etc/killswitch.nft" "$REPO/system/killswitch/files/etc/killswitch.nft"
chmod 600 "$r/etc/killswitch.nft"
run --role personal;                 check "mode drift: shown, exit 1" test $rc = 1 -a -n "$(said 'mode: +/etc/killswitch.nft \(600 → 644\)' && echo y)"
run --role personal --yes;           check "mode drift: apply restores 644" test "$(stat -c %a "$r/etc/killswitch.nft")" = 644
run --role work;                     check "wrong role, installed: told to remove it, exit 1" test $rc = 1 -a -n "$(said 'not meant for role=work' && echo y)"
run --remove killswitch;             check "remove: exit 0, files gone" test $rc = 0 -a ! -e "$r/etc/killswitch.nft" -a ! -e "$r/etc/systemd/system/killswitch.service"
run --remove killswitch;             check "remove twice: 'not installed'" said 'not installed'
run --role work;                     check "wrong role, not installed: skipped, exit 0" test $rc = 0 -a -n "$(said 'skipped' && echo y)"
rm -rf "$r"; ubuntu
run --role personal --yes;           check "Ubuntu os-release: installs (OS any)" test $rc = 0 -a -e "$r/etc/killswitch.nft"
run;                                 check "no --role: exit 2" test $rc = 2
run --remove;                        check "--remove without a name: exit 2" test $rc = 2
run --role personal --bogus;         check "unknown flag: exit 2" test $rc = 2
if ((EUID != 0)); then
  out=$("$inst" --role personal --yes 2>&1); rc=$?
  check "real / without root: refused before any change" test $rc = 1 -a -n "$(said 'run with pkexec' && echo y)"
fi

# Kill switch files. dceb925: Ubuntu keeps nft in /usr/sbin, so the unit names it bare
# (systemd's search path finds it) instead of a Fedora path.
unit="$REPO/system/killswitch/files/etc/systemd/system/killswitch.service"
check "unit: ExecStart/ExecStop call nft by name, not by path" test "$(grep -cE '^Exec(Start|Stop)=nft ' "$unit")" = 2
rules="$REPO/system/killswitch/files/etc/killswitch.nft"
if nft -c -f "$rules" >/dev/null 2>&1 || unshare -rn nft -c -f "$rules" >/dev/null 2>&1; then
  pass "rules: nft accepts the syntax (nft -c)"
elif ! command -v nft >/dev/null; then
  skip "rules syntax: no nft here"
else
  skip "rules syntax: nft -c needs root or a user namespace here (try: pkexec nft -c -f $rules)"
fi
