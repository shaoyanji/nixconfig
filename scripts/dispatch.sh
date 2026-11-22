#!/usr/bin/env bash
# dispatch — one command for the Infron backup queue: pick an agent, then a model.
#
# Three routes already answer on the route: `dsh-infron` (an agentic session), the
# reasonix wrapper (an agent with tools), and `infron` (one plain completion). Choosing
# between them by hand is the part that does not scale — a task that has to read a file
# or judge a diff wants the agent that can hold context, a short question wants the
# leanest route, and whichever agent is missing today must not become a failed command.
# This script owns that choice and the order it falls back in.
#
# The ladder is walked in order and stops at the first non-empty answer:
#
#   kind=code  (a diff, a script, a file to patch)
#     reasonix primary · reasonix backup · dsh primary · dsh backup · chat primary
#   kind=quick (a question, a classification, one paragraph)
#     dsh primary · dsh backup · reasonix primary · reasonix backup · chat primary
#
# A route whose binary is absent is skipped rather than attempted: `dsh-infron` falls
# back to reasonix without dsh, and `infron-subagent` falls back to the chat caller
# without reasonix, so trying them would walk the same path twice. `chat` needs curl.
#
# Model ids are read from the dsh overlay, the one copy of the route: the primary is
# what a new session starts on, the backup is the other id in its list. A `:free` rule
# still belongs to the wrappers, which refuse a paid id before any request.
#
# Usage:
#   dispatch "review the staged diff"
#   printf '%s' "$log" | dispatch --kind quick "what failed?"
#   dispatch --kind code --model backup "patch the failing assertion"
#   dispatch --dry-run --json "..."        # the plan, no request
#
# Exit: 0 answered · 1 every route failed · 2 usage or configuration.
set -uo pipefail

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
patch="$repo/modules/user/ai/dsh-infron.patch.yml"
kind=auto
model_arg=auto
forced_agent=auto
timeout_s=300
json=0
dry_run=0
prompt=""

die() {
  printf 'dispatch: %s\n' "$*" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
usage: dispatch [--kind auto|code|quick] [--model auto|primary|backup|ID]
                [--agent auto|dsh|reasonix|chat] [--timeout S] [--json]
                [--dry-run] [prompt]

The prompt is the remaining arguments, or stdin when it is `-` or absent.
kind=auto reads the task: a diff, code fence, path or 900+ characters means code.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --kind)
      [ $# -ge 2 ] || die "--kind needs a value"
      kind="$2"
      shift 2
      ;;
    --model)
      [ $# -ge 2 ] || die "--model needs a value"
      model_arg="$2"
      shift 2
      ;;
    --agent)
      [ $# -ge 2 ] || die "--agent needs a value"
      forced_agent="$2"
      shift 2
      ;;
    --timeout)
      [ $# -ge 2 ] || die "--timeout needs a value"
      timeout_s="$2"
      shift 2
      ;;
    --json)
      json=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option $1"
      ;;
    *)
      break
      ;;
  esac
done

[ "$timeout_s" -gt 0 ] 2>/dev/null || die "--timeout must be a positive number"
case "$kind" in
  auto | code | quick) ;;
  agent) kind=code ;;
  text) kind=quick ;;
  *) die "--kind must be auto, code or quick (got $kind)" ;;
esac
case "$forced_agent" in
  auto | dsh | reasonix | chat) ;;
  *) die "--agent must be auto, dsh, reasonix or chat (got $forced_agent)" ;;
esac

prompt="$*"
if [ -z "$prompt" ] || [ "$prompt" = "-" ]; then
  if [ ! -t 0 ]; then
    prompt="$(cat)"
  fi
fi
[ -n "${prompt//[[:space:]]/}" ] || die "no prompt (pass arguments, or pipe one on stdin)"

[ -f "$patch" ] || die "$patch is missing — the route overlay is not where this script expects it"

