#!/usr/bin/env bash
# Regression fixture for `task checks:ports` (scripts/task/port-audit.sh).
#
# The bucket rules that matter cannot be produced on demand from a live host: a
# declared port with only a loopback listener, a tailscaled mount, a global-list
# opening, a declaration with nothing behind it. So the audit runs against a fake
# PATH (`bin/`: hostname, nix, ss, sysctl, tailscale) with the declaration, the
# listener list and the serve status supplied as variables. The refusal paths get
# the same treatment: a foreign HOST and an interface that declares nothing must
# exit 2 rather than answer from the wrong inputs. Coverage is part of the gate —
# a case missing from EXPECTED, or an EXPECTED case that no longer runs, fails the
# fixture — so deleting the REDUNDANT case cannot pass as a smaller suite. No nix
# eval, no host, no network — under a second, which is why `checks:quick` carries it.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
audit="$repo/scripts/task/port-audit.sh"
bin="$here/bin"

command -v jq >/dev/null 2>&1 || {
  echo "fixture: jq is required (the audit parses the declaration with it)" >&2
  exit 2
}
[ -x "$audit" ] || {
  echo "fixture: $audit is not executable" >&2
  exit 2
}

# One exposure declaration, reused: 22 is declared on the interface, 8181 is not.
# Cases that need a different declaration replace it.
SCOPED='{"allowedTCPPorts":[],"allowedUDPPorts":[],"interfaces":{"tailscale0":{"allowedTCPPorts":[22],"allowedUDPPorts":[53]}}}'

# Every case this fixture is supposed to run. Coverage is asserted, not counted:
# deleting a case with its `run` call would otherwise just print a smaller number
# and still exit 0, which is the regression a fixture exists to prevent. Dropping
# one now means editing this list too — a reviewable act, not a silent one.
EXPECTED=(
  "redundant mesh row exits 1"
  "redundant over ::1 exits 1"
  "serve port is not a hole"
  "serve port from the Web map"
  "global opening is declared"
  "dead hole still fails under STRICT"
  "dead hole is only reported without STRICT"
  "foreign host is refused"
  "unscoped interface is refused"
)

fail=0
cases=0
ran=()
# The audit refuses rather than half-answers when it cannot trust its inputs, so
# those paths need a caller-supplied identity: they exit before any bucket.
RUN_HOST=fixture
RUN_IFACE=tailscale0
run() { # name want_rc needle...
  local name="$1" want="$2"
  shift 2
  local out rc needle
  cases=$((cases + 1))
  ran+=("$name")
  out="$(
    PATH="$bin:$PATH" HOST="$RUN_HOST" IFACE="$RUN_IFACE" STRICT="${STRICT:-0}" \
      FIXTURE_SS="$SS" FIXTURE_FIREWALL="$FIREWALL" FIXTURE_SERVE="$SERVE" \
      bash "$audit" 2>&1
  )"
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL $name: exit ${rc}, want ${want}"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  for needle in "$@"; do
    if ! grep -qF -- "$needle" <<<"$out"; then
      echo "FAIL $name: output lacks '${needle}'"
      printf '%s\n' "$out" | sed 's/^/     /'
      fail=1
      return
    fi
  done
  echo "ok   $name (exit ${rc})"
}

# 1. The rule this fixture exists for: a declared port whose listener binds
#    loopback is a hole with no possible client, and it fails without STRICT.
FIREWALL='{"allowedTCPPorts":[],"allowedUDPPorts":[],"interfaces":{"tailscale0":{"allowedTCPPorts":[22,8181],"allowedUDPPorts":[]}}}'
SERVE="{}"
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\ntcp LISTEN 0 4096 127.0.0.1:8181 0.0.0.0:*'
STRICT=0 run "redundant mesh row exits 1" 1 \
  "SERVED (declared + listening):        22 " \
  "REDUNDANT (declared, loopback only):  8181 " \
  "ERROR: REDUNDANT ports are declared on tailscale0"

# 2. The IPv6 loopback form must land in the same bucket, not in SERVED: `[::1]:`
#    was once the shape that made a loopback service look public.
SS=$'tcp LISTEN 0 4096 [::1]:8181 [::]:*'
FIREWALL='{"allowedTCPPorts":[],"allowedUDPPorts":[],"interfaces":{"tailscale0":{"allowedTCPPorts":[8181],"allowedUDPPorts":[]}}}'
STRICT=0 run "redundant over ::1 exits 1" 1 "REDUNDANT (declared, loopback only):  8181 "

