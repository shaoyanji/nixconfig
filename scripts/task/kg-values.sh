#!/usr/bin/env bash
# kg-values.sh — the SECOND step: the graph resolved the subject, now a directed
# `nix eval` fills the values that the command actually needs.
#
# Why this exists
# ---------------
# `ops:ask` answers *which node and which relation*, and stops there. That is the
# right half of an answer for reading and the wrong half for acting: "deploy fern"
# needs `arch`, `ssh_alias`, `status`, not a list of documents that mention fern.
# The graph knows the node; only the compiled registries know the values.
#
# So the mechanism is two steps and they are deliberately separate:
#   1. graph      kg-ask.sh (cached, ~5 ms) / kg-query.sh (sidecar, 28 ms vs 476 ms
#                 for jq) resolves type + id, and declines loudly on a typo.
#   2. values     ONE leaf `nix eval` of that subject's attr path — 0.10-0.15 s for
#                 `inventory.hosts.<h>` or `agentSkills.skills.<s>`.
#
# What step 2 may NOT do: evaluate a host configuration. A toplevel is 13 s and
# 700 MiB ([[flake/policies.nix#no-fleet-default]]), which is not a lookup, it is a
# build. Every attr path this script touches is a compiled registry, and the guard
# below refuses `nixosConfigurations` by name.
#
# The interesting case is the one where the two disagree: the graph can name a host
# that `inventory.toml` does not compile (it lists external boxes too). That is not
# an error here — it is reported as `values: null` with `managed: false`, because
# "the graph knows it, the inventory does not" is the exact gap this step measures.
#
# Usage
#   kg-values.sh --q "what touches fern"          # step 1 runs inside
#   kg-values.sh --type host --id fern            # subject already known
#   kg-ask.sh --json "..." | kg-values.sh          # from an answer on stdin
#
#   --human   table instead of JSON
#   --refresh passed through to kg-ask.sh (ignore the cached graph)
#
# Exit: 0 = values (or an honest null), 1 = graph/eval unavailable,
#       2 = unknown subject (the graph's own suggestions are printed), 3 = usage.
set -euo pipefail

FLAKE=".?submodules=1#"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUERY="$ROOT/scripts/task/kg-query.sh"
ASK="$ROOT/scripts/task/kg-ask.sh"

MODE=json
TYPE=""
ID=""
QUESTION=""
REFRESH=()
while [ $# -gt 0 ]; do
  case "$1" in
  --json) MODE=json ;;
  --human) MODE=human ;;
  --refresh) REFRESH=(--refresh) ;;
  --type)
    TYPE="${2:-}"
    shift
    ;;
  --id)
    ID="${2:-}"
    shift
    ;;
  --q)
    QUESTION="${2:-}"
    shift
    ;;
  -h | --help)
    sed -n '2,40p' "$0"
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    exit 3
    ;;
  esac
  shift
done

# --- step 1: resolve the subject ------------------------------------------------
# An explicit type/id wins; a question goes through the deterministic router; an
# answer on stdin is accepted as-is so the two steps can also be run by hand.
ASK_JSON=""
if [ -n "$QUESTION" ]; then
  ASK_JSON="$(bash "$ASK" --json "${REFRESH[@]}" "$QUESTION")" || exit 1
elif [ -z "$TYPE" ] && [ -z "$ID" ]; then
  if [ -t 0 ]; then
    echo "usage: $0 --q QUESTION | --type host|skill|doc|tag --id ID | <ask.json" >&2
    exit 3
  fi
  ASK_JSON="$(cat)"
fi

if [ -n "$ASK_JSON" ]; then
  TYPE="${TYPE:-$(jq -r '.subject.type // empty' <<<"$ASK_JSON")}"
  ID="${ID:-$(jq -r '.subject.id // empty' <<<"$ASK_JSON")}"
fi

# kg-ask returns a prefixed node id (`host:fern`); the attr path and the task name
# want the bare name, and the graph query takes the bare name too.
case "$ID" in
host:* | skill:* | doc:* | tag:*) ID="${ID#*:}" ;;
esac

