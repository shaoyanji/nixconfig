#!/usr/bin/env bash
# checks:infron — the balance guard on the shared Infron caller, without a request.
#
# Why (2026-11-18): the route's two `:free` ids are billed at zero, and any other
# id spends a prepaid $5 that nothing tops up. That rule lives in one script now
# (scripts/infron-chat.sh), so it needs one gate: these refusals are the only
# thing between a typo in a model id and the balance.
#
# No network and no token. The refusal cases exit before `curl` is reached, and
# the request-shaped cases run against a stub `curl` placed first on PATH, which
# records the model id it was asked for. So the check proves the guard, the
# default pair, and the fallback order without spending anything.
#
# Exit 0 = clean, 1 = defect.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper="$repo/scripts/infron-chat.sh"
free_primary="deepseek/deepseek-v4-flash-0731:free"
free_backup="qwen/qwen3.8-27b:free"
fail=0

ok() { printf '  ok    %s\n' "$*"; }
bad() {
  printf '  FAIL  %s\n' "$*" >&2
  fail=1
}

if [ ! -f "$helper" ]; then
  echo "checks:infron: $helper is missing" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
log="$work/models"
: >"$log"

# The stub answers like the route does: with `__code:<status>` appended, which is
# the shape the caller parses. `fallback` fails the first id and answers the
# second, `down` fails both.
cat >"$work/bin/curl" <<'STUB'
#!/usr/bin/env bash
payload=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[i]}" = "--data-binary" ] && payload="${args[i+1]#@}"
done
jq -r '.model // empty' "$payload" 2>/dev/null >>"${STUB_LOG:?}"
seen="$(wc -l <"$STUB_LOG" 2>/dev/null || echo 0)"
if [ "${STUB_MODE:-fallback}" = "down" ] || [ "$seen" -eq 1 ]; then
  printf '{"error":{"message":"stub rate limit"}}\n__code:429'
else
  printf '{"choices":[{"message":{"content":"stub answer"}}]}\n__code:200'
fi
STUB
chmod +x "$work/bin/curl"

# call <expect> <label> [VAR=value ...] -- <args ...>
# Runs the helper with the stub first on PATH and leaves rc, stdout and stderr in
# $work. The expectation is the exit status the guard must produce.
call() {
  local expect="$1" label="$2"
  shift 2
  local vars=()
  while [ "$1" != "--" ]; do
    vars+=("$1")
    shift
  done
  shift
  [ ${#vars[@]} -gt 0 ] && export "${vars[@]}"
  : >"$log"
  PATH="$work/bin:$PATH" STUB_LOG="$log" STUB_MODE="${STUB_MODE:-fallback}" \
    bash "$helper" "$@" >"$work/out" 2>"$work/err"
  local rc=$?
  while [ ${#vars[@]} -gt 0 ]; do
    unset "${vars[0]%%=*}"
    vars=("${vars[@]:1}")
  done
  if [ "$rc" -eq "$expect" ]; then
    ok "$label (rc=$rc)"
  else
    bad "$label: expected rc=$expect, got rc=$rc; stderr: $(tr '\n' ' ' <"$work/err")"
  fi
}

export INFRON_API_KEY="${INFRON_API_KEY:-stub-key}"

echo "== refusals"
call 2 "a paid primary id is refused" INFRON_MODEL=deepseek/deepseek-v4-pro -- "hi"
grep -q ':free' "$work/err" && ok "the refusal names the :free rule" || bad "the refusal does not mention :free"
[ -s "$log" ] && bad "a refused model still made a request" || ok "no request left the helper for a refused model"

call 2 "a paid backup id is refused" INFRON_BACKUP_MODEL=deepseek/deepseek-v4-pro -- "hi"
[ -s "$log" ] && bad "a refused backup still made a request" || ok "no request for a refused backup"

(
  unset INFRON_API_KEY
  PATH="$work/bin:$PATH" STUB_LOG="$log" bash "$helper" "hi" >"$work/out" 2>"$work/err"
) ; rc=$?
[ "$rc" -eq 2 ] && ok "an unset INFRON_API_KEY is refused (rc=2)" || bad "unset key gave rc=$rc, expected 2"
grep -q 'INFRON_API_KEY' "$work/err" && ok "the refusal names the variable" || bad "the refusal does not name INFRON_API_KEY"

echo "== defaults and failover"
: >"$log"
PATH="$work/bin:$PATH" STUB_LOG="$log" STUB_MODE=fallback bash "$helper" "hi" >"$work/out" 2>"$work/err"
rc=$?
[ "$rc" -eq 0 ] && ok "a 429 on the primary still answers (rc=0)" || bad "fallback run exited $rc"
[ "$(cat "$work/out")" = "stub answer" ] && ok "the backup's content is what reaches stdout" || bad "stdout was '$(cat "$work/out")'"
first="$(sed -n 1p "$log")"
second="$(sed -n 2p "$log")"
[ "$first" = "$free_primary" ] && ok "primary is $free_primary" || bad "primary was '$first'"
[ "$second" = "$free_backup" ] && ok "backup is $free_backup" || bad "backup was '$second'"
case "$first$second" in
  *[!:]free* | "") bad "a default model id does not end in :free" ;;
  *) ok "both defaults end in :free" ;;
esac

echo "== configured ids"
# The route is named in one repo file (the hermes persona). Its model ids are
# router-style `family/name`, so any id without `:free` there would spend the
# balance even though the helper's own defaults are correct.
persona="$repo/modules/user/ai/hermes-persona/config.yaml"
if [ -f "$persona" ]; then
  ids="$(grep -oE '(deepseek|qwen)/[A-Za-z0-9._:-]+' "$persona" | sort -u)"
  if [ -z "$ids" ]; then
    bad "no Infron model id found in the persona config — has the route moved?"
  else
    while IFS= read -r id; do
      case "$id" in
        *:free) ok "persona id $id is :free" ;;
        *) bad "persona id $id is not :free — the route bills that id" ;;
      esac
    done <<<"$ids"
  fi
else
  bad "$persona is missing"
fi

echo "== hermes spend guard"
# The persona is read structurally here, not grepped: a paid id can hide in
# fields a `(deepseek|qwen)` pattern never sees — model.default, a fallback
# entry, another providers.<name> block, or the catalog a live /models probe
# serves the picker. The spend rule the file must keep (measured 2026-11-19,
# when a picker-selected nemotron-3.5-super billed the prepaid balance):
#
#   1. on a metered route (custom endpoint, openrouter) an id may only be
#      named with its `:free` suffix — that suffix is the zero-billing contract
#   2. ollama-cloud/ollama/lmstudio/nous are closed free lanes — any id there
#      is unbilled
#   3. every providers.<name> row must be pinned: discover_models: false plus a
#      list-shaped models: allowlist, or the picker probes the endpoint and
#      offers its paid ids
#   4. model_catalog.excluded_providers hides the keyed billable vendors from
#      every picker (CLI, TUI, gateway slash); hermes' cost guard warns only on
#      known pricing and stays silent on a custom route
#   5. the chain must cross vendors: Infron's daily quota is account-scoped, so
#      a same-route second id is not a failover, it is the same failure
if ! command -v yq >/dev/null 2>&1; then
  bad "yq is required to read the persona's spend fields"
elif [ ! -f "$persona" ]; then
  bad "cannot read the persona's spend fields: $persona is missing"
else
  persona_default="$(yq -r '.model.default // ""' "$persona")"
  case "$persona_default" in
    *:free) ok "model.default $persona_default is :free" ;;
    *) bad "model.default '$persona_default' is not :free — the primary bills on every turn" ;;
  esac
  case "$(yq -r '.model.provider // ""' "$persona")" in
    custom | infron) ok "model.provider stays on the declared route" ;;
    *) bad "model.provider moved off the declared route — gate its ids before merging" ;;
  esac

  # Every providers.<name> entry: pinned catalog, every declared id :free. An
  # empty map fails too — without a named entry shadowing the endpoint's URL,
  # the picker falls back to a bare "custom" row that probes it live.
  prov_count="$(yq '.providers | length' "$persona" 2>/dev/null || echo 0)"
  [ "$prov_count" -ge 1 ] || bad "providers: is empty — the bare custom row probes the route's paid catalog"
  for pname in $(yq -r '.providers | keys | .[]' "$persona"); do
    if [ "$(yq -r ".providers.$pname.discover_models" "$persona")" = "false" ]; then
      ok "providers.$pname discover_models: false pins the picker row"
    else
      bad "providers.$pname probes its catalog live — the picker offers the route's paid ids"
    fi
    if [ "$(yq ".providers.$pname.models | type" "$persona")" = "!!seq" ]; then
      ok "providers.$pname models: is a list-shaped allowlist"
      id_src=".providers.$pname.models[]"
    else
      bad "providers.$pname models: is not a list — a dict is metadata, not an allowlist"
      id_src=".providers.$pname.models | keys | .[]"
    fi
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      case "$id" in
        *:free) ;;
        *) bad "providers.$pname names paid id '$id'" ;;
      esac
    done < <(yq -r "$id_src, .providers.$pname.default_model? // \"\"" "$persona")
  done

  # The chain: at least two independent free quotas. Metered-route entries need
  # :free; closed-lane providers (ollama-cloud, ollama, lmstudio, nous) carry
  # their free contract in the provider, not the id.
  fb_count="$(yq '.fallback_providers | length' "$persona" 2>/dev/null || echo 0)"
  [ "$fb_count" -ge 2 ] && ok "fallback chain has $fb_count lanes" \
    || bad "fallback chain has $fb_count lane(s) — Infron's daily quota is account-scoped, so a same-route second id is the same failure"
  while IFS=$'\t' read -r fb_provider fb_model; do
    [ -n "$fb_provider" ] || continue
    case "$fb_provider" in
      custom | openrouter)
        case "$fb_model" in
          *:free) ok "fallback $fb_provider/$fb_model is :free" ;;
          *) bad "fallback $fb_provider/$fb_model — a metered-route id without :free spends the balance" ;;
        esac
        ;;
      ollama-cloud | ollama | lmstudio | nous)
        ok "fallback $fb_provider/$fb_model is on a closed free lane"
        ;;
      *)
        bad "fallback provider '$fb_provider' can bill — only :free ids on metered routes or the closed free lanes are allowed"
        ;;
    esac
  done < <(yq -r '.fallback_providers[]? | (.provider // "") + "\t" + (.model // "")' "$persona")

  # Picker denylist: the keyed billable vendors must all be hidden. Slugs match
  # case-insensitively upstream; the list here is asserted verbatim.
  required_excl="nvidia openai-api openrouter deepseek gemini groq cerebras aihubmix cohere tinker opencode-zen opencode-go nous"
  excl_list="$(yq -r '.model_catalog.excluded_providers[]?' "$persona")"
  missing_excl=""
  for p in $required_excl; do
    grep -qxF "$p" <<<"$excl_list" || missing_excl="$missing_excl $p"
  done
  [ -z "$missing_excl" ] && ok "model_catalog.excluded_providers hides the keyed billable vendors" \
    || bad "model_catalog.excluded_providers is missing:$missing_excl"

  [ "$(yq -r '.auxiliary.free_only // false' "$persona")" = "true" ] \
    && ok "auxiliary.free_only stays on" \
    || bad "auxiliary.free_only is off — aux calls can reach paid openrouter ids"

  # Dead-key regression + restart budget: api_max_retries is read from agent.,
  # not fallback, and every failover hop consumes one restart-count credit —
  # the turn dies at rebuilt_restart_limit_exceeded below the chain length.
  if yq -e '.fallback.api_max_retries' "$persona" >/dev/null 2>&1; then
    bad "fallback.api_max_retries is dead config — the key is read from agent.api_max_retries"
  else
    ok "no dead fallback.api_max_retries"
  fi
  retries="$(yq -r '.agent.api_max_retries // 0' "$persona")"
  if [ "$retries" -ge "$fb_count" ] 2>/dev/null; then
    ok "agent.api_max_retries ($retries) covers the $fb_count-lane chain"
  else
    bad "agent.api_max_retries ($retries) < fallback lanes ($fb_count) — a failover hop needs one restart credit each"
  fi
