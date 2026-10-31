# shellcheck shell=bash
# mullvad-wg against fakes: curl (Mullvad's API), nmcli, wg, hostname (tests/fakes/).
# No network, no real keys, no NetworkManager changes. Each case is a fix from 2026-10-31.
. "$TESTS/lib.sh"
needs jq column awk

export FAKE="$WORK/fake" XDG_RUNTIME_DIR="$WORK/run" XDG_STATE_HOME="$WORK/state"
export PATH="$TESTS/fakes:$PATH" MULLVAD_ACCOUNT=1234567812345678 NM_PERM=yes
mkdir -p "$FAKE" "$XDG_RUNTIME_DIR"
mwg() { out=$(bash "$REPO/home/private_dot_local/bin/executable_mullvad-wg" "$@" 2>&1); rc=$?; }
said() { grep -qE -- "$1" <<<"$out"; }
keys="$XDG_RUNTIME_DIR/mullvad-wg"
reg="$XDG_STATE_HOME/mullvad-wg/devices.tsv"
no_key_left() { [[ -z $(ls -A "$keys" 2>/dev/null) ]]; }
nothing_registered() { ! grep -q '^ARGV: POST https://api.mullvad.net/accounts/v1/devices' "$FAKE/argv.log" 2>/dev/null; }

# 4d863a0: NetworkManager's permission is checked before a key is made or a device registered.
NM_PERM=auth mwg add ch-zrh-wg-001
check "NM permission 'auth': add stops, exit 1" test $rc = 1
check "NM permission 'auth': explains polkit" said "'auth': polkit would ask"
check "NM permission 'auth': no key made" no_key_left
check "NM permission 'auth': nothing registered" nothing_registered
NM_PERM=fail mwg keygen mv-ch-zrh-001
check "NM not readable: keygen stops, says '(not readable)'" test $rc = 1 -a -n "$(said 'not readable' && echo y)"
check "NM not readable: no key made" no_key_left

# 5221d8d: API unreachable (kill switch, no tunnel) is said as such, before anything is made.
FAKE_DOWN=1 mwg add ch-zrh-wg-001
check "API down: stops with 'can't reach api.mullvad.net'" test $rc = 1 -a -n "$(said "can't reach api.mullvad.net" && echo y)"
check "API down: no key made" no_key_left

# Happy path. 82cc92b: authenticated calls failed (the token's config pipe closed before curl
# read it); the fake curl answers 401 unless it can read the token from --config.
: >"$FAKE/argv.log"
mwg add ch-zrh-wg-001
check "add: exit 0" test $rc = 0
[[ $rc = 0 ]] || printf '%s\n' "$out" | sed 's/^/        /'
check "add: authenticated calls worked (device registered)" grep -q '^ARGV: POST https://api.mullvad.net/accounts/v1/devices' "$FAKE/argv.log"
check "add: every API call has a time limit (5221d8d)" test "$(grep -c '^ARGV: [A-Z]* https://api.mullvad.net/[a-z]' "$FAKE/argv.log")" -le "$(grep -c '^LIMIT: --max-time' "$FAKE/argv.log")"
check "add: profile named after the server" grep -qx mv-ch-zrh-001 "$FAKE/nm.list"
check "add: registry line for this machine" awk -F'\t' '$4 == "mv-ch-zrh-001" && $6 == "testbox" {f=1} END {exit !f}' "$reg"
check "add: registry is private (600)" test "$(stat -c %a "$reg")" = 600
check "add: key and .conf gone from RAM after import" no_key_left
check "add: autoconnect off" grep -q 'modify mv-ch-zrh-001 connection.autoconnect no' "$FAKE/nmcli.log"
check "add: left disconnected (4d863a0)" grep -q 'connection down mv-ch-zrh-001' "$FAKE/nmcli.log"
check "add: account number in no output" test -z "$(grep -r 1234567812345678 "$FAKE" "$XDG_STATE_HOME"; grep 1234567812345678 <<<"$out")"

mwg add ch-zrh-wg-001 --profile mv-zrh-boot --boot
check "add --boot: exit 0" test $rc = 0
check "add --boot: autoconnect on" grep -q 'modify mv-zrh-boot connection.autoconnect yes' "$FAKE/nmcli.log"
refute "add --boot: stays connected" grep -q 'connection down mv-zrh-boot' "$FAKE/nmcli.log"

mwg add ch-zrh-wg-001
check "add twice: refused before a key is made" test $rc = 1 -a -n "$(said 'already has a profile mv-ch-zrh-001' && echo y)"
check "add twice: no key left over" no_key_left
mwg devices
check "devices: lists both, with machine and profile" test $rc = 0 -a "$(grep -c testbox <<<"$out")" = 2
mwg register ch-zrh-wg-001 --pubkey not-a-key
check "register: refuses a malformed public key" test $rc = 1 -a -n "$(said "doesn't look like a WireGuard public key" && echo y)"
mwg keygen mv-this-is-too-long
check "keygen: refuses a profile name over 15 characters" test $rc = 1
mwg import "profile=mv-ch-zrh-009 pubkey=x addr=y peer=z endpoint=e"
check "import without keygen here: refused" test $rc = 1 -a -n "$(said 'no key for mv-ch-zrh-009' && echo y)"

mwg remove --machine testbox --profile mv-ch-zrh-001
check "remove: exit 0, removed at Mullvad" test $rc = 0 -a -n "$(said 'removed device dev-1' && echo y)"
check "remove: NM profile deleted" grep -q 'connection delete mv-ch-zrh-001' "$FAKE/nmcli.log"
refute "remove: registry line gone" grep -q 'mv-ch-zrh-001' "$reg"
check "remove: the other device kept" grep -q 'mv-zrh-boot' "$reg"
mwg remove --machine testbox --profile mv-ch-zrh-001
check "remove again: 'nothing in the registry'" test $rc = 1 -a -n "$(said 'nothing in the registry' && echo y)"
