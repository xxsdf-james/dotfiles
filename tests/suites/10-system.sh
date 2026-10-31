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
check "unit: ExecStart/ExecReload/ExecStop call nft by name, not by path" test "$(grep -cE '^Exec(Start|Reload|Stop)=nft ' "$unit")" = 3
# K3: a rule change reloads (one nft -f transaction) instead of restarting, which dropped the table for a moment.
check "unit: ExecReload loads the rules file" grep -qx 'ExecReload=nft -f /etc/killswitch.nft' "$unit"
# K5: the rules must be loaded before the network comes up at boot, not after.
check "unit: ordered before the network (Before=network-pre.target)" grep -qx 'Before=network-pre.target' "$unit"
check "unit: started at boot (WantedBy=multi-user.target)" grep -qx 'WantedBy=multi-user.target' "$unit"
check "manifest: apply uses reload-or-restart, not restart" grep -q 'reload-or-restart killswitch.service' "$REPO/system/killswitch/manifest"
rules="$REPO/system/killswitch/files/etc/killswitch.nft"
# K5: also through sudo when that works without a prompt (sudo -n; run `sudo -v` first on the VM).
if nft -c -f "$rules" >/dev/null 2>&1 || unshare -rn nft -c -f "$rules" >/dev/null 2>&1 \
   || sudo -n nft -c -f "$rules" >/dev/null 2>&1; then
  pass "rules: nft accepts the syntax (nft -c)"
elif ! command -v nft >/dev/null; then
  skip "rules syntax: no nft here"
else
  skip "rules syntax: nft -c needs root, a user namespace or cached sudo here (try: sudo -v, or pkexec nft -c -f $rules)"
fi

# K3: no plain UDP to 51820 (only packets with WireGuard's fwmark), no DNS outside the tunnel.
check "rules: port 51820 only with a fwmark" has "$rules" '^\s*meta mark != 0 udp dport 51820 accept$'
refute "rules: no bare 'udp dport 51820 accept' left" has "$rules" '^\s*udp dport 51820 accept'
dns_before_lan() {  # dns_before_lan CHAIN: the DNS drop comes before that chain's LAN accept
  awk -v c="$1" '$1=="chain"{in_c=($2==c)} in_c&&/th dport \{ 53, 853 \} drop/{d=NR} in_c&&/ip daddr \{ 10\.0\.0\.0\/8/{l=NR} END{exit !(d&&l&&d<l)}' "$rules"
}
check "rules: output drops DNS (53, 853) before the LAN accept" dns_before_lan output
check "rules: forward drops DNS (53, 853) before the LAN accept" dns_before_lan forward

# Live checks, only where the kill switch runs and no tunnel is up (the VM test). A packet the
# output chain drops makes the send fail with EPERM, so no root is needed to see it.
if systemctl is-active --quiet killswitch.service 2>/dev/null && ! ip -o link show 2>/dev/null | grep -q ' mv-'; then
  udp() { timeout 3 bash -c "echo x >/dev/udp/$1/$2" 2>/dev/null; }
  gw=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
  refute "live, VPN down: plain UDP to 192.0.2.1:51820 blocked" udp 192.0.2.1 51820
  refute "live, VPN down: DNS to 9.9.9.9:53 blocked" udp 9.9.9.9 53
  refute "live, VPN down: DNS over TLS/QUIC to 9.9.9.9:853 blocked" udp 9.9.9.9 853
  if [[ -n $gw ]]; then
    refute "live, VPN down: DNS to the router ($gw:53) blocked" udp "$gw" 53
    check "live, VPN down: other LAN traffic to the router still allowed ($gw:9)" udp "$gw" 9
  else
    skip "live: no default route, router checks skipped"
  fi
  refute "live, VPN down: name lookup fails" timeout 5 getent hosts example.com

  # K5, IPv6: the table is inet and output's policy is drop, so a global IPv6 send must fail with
  # EPERM. ENETUNREACH means there's no IPv6 route, so the packet never reached the kill switch:
  # that's a SKIP, not a pass. (On the VM: add a throwaway address and route first.)
  v6=$(timeout 3 bash -c 'echo x >/dev/udp/2001:db8::1/9' 2>&1); v6rc=$?
  case $v6 in
    *"Operation not permitted"*) pass "live, VPN down: IPv6 to 2001:db8::1 blocked (EPERM)" ;;
    *"unreachable"*|*"Cannot assign requested address"*)
      skip "live IPv6: no IPv6 route or address here, so nothing reaches the kill switch ($(tail -n1 <<<"$v6"))" ;;
    *) if ((v6rc == 0)); then fail "live, VPN down: IPv6 to 2001:db8::1 was sent (not blocked)"
       else fail "live, VPN down: IPv6 send failed for another reason: $(tail -n1 <<<"$v6")"; fi ;;
  esac

  # K5, boot order: after a boot, the kill switch must be active before NetworkManager starts.
  # If it started long after NetworkManager, it was started by hand or by an apply since boot.
  ks=$(systemctl show -P ActiveEnterTimestampMonotonic killswitch.service 2>/dev/null)
  nm=$(systemctl show -P ExecMainStartTimestampMonotonic NetworkManager.service 2>/dev/null)
  if [[ ${ks:-0} == 0 || ${nm:-0} == 0 ]]; then
    skip "live boot order: no NetworkManager start time here"
  elif ((ks <= nm)); then
    pass "live boot order: kill switch active before NetworkManager started"
  elif ((ks - nm > 120000000)); then
    skip "live boot order: kill switch started $(((ks - nm) / 1000000)) s after NetworkManager (by hand or an apply since boot; reboot and run again)"
  else
    fail "live boot order: kill switch active $(((ks - nm) / 1000000)) s after NetworkManager started"
  fi

  # K5, forward chain: a rootful container's traffic is forwarded (rootless podman goes through
  # output instead, which the checks above already cover). Needs podman, sudo without a prompt
  # and the image already pulled (the pull itself is blocked with the VPN down).
  img=${KS_TEST_IMAGE:-docker.io/library/busybox:latest}
  if command -v podman >/dev/null && sudo -n podman image exists "$img" 2>/dev/null; then
    ctr() { sudo -n podman run --rm --network bridge "$img" "$@"; }
    refute "live, container: TCP to 1.1.1.1:443 blocked (forward chain)" ctr timeout 5 nc 1.1.1.1 443 </dev/null
    refute "live, container: DNS lookup via 9.9.9.9 blocked" ctr timeout 5 nslookup example.com 9.9.9.9
    if [[ -n $gw ]]; then
      refute "live, container: DNS lookup via the router ($gw) blocked" ctr timeout 5 nslookup example.com "$gw"
      check "live, container: ping to the router ($gw) still allowed" ctr ping -c 1 -W 3 "$gw"
    fi
  else
    skip "live container checks: need podman, sudo -n and the image $img pulled (run on the VM)"
  fi
else
  skip "live kill switch checks: service not active here, or a mv-* tunnel is up (run on the VM)"
fi