fi

echo "== dsh provider"
# The dsh overlay is repo-owned, so every field that makes it the Infron route is
# checkable, and a model id that lost its `:free` suffix is the same balance risk
# here as in the reasonix provider block.
dsh_patch="$repo/modules/user/ai/dsh-infron.patch.yml"
dsh_wrapper="$repo/scripts/dsh-infron.sh"
if [ -f "$dsh_patch" ]; then
  ok "the dsh overlay exists"
  if grep -q 'id: llm-pi-ai' "$dsh_patch"; then
    ok "the overlay targets the llm-pi-ai provider plugin"
  else
    bad "the dsh overlay does not target llm-pi-ai"
  fi
  if grep -q 'api: openai-completions' "$dsh_patch"; then
    ok "the route speaks OpenAI Chat Completions"
  else
    bad "the dsh route does not name its API protocol"
  fi
  if grep -q 'baseURL: https://llm.onerouter.pro/v1' "$dsh_patch"; then
    ok "the dsh route points at llm.onerouter.pro/v1"
  else
    bad "the dsh route does not point at Infron"
  fi
  if grep -q 'apiKeyEnv: INFRON_API_KEY' "$dsh_patch"; then
    ok "the dsh route reads INFRON_API_KEY"
  else
    bad "the dsh route does not name INFRON_API_KEY"
  fi
  dsh_ids="$(grep -oE '(deepseek|qwen)/[A-Za-z0-9._:-]+' "$dsh_patch" | sort -u)"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case "$id" in
      *:free) ok "dsh model $id is :free" ;;
      *) bad "dsh model $id is not :free — the route bills that id" ;;
    esac
  done <<<"$dsh_ids"