# All three routes read INFRON_API_KEY; two of them resolve it themselves, the plain
# caller does not. Resolving it here too keeps the last rung usable on a host where the
# agents are absent, and the path comes from the one place that owns it.
if [ -z "${INFRON_API_KEY:-}" ] && command -v sops >/dev/null 2>&1; then
  # shellcheck source=scripts/task/lib/paths.sh
  . "$repo/scripts/task/lib/paths.sh"
  INFRON_API_KEY="$(secret_get '["ai-services-shared-env"]' 2>/dev/null |
    sed -n 's/^INFRON_API_KEY=//p' | head -1)"
  [ -n "$INFRON_API_KEY" ] && export INFRON_API_KEY
fi

# The overlay is the route registry: the default model it names, and the second id in
# its list. Plain tools read them; yq's list traversal is not worth a dependency for
# two `family/name` tokens, and the gate greps the same regex.
primary="$(awk '/id: agent-default-model/{seen=1} seen && /model:/{print; exit}' "$patch" |
  sed -n 's/.*"\([^"]*\)".*/\1/p')"
if [ -z "$primary" ]; then
  primary="$(grep -oE '(deepseek|qwen)/[A-Za-z0-9._:-]+' "$patch" | head -1)"
fi
[ -n "$primary" ] || die "cannot read the primary model id from $patch"

backup="$(grep -oE '(deepseek|qwen)/[A-Za-z0-9._:-]+' "$patch" | grep -vxF "$primary" | head -1)"

case "$model_arg" in
  auto)
    models=("$primary")
    [ -n "$backup" ] && models+=("$backup")
    ;;
  primary) models=("$primary") ;;
  backup)
    [ -n "$backup" ] || die "the route declares no backup model; use --model primary or an id"
    models=("$backup")
    ;;
  *) models=("$model_arg") ;;
esac

# Availability is a property of the binary, not of the network: a missing agent must
# change the plan, not the outcome of the first request.
have_dsh() { command -v dsh >/dev/null 2>&1; }
have_reasonix() { command -v reasonix >/dev/null 2>&1; }
have_chat() { [ -f "$repo/scripts/infron-chat.sh" ]; }

route_available() {
  case "$1" in
    dsh) have_dsh ;;
    reasonix) have_reasonix ;;
    chat) have_chat ;;
    *) return 1 ;;
  esac
}