if [ -z "$TYPE" ] || [ -z "$ID" ]; then
  # Two different non-subjects, deliberately not merged. A question the graph
  # answered outright (tag membership, stats) has nothing missing, so step 2 is a
  # no-op and says so. A question that named nothing is a decline — never a node
  # invented so that there is something to resolve.
  # No inline default: `${x:-{"k":[]}}` lets the brace close the expansion early.
  ask_for_jq="${ASK_JSON}"
  [ -n "$ask_for_jq" ] || ask_for_jq='{}'
  have="$(jq -r '(.results // []) | length' <<<"$ask_for_jq" 2>/dev/null)" || have=0
  case "$have" in '' | *[!0-9]*) have=0 ;; esac
  # UNKNOWN is a menu of the six patterns, not an answer — its hits are keyword
  # noise, so a non-empty result set there is still a decline.
  intent="$(jq -r '.intent // "UNKNOWN"' <<<"$ask_for_jq" 2>/dev/null)"
  if [ "$have" -gt 0 ] && [ "$intent" != "UNKNOWN" ]; then
    if [ "$MODE" = json ]; then
      jq -n -c --argjson a "$ASK_JSON" '{
        step: 2, complete: true, subject: null,
        intent: ($a.intent // null), values: (($a.results // [])[0:10]),
        vars: {}, commands: [],
        note: "the graph answer is complete; nothing was missing to resolve"}'
    else
      printf 'complete  : the graph answered outright (%s result(s)) — no values missing\n' "$have"
      jq -r '(.results // [])[0:10][]' <<<"$ASK_JSON"
    fi
    exit 0
  fi
  echo "kg-values: the graph resolved no subject, so there are no values to fetch." >&2
  [ -n "$ASK_JSON" ] && jq -r '.note // empty' <<<"$ASK_JSON" >&2
  exit 2
fi

case "$TYPE" in
host | skill | doc | tag) ;;
*)
  echo "kg-values: unsupported subject type '$TYPE' (host, skill, doc, tag)" >&2
  exit 2
  ;;
esac

# The graph is the authority on existence, so a typo keeps the one implementation
# that already prints suggestions — and the sidecar answers it in ~28 ms.
# The decline is JSON on stdout with exit 2, so capture it BEFORE deciding: `||` on
# an assignment would throw the suggestions away with the status.
set +e
NODE_JSON="$(bash "$QUERY" "$TYPE" "$ID" --json)"
NODE_RC=$?
set -e
if [ "$NODE_RC" -ne 0 ]; then
  err="$(jq -r '.error // "unknown subject"' <<<"$NODE_JSON" 2>/dev/null || echo unknown-subject)"
  sugg="$(jq -r '(.suggestions // []) | join(", ")' <<<"$NODE_JSON" 2>/dev/null || true)"
  echo "kg-values: $TYPE '$ID' — ${err//_/ }" >&2
  [ -n "$sugg" ] && echo "  did you mean: $sugg" >&2
  exit 2
fi

# --- the guard: no host configuration, ever ------------------------------------
attr_for() {
  case "$1" in
  host) echo "inventory.hosts.$2" ;;
  skill) echo "agentSkills.skills.$2" ;;
  *) echo "" ;;
  esac
}
ATTR="$(attr_for "$TYPE" "$ID")"
case "$ATTR" in
*nixosConfigurations* | *config.system.build*)
  echo "kg-values: refusing to evaluate a host configuration as a value lookup" >&2
  exit 3
  ;;
esac

# --- step 2: the directed eval --------------------------------------------------
# One attr, projected to the fields a command needs. `--apply` keeps the payload
# small; anything absent stays absent rather than becoming an empty string.
VALUES=null
ATTR_USED=""
if [ -n "$ATTR" ]; then
  ATTR_USED="$ATTR"
  case "$TYPE" in
  host)
    VALUES="$(nix eval --json "$FLAKE$ATTR" --apply 'h: {
      arch = h.arch or null;
      category = h.category or null;
      role = h.role or null;
      status = h.status or null;
      system_type = h.system_type or null;
      kind = h.kind or null;
      ssh_alias = h.network.ssh_alias or null;
      tailscale_ip = h.network.tailscale_ip or null;
      lan_ip = h.network.lan_ip or null;
      traits = h.software.traits or [];
    }' 2>/dev/null)" || VALUES=null
    ;;
  skill)
    VALUES="$(nix eval --json "$FLAKE$ATTR" --apply 's: {
      path = s.path or null;
      description = s.description or null;
      tags = s.tags or [];
      platforms = s.platforms or [];
      lineCount = s.lineCount or null;
    }' 2>/dev/null)" || VALUES=null
    ;;
  esac
fi

