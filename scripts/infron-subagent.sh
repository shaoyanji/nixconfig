#!/usr/bin/env bash
# infron-subagent — a headless backup subagent on the Infron `:free` route.
#
# `reasonix -p` is the agent: it takes a task, runs tools, and prints one answer.
# The provider is the `infron` entry in ~/.reasonix/config.toml (base_url
# https://llm.onerouter.pro/v1, api_key_env INFRON_API_KEY, models limited to the
# two `:free` ids). This wrapper owns the three things that otherwise get retyped:
#
#   1. the key, resolved from INFRON_API_KEY or the shared sops blob, and stored
#      where reasonix looks for it (~/.reasonix/.env, mode 600);
#   2. the `:free` rule — a paid id spends the prepaid balance that keeps the free
#      ones working, so it is refused before any request;
#   3. the fallback: with no reasonix installed, one plain `infron` completion is
#      still a useful backup queue.
#
# Usage:
#   infron-subagent "summarise the staged diff"
#   printf '%s' "$log" | infron-subagent "what failed?"
#   INFRON_MODEL=qwen/qwen3.8-27b:free infron-subagent "…"
#
# Exit: 0 answered · 2 configuration (model or key) · otherwise the agent's status.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
model="${INFRON_MODEL:-deepseek/deepseek-v4-flash-0731:free}"

case $model in
  *:free) ;;
  *)
    echo "infron-subagent: ${model} is not a :free id — the route bills it" >&2
    exit 2
    ;;
esac

key="${INFRON_API_KEY:-}"
if [ -z "$key" ] && command -v sops >/dev/null 2>&1 && [ -f "$repo/modules/secrets.yaml" ]; then
  key="$(sops -d "$repo/modules/secrets.yaml" 2>/dev/null |
    yq -p yaml -o json '.["ai-services-shared-env"]' -r 2>/dev/null |
    sed -n 's/^INFRON_API_KEY=//p' | head -1)" || true
fi
if [ -z "$key" ]; then
  echo "infron-subagent: no INFRON_API_KEY (export it, or decrypt modules/secrets.yaml here)" >&2
  exit 2
fi
export INFRON_API_KEY="$key"

# A fresh machine has reasonix and no provider block. The block is user state, so
# it is appended once, marked; the gate fails if a later edit names a paid id.
if command -v reasonix >/dev/null 2>&1; then
  rxcfg="${HOME}/.reasonix/config.toml"
  if [ -f "$rxcfg" ] && ! grep -Eq 'name[[:space:]]*=[[:space:]]*"infron"' "$rxcfg"; then
    cat >>"$rxcfg" <<'BLOCK'

# infron-subagent: the `:free` route; delete this block only with the wrapper.
[[providers]]
name        = "infron"
kind        = "openai"
base_url    = "https://llm.onerouter.pro/v1"
models      = ["deepseek/deepseek-v4-flash-0731:free", "qwen/qwen3.8-27b:free"]
default     = "deepseek/deepseek-v4-flash-0731:free"
api_key_env = "INFRON_API_KEY"
context_window = 131072
BLOCK
  fi
fi

if command -v reasonix >/dev/null 2>&1; then
  envfile="${HOME}/.reasonix/.env"
  mkdir -p "${HOME}/.reasonix"
  if ! grep -q '^INFRON_API_KEY=' "$envfile" 2>/dev/null; then
    printf 'INFRON_API_KEY=%s\n' "$key" >>"$envfile"
    chmod 600 "$envfile"
  fi
  exec reasonix -p --model "infron/${model}" "$@"
fi

exec "$repo/scripts/infron-chat.sh" --model "$model" "$@"