if [ "$kind" = auto ]; then
  text="$prompt"
  if printf '%s' "$text" | grep -q '```' ||
    printf '%s' "$text" | grep -Eqi '(^|[^a-z])(diff|patch|refactor|compile|typecheck|assert|taskfile|\.nix|\.sh|\.yml|\.toml|scripts/|git |commit|grep|sed|awk)'; then
    kind=code
  elif [ ${#text} -ge 900 ]; then
    kind=code
  else
    kind=quick
  fi
fi

if [ "$forced_agent" != auto ]; then
  ladder=("$forced_agent")
elif [ "$kind" = code ]; then
  ladder=(reasonix dsh chat)
else
  ladder=(dsh reasonix chat)
fi

plan=()
for agent in "${ladder[@]}"; do
  # A dry run names the declared plan, not the reachable one: which binaries a
  # host has installed changes nothing about the order a task kind should try.
  # checks:infron reads this plan on hosts without reasonix or dsh on PATH.
  if [ "$dry_run" -eq 0 ] && ! route_available "$agent"; then
    continue
  fi
  if [ "$agent" = chat ]; then
    # The plain caller does its own primary-then-backup failover in one request path;
    # listing both here would spend two dispatcher attempts on one route.
    plan+=("$agent:$primary")
    continue
  fi
  for model in "${models[@]}"; do
    plan+=("$agent:$model")
  done
done

if [ ${#plan[@]} -eq 0 ]; then
  die "no route is available (dsh, reasonix and the chat caller are all missing)"
fi

if [ "$dry_run" -eq 1 ]; then
  if [ "$json" -eq 1 ]; then
    printf '%s\n' "${plan[@]}" |
      jq -R -s 'split("\n") | map(select(length > 0)) | map(split(":") | {agent: .[0], model: (.[1:] | join(":"))}) |
        {dry_run: true, kind: $kind, plan: ., prompt_chars: ($chars | tonumber)}' \
        --arg kind "$kind" --arg chars "${#prompt}"
  else
    printf '%s\n' "${plan[@]}"
  fi
  exit 0
fi

attempts="$(mktemp)"
out="$(mktemp)"
err="$(mktemp)"
trap 'rm -f "$attempts" "$out" "$err"' EXIT
: >"$attempts"

started=$SECONDS
route_agent=""
route_model=""
answer=""

for entry in "${plan[@]}"; do
  agent="${entry%%:*}"
  model="${entry#*:}"
  : >"$out"
  : >"$err"
  t0=$SECONDS
  case "$agent" in
    dsh) INFRON_MODEL="$model" timeout "$timeout_s" bash "$repo/scripts/dsh-infron.sh" "$prompt" >"$out" 2>"$err" ;;
    reasonix) INFRON_MODEL="$model" timeout "$timeout_s" bash "$repo/scripts/infron-subagent.sh" "$prompt" >"$out" 2>"$err" ;;
    chat) INFRON_MODEL="$model" timeout "$timeout_s" bash "$repo/scripts/infron-chat.sh" "$prompt" >"$out" 2>"$err" ;;
  esac
  rc=$?
  secs=$((SECONDS - t0))
  jq -nc --arg agent "$agent" --arg model "$model" --argjson rc "$rc" --argjson secs "$secs" \
    --arg err "$(head -c 400 "$err")" \
    '{agent: $agent, model: $model, rc: $rc, seconds: $secs, error: $err}' >>"$attempts"
  printf 'dispatch: %s:%s rc=%s %ss\n' "$agent" "$model" "$rc" "$secs" >&2
  case "$rc" in
    0)
      if [ -n "$(tr -d '[:space:]' <"$out")" ]; then
        route_agent="$agent"
        route_model="$model"
        answer="$(cat "$out")"
        break
      fi
      printf 'dispatch: %s answered nothing\n' "$agent" >&2
      ;;
    2)
      # A wrapper's status 2 is a configuration answer (key, model rule, overlay): every
      # other route shares it, so falling through would only repeat the same refusal.
      printf 'dispatch: %s cannot run — %s\n' "$agent" "$(head -1 "$err")" >&2
      [ "$json" -eq 1 ] && jq -s '{ok: false, attempts: .}' "$attempts"
      exit 2
      ;;
    124) printf 'dispatch: %s timed out after %ss\n' "$agent" "$timeout_s" >&2 ;;
    *) [ -s "$err" ] && printf 'dispatch: %s failed — %s\n' "$agent" "$(tail -1 "$err")" >&2 ;;
  esac
done

total=$((SECONDS - started))

if [ -z "$route_agent" ]; then
  if [ "$json" -eq 1 ]; then
    jq -s --argjson secs "$total" --arg kind "$kind" '{ok: false, kind: $kind, seconds: $secs, attempts: .}' "$attempts"
  else
    printf 'dispatch: no route answered (tried %s)\n' "${plan[*]}" >&2
  fi
  exit 1
fi

if [ "$json" -eq 1 ]; then
  jq -s --arg agent "$route_agent" --arg model "$route_model" --argjson secs "$total" \
    --arg kind "$kind" --arg answer "$answer" \
    '{ok: true, kind: $kind, route: {agent: $agent, model: $model}, seconds: $secs, answer: $answer, attempts: .}' "$attempts"
else
  printf 'dispatch: answered via %s:%s in %ss\n' "$route_agent" "$route_model" "$total" >&2
  printf '%s\n' "$answer"
fi