else
  bad "$dsh_patch is missing"
fi
if [ -f "$dsh_wrapper" ]; then
  if grep -q 'INFRON_MODEL:-\$primary' "$dsh_wrapper"; then
    ok "the dsh wrapper defaults to the :free primary"
  else
    bad "the dsh wrapper does not default to the :free primary"
  fi
  if grep -q '\*:free)' "$dsh_wrapper"; then
    ok "the dsh wrapper refuses a non-:free id"
  else
    bad "the dsh wrapper has no :free guard"
  fi
else
  bad "$dsh_wrapper is missing"
fi

echo "== reasonix provider"
# The provider block is user state (`~/.reasonix/config.toml`), so it is checked
# where it exists and skipped where it does not — but a block that names a paid id
# or the wrong route is the same balance risk as a bad default in the helper.
rx="$HOME/.reasonix/config.toml"
wrapper="$repo/scripts/infron-subagent.sh"
if [ -f "$wrapper" ]; then
  if grep -q 'INFRON_MODEL:-deepseek/deepseek-v4-flash-0731:free' "$wrapper"; then
    ok "the wrapper defaults to the :free primary"
  else
    bad "the wrapper does not default to the :free primary"
  fi
  if grep -q '\*:free)' "$wrapper"; then
    ok "the wrapper refuses a non-:free id"
  else
    bad "the wrapper has no :free guard"
  fi
