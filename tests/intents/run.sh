#!/usr/bin/env bash
# Fixture for checks:intents (scripts/task/intents-check.sh + flake/intents.nix).
#
# Proves the gate's judgment on the report it consumes (a seeded broken report
# must fail and name the failure) AND the schema's verdicts through a live
# .#intents eval — the three refusal classes and the admit:
#
#   admit          devin admits a chain-change inside its radius
#   kind refuse    tmux-pane-steward cannot admit chain-change (route, do not execute)
#   radius refuse  freebuff's claims sit inside modules/,hosts/,AGENTS.nix only
#   undeclared     a capability name nobody declared refuses outright
#   place          admit names the tier; a capability providing a kind it cannot
#                  reach is the capReachMisses invariant — seeded, since declared
#                  data cannot produce one
#   route          .#intents.route answers kind -> {place,tier,io,gate,cmd} —
#                  experiment proves clanker, a lane without clanker is refused
#
# classOf: two dispatches with the same kind over the same claims share one
# quotient class — subject does not participate; kind does.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

gate=scripts/task/intents-check.sh
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

# --- 1. the current tree passes ----------------------------------------------
if bash "$gate" >/dev/null 2>&1; then
  echo "ok   current tree passes the gate"
else
  echo "FAIL current tree does not pass the gate"
  fail=1
fi

# --- 2. a seeded broken report must fail and name the failure -----------------
cat >"$tmp/undeclared-source.json" <<'EOF'
{"ok":false,"failures":["xs source 'ghost-lane' has no capability declaration"],"undeclaredSources":["ghost-lane"],"undeclaredVerbs":[]}
EOF
if ! out=$(bash "$gate" "$tmp/undeclared-source.json" 2>&1); then
  echo "ok   undeclared source report fails the gate"
  grep -q "ghost-lane" <<<"$out" \
    && echo "ok   the failure names the source" \
    || { echo "FAIL the failure does not name the source"; fail=1; }
else
  echo "FAIL gate accepted a report with an undeclared source"
  fail=1
fi

cat >"$tmp/sample-miss.json" <<'EOF'
{"ok":false,"failures":["sample nixconfig:steward-devin-drive-x on devin: want true, got false"],"undeclaredSources":[],"undeclaredVerbs":[]}
EOF
if ! out=$(bash "$gate" "$tmp/sample-miss.json" 2>&1); then
  echo "ok   admit-verdict miss report fails the gate"
  grep -q "want true, got false" <<<"$out" \
    && echo "ok   the failure names the verdict miss" \
    || { echo "FAIL the failure does not name the verdict miss"; fail=1; }
else
  echo "FAIL gate accepted a report with a sample miss"
  fail=1
fi

cat >"$tmp/reach-miss.json" <<'EOF'
{"ok":false,"failures":["freebuff provides chain-change but cannot reach place 'local-gate'"],"undeclaredSources":[],"undeclaredVerbs":[]}
EOF
if ! out=$(bash "$gate" "$tmp/reach-miss.json" 2>&1); then
  echo "ok   reach-miss report fails the gate"
  grep -q "cannot reach place" <<<"$out" \
    && echo "ok   the failure names the unreachable place" \
    || { echo "FAIL the failure does not name the place"; fail=1; }
else
  echo "FAIL gate accepted a report with a reach miss"
  fail=1
fi

# --- 3. the verdict classes, through the live spec ----------------------------
verdicts="$(nix eval --json .#intents --apply 'i: {
  admitted = i.admit { intent = { subject = "t"; kind = "chain-change"; claims = ["modules/"]; gate = "checks:drv-equality"; }; capability = "devin"; };
  kindRefused = i.admit { intent = { subject = "t"; kind = "chain-change"; claims = ["modules/"]; gate = "checks:drv-equality"; }; capability = "tmux-pane-steward"; };
  radiusRefused = i.admit { intent = { subject = "t"; kind = "chain-change"; claims = ["lib/agent-turns/"]; gate = "checks:drv-equality"; }; capability = "freebuff"; };
  undeclared = i.admit { intent = { subject = "t"; kind = "chain-change"; claims = []; gate = "checks:drv-equality"; }; capability = "ghost-lane"; };
}' 2>/dev/null)"

check() { # json  name  jq-expression  expected
  got="$(jq -r "$3" <<<"$1")"
  if [ "$got" = "$4" ]; then
    echo "ok   $2"
  else
    echo "FAIL $2 (want $4, got $got)"
    fail=1
  fi
}

check "$verdicts" "devin admits chain-change in radius"        '.admitted.ok'         'true'
check "$verdicts" "admit names the place tier"                 '.admitted.why | test("at local-gate")' 'true'
check "$verdicts" "steward refused chain-change"               '.kindRefused.ok'      'false'
check "$verdicts" "kind refusal says route-not-execute"        '.kindRefused.why | test("route, do not execute")' 'true'
check "$verdicts" "freebuff refused out-of-radius claim"       '.radiusRefused.ok'    'false'
check "$verdicts" "radius refusal names the claim"             '.radiusRefused.why | test("outside")' 'true'
check "$verdicts" "undeclared capability refused"              '.undeclared.ok'       'false'

# --- 4. the route — kind -> place, tier, gate, command --------------------------
routes="$(nix eval --json .#intents --apply 'i: {
  exp = i.route.experiment;
  expAdmit = i.admit { intent = { subject = "t"; kind = "experiment"; claims = ["modules/"]; gate = "clanker:jobs"; }; capability = "devin"; };
  expRefused = i.admit { intent = { subject = "t"; kind = "experiment"; claims = ["modules/"]; gate = "clanker:jobs"; }; capability = "freebuff"; };
  flakeChange = i.route."flake-change";
  drive = i.route.drive;
}' 2>/dev/null)"

check "$routes" "experiment routes to clanker (never local disk)" '.exp.place'   'clanker'
check "$routes" "clanker is the offload tier"                    '.exp.tier'     '3'
check "$routes" "the route names a clanker command"              '.exp.cmd | test("clanker")' 'true'
check "$routes" "devin admits experiment at clanker"             '.expAdmit.why | test("at clanker")' 'true'
check "$routes" "a lane without clanker reach is refused"        '.expRefused.ok' 'false'
check "$routes" "flake-change stays eval"                        '.flakeChange.place' 'eval'
check "$routes" "drive stays delphi"                             '.drive.place'  'delphi'

# --- 5. classOf — the dedup key -----------------------------------------------
classes="$(nix eval --json .#intents --apply 'i: let
  a = i.classOf { subject = "s-1"; kind = "chain-change"; claims = ["modules/" "hosts/"]; gate = "g"; };
  b = i.classOf { subject = "s-2"; kind = "chain-change"; claims = ["hosts/" "modules/"]; gate = "g"; };
  c = i.classOf { subject = "s-1"; kind = "gate-change";  claims = ["modules/" "hosts/"]; gate = "g"; };
in { inherit a b c; }' 2>/dev/null)"

check "$classes" "same kind+claims share a class (subject, claim order ignored)" '.a == .b' 'true'
check "$classes" "a different kind is a different class"                         '.a == .c' 'false'
check "$classes" "the class is a quotient hash (a number)"                       '.a | type == "number"' 'true'

if [ "$fail" -eq 0 ]; then
  echo "intents fixture: all cases ok"
else
  exit 1
fi