# --- vars: what an execution actually reads -------------------------------------
VARS="$(jq -c --arg type "$TYPE" --arg id "$ID" --argjson v "$VALUES" '
  def up: ascii_upcase | gsub("[^A-Z0-9]+"; "_");
  ($v // {}) as $v
  | if $type == "host" then {
      HOST: $id,
      ARCH: $v.arch,
      CATEGORY: $v.category,
      STATUS: $v.status,
      SSH_ALIAS: ($v.ssh_alias // $id),
      TAILSCALE_IP: $v.tailscale_ip,
      LAN_IP: $v.lan_ip,
      TRAITS: (($v.traits // []) | join(" "))
    }
    elif $type == "skill" then {
      SKILL: $id,
      SKILL_PATH: $v.path,
      TAGS: (($v.tags // []) | join(" "))
    }
    elif $type == "doc" then {DOC: $id}
    else {TAG: $id} end
  | with_entries(select(.value != null and .value != "" and .value != []))
' <<<"null")"

# --- commands: the graph's answer, expressed as the task that owns it -----------
# Conventions, not a second registry: the task surface is generated from the same
# inventory, so `infra:deploy:host:<n>` exists exactly when the host does.
COMMANDS="$(jq -c --arg type "$TYPE" --arg id "$ID" --argjson v "$VALUES" '
  ($v // {}) as $v
  | if $type == "host" then
      # `kind` is the discriminator the compiled inventory actually carries:
      # nixos/darwin/home are flake-managed, `external` is a box that only exists
      # in the registry (burgernas is a Synology: no deploy task exists for it).
      if ((["nixos", "darwin", "home"] | index($v.kind // "external")) != null) then
        ([{task: "checks:host", vars: {HOST: $id}, note: "gate: module system, assertions, registry"},
          {task: ("infra:deploy:host:" + $id), vars: {}, note: "one intended host; gate → plan → apply → validate"}]
         + (if $v.status == "preserved" then
              [{task: ("infra:deploy:host:" + $id), vars: {ALLOW_PRESERVED: "1"}, note: "dormant host: deploy/apply warn and exit 0 without ALLOW_PRESERVED"}]
            else [] end))
      else
        [{task: "ops:kg:host", vars: {HOST: $id},
          note: ("external, non-Nix host (" + ($v.system_type // $v.kind // "unknown") + "): nothing here deploys it — this is a read of what touches it")}]
      end
    elif $type == "skill" then [{task: "ops:kg:skill", vars: {SKILL: $id}, note: "every host and doc that mentions this skill"}]
    elif $type == "doc" then [{task: "ops:kg:doc", vars: {DOC: $id}, note: "hosts and skills this page names"}]
    else [{task: "ops:kg:tag", vars: {TAG: $id}, note: "skills carrying this tag"}] end
  | map(. + {command: (.task + " " + ([.vars | to_entries[] | "\(.key)=\(.value)"] | join(" ")))}
            | .command |= rtrimstr(" "))
' <<<"null")"

OUT="$(jq -n -c \
  --arg type "$TYPE" \
  --arg id "$ID" \
  --arg attr "$ATTR_USED" \
  --arg checked "$(jq -r '.pattern // "?"' <<<"$NODE_JSON" 2>/dev/null || echo '?')" \
  --argjson values "$VALUES" \
  --argjson vars "$VARS" \
  --argjson commands "$COMMANDS" \
  --argjson node "$(jq -c '{count: (.count // 0), results: ((.results // [])[0:5])}' <<<"$NODE_JSON" 2>/dev/null || echo '{"count":0,"results":[]}')" \
  '{
    step: 2,
    subject: {type: $type, id: $id},
    graph: $node,
    attr: (if $attr == "" then null else $attr end),
    managed: ($values != null),
    values: $values,
    vars: $vars,
    commands: $commands
  }')"

if [ "$MODE" = json ]; then
  echo "$OUT"
  exit 0
fi

printf 'subject   : %s %s\n' "$TYPE" "$ID"
printf 'graph     : %s hit(s) %s\n' "$(jq -r '.graph.count' <<<"$OUT")" \
  "$(jq -r 'if .managed then "" else "(no compiled values — the graph names it, inventory does not)" end' <<<"$OUT")"
printf 'eval      : %s\n' "$(jq -r '.attr // "—"' <<<"$OUT")"
echo
echo "vars (feed these to the command):"
jq -r '.vars | to_entries[] | "  \(.key)=\(.value)"' <<<"$OUT"
echo
echo "commands:"
jq -r '.commands[] | "  \(.command)\n      \(.note)"' <<<"$OUT"