else
  bad "$wrapper is missing"
fi
if [ -f "$rx" ]; then
  if grep -Eq 'name[[:space:]]*=[[:space:]]*"infron"' "$rx"; then
    ok "~/.reasonix/config.toml declares the infron provider"
  else
    bad "~/.reasonix/config.toml has no infron provider — infron-subagent cannot answer"
  fi
  if grep -Eq 'base_url[[:space:]]*=[[:space:]]*"https://llm\.onerouter\.pro/v1"' "$rx"; then
    ok "the provider points at llm.onerouter.pro/v1"
  else
    bad "the provider base_url is not the Infron route"
  fi
  if grep -Eq 'api_key_env[[:space:]]*=[[:space:]]*"INFRON_API_KEY"' "$rx"; then
    ok "the provider reads INFRON_API_KEY"
  else
    bad "the provider does not name INFRON_API_KEY"
  fi
  rx_ids="$(grep -oE '(deepseek|qwen)/[A-Za-z0-9._:-]+' "$rx" | sort -u)"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case "$id" in
      *:free) ok "reasonix model $id is :free" ;;
      *) bad "reasonix model $id is not :free — the route bills that id" ;;
    esac
  done <<<"$rx_ids"
else
  ok "no ~/.reasonix/config.toml (provider block is user state; skipped)"
fi