# 3. A tailscaled mount needs no row: tailscaled terminates and forwards itself,
#    so an undeclared listener on a served port is SERVED-SERVE, not a hole.
FIREWALL="$SCOPED"
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\ntcp LISTEN 0 4096 100.97.61.65:8443 0.0.0.0:*'
SERVE='{"TCP":{"8443":{"HTTPS":true}},"Web":{}}'
STRICT=1 run "serve port is not a hole" 0 \
  "SERVED-SERVE (tailscaled mount):     8443 " \
  "FIREWALL-ONLY (public, undeclared):   none"

# 4. The `Web` key carries host:port, so it is the second shape the audit parses.
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\ntcp LISTEN 0 4096 100.97.61.65:8447 0.0.0.0:*'
SERVE='{"TCP":{},"Web":{"fixture.ts.net:8447":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:8083"}}}}}'
STRICT=1 run "serve port from the Web map" 0 "SERVED-SERVE (tailscaled mount):     8447 "

# 5. A global-list port is declared — open on every interface — not drift.
FIREWALL='{"allowedTCPPorts":[22],"allowedUDPPorts":[],"interfaces":{"tailscale0":{"allowedTCPPorts":[1966],"allowedUDPPorts":[]}}}'
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\ntcp LISTEN 0 4096 0.0.0.0:1966 0.0.0.0:*'
SERVE="{}"
STRICT=1 run "global opening is declared" 0 \
  "SERVED-GLOBAL (global list):         22 " \
  "FIREWALL-ONLY (public, undeclared):   none"

# 6. The gate still fails real drift: STRICT plus a declaration with no listener.
FIREWALL='{"allowedTCPPorts":[],"allowedUDPPorts":[],"interfaces":{"tailscale0":{"allowedTCPPorts":[9999],"allowedUDPPorts":[]}}}'
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*'
STRICT=1 run "dead hole still fails under STRICT" 1 \
  "DEAD-HOLE (declared, no listener):    9999 " \
  "ERROR: STRICT=1 with drift"

# 7. Without STRICT the same drift is reported but does not fail, so the two exit
#    behaviours stay distinct.
STRICT=0 run "dead hole is only reported without STRICT" 0 "DEAD-HOLE (declared, no listener):    9999 "

# 8. A foreign HOST is refused, not answered from this machine's listeners: on
#    delphi, frieren's declaration reported 21 DEAD-HOLE rows that all had a
#    listener — the audit had read the wrong machine's `ss`.
RUN_HOST=otherhost
FIREWALL="$SCOPED"
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*'
SERVE="{}"
STRICT=1 run "foreign host is refused" 2 \
  "but this machine is 'fixture'" \
  "Run it on that host instead"
RUN_HOST=fixture

# 9. An interface that declares nothing is a typo, not a finding: every listener
#    would land in FIREWALL-ONLY, which reads as drift and is unactionable. Refuse
#    it with the interface the operator probably meant.
FIREWALL='{"allowedTCPPorts":[],"allowedUDPPorts":[],"interfaces":{"enp1s0":{"allowedTCPPorts":[22],"allowedUDPPorts":[]}}}'
SS=$'tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*'
STRICT=1 run "unscoped interface is refused" 2 \
  "tailscale0 declares no ports on fixture" \
  "IFACE=tailscale0"

# Coverage, in both directions: a case in EXPECTED must have run, and a case that
# ran must be listed. The first catches a deleted `run` call, the second a case
# added without declaring it (which would otherwise be coverage nobody tracks).
ran_set="$(printf '%s\n' "${ran[@]}")"
expected_set="$(printf '%s\n' "${EXPECTED[@]}")"
for c in "${EXPECTED[@]}"; do
  if ! grep -qxF -- "$c" <<<"$ran_set"; then
    echo "FAIL coverage: expected case did not run: ${c}" >&2
    fail=1
  fi
done
for c in "${ran[@]}"; do
  if ! grep -qxF -- "$c" <<<"$expected_set"; then
    echo "FAIL coverage: case is not declared in EXPECTED: ${c}" >&2
    fail=1
  fi
done

if [ "$fail" != 0 ]; then
  echo "port-audit fixture: FAILED" >&2
  exit 1
fi
echo "port-audit fixture: ${cases} cases ok (all expected)"