echo "== dispatch"
# The dispatcher is the operator's one command, so its plan is checkable without a
# request: which agent a task kind picks, that a plan never names a paid id, and that
# the JSON shape a program parses is the one the dry run prints.
dispatcher="$repo/scripts/dispatch.sh"
if [ -f "$dispatcher" ]; then
  ok "the dispatcher exists"
  plan_code="$(bash "$dispatcher" --dry-run --kind code "fix the failing assertion in scripts/x.sh" 2>/dev/null)"
  plan_quick="$(bash "$dispatcher" --dry-run --kind quick "name one risk" 2>/dev/null)"
  first_code="$(printf '%s\n' "$plan_code" | head -1)"
  first_quick="$(printf '%s\n' "$plan_quick" | head -1)"
  case "$first_code" in
    reasonix:*) ok "a code task walks reasonix first" ;;
    *) bad "the code plan starts with '$first_code'" ;;
  esac
  case "$first_quick" in
    dsh:*) ok "a quick task walks dsh first" ;;
    *) bad "the quick plan starts with '$first_quick'" ;;
  esac
  paid=""
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "${entry#*:}" in
      *:free) ;;
      *) paid="${entry#*:}" ;;
    esac
  done <<<"$(printf '%s\n%s\n' "$plan_code" "$plan_quick")"
  [ -n "$paid" ] && bad "a dispatch plan names the paid id '$paid'" || ok "every planned model id is :free"
  if bash "$dispatcher" --dry-run --json "hi" 2>/dev/null | jq -e '.dry_run and (.plan | length > 0)' >/dev/null 2>&1; then
    ok "the dry-run plan parses as the documented JSON"
  else
    bad "the dry-run plan is not the documented JSON shape"
  fi
  forced="$(bash "$dispatcher" --dry-run --kind quick --agent reasonix "hi" 2>/dev/null | head -1)"
  case "$forced" in
    reasonix:*) ok "--agent restricts the plan to one agent" ;;
    *) bad "--agent did not restrict the plan: '$forced'" ;;
  esac
  auto_code="$(bash "$dispatcher" --dry-run "please refactor scripts/dispatch.sh" 2>/dev/null | head -1)"
  case "$auto_code" in
    reasonix:*) ok "kind=auto reads a path and a verb as a code task" ;;
    *) bad "kind=auto misread a code task: '$auto_code'" ;;
  esac
  bash "$dispatcher" --dry-run --kind nonsense "hi" >/dev/null 2>&1
  [ $? -eq 2 ] && ok "an unknown kind is refused" || bad "an unknown kind was not refused"
  bash "$dispatcher" --dry-run --agent nope "hi" >/dev/null 2>&1
  [ $? -eq 2 ] && ok "an unknown agent is refused" || bad "an unknown agent was not refused"
  bash "$dispatcher" --dry-run -- "" </dev/null >/dev/null 2>&1
  [ $? -eq 2 ] && ok "an empty prompt is refused" || bad "an empty prompt was not refused"
  if grep -Eq 'modules/secrets|secrets\.yaml' "$dispatcher"; then
    bad "the dispatcher spells the secrets path instead of leaving it to the wrappers"
  else
    ok "the dispatcher takes the secrets path from paths.sh"
  fi
else
  bad "$dispatcher is missing"
fi

echo "== both down"
: >"$log"
PATH="$work/bin:$PATH" STUB_LOG="$log" STUB_MODE=down bash "$helper" "hi" >"$work/out" 2>"$work/err"
rc=$?
[ "$rc" -eq 1 ] && ok "two failures exit 1" || bad "both-down exited $rc, expected 1"
grep -q 'both models failed' "$work/err" && ok "the failure says both models failed" || bad "the failure does not say both models failed"

# The installed binary is what callers actually run; it is absent before a switch,
# so its presence is checked but not its plumbing.
if command -v infron >/dev/null 2>&1; then
  installed="$(command -v infron)"
  if INFRON_MODEL=deepseek/deepseek-v4-pro INFRON_API_KEY=x infron hi >/dev/null 2>&1; then
    bad "$installed accepted a paid model id"
  else
    [ $? -eq 2 ] && ok "$installed refuses a paid id too" || bad "$installed refused with the wrong status"
  fi
else
  ok "infron not on PATH yet (a switch installs it); the source was checked"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "infron guard: DEFECT(S) above" >&2
  exit 1
fi
echo "infron guard: clean"
