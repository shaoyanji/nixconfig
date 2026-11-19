#!/usr/bin/env bash
# dsh-infron — a headless dsh agent on the Infron `:free` route.
#
# dsh is model- and endpoint-agnostic through its profile patch layer: the provider
# plugin `@deepseek-ai/dsh-llm-pi-ai` (entry id `llm-pi-ai`) owns a `providers`
# map, and `agent-default-model` names the route a new session starts on. The
# overlay in modules/user/ai/dsh-infron.patch.yml supplies both, so the profile's
# own cordis.patch.yml is never edited and this file stays the single copy.
#
# The wrapper owns what the patch cannot: the key (resolved from INFRON_API_KEY or
# the shared sops blob), the `:free` rule, the per-run model override (dsh's
# headless app takes no --model flag, so a second overlay wins over the first), and
# the fallback to the reasonix wrapper when dsh is not installed.
#
# Usage:
#   dsh-infron "summarise the staged diff"
#   printf '%s' "$log" | dsh-infron -
#   INFRON_MODEL=qwen/qwen3.8-27b:free dsh-infron "…"
#
# Exit: 0 answered · 2 configuration (model or key) · otherwise the agent's status.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
primary="deepseek/deepseek-v4-flash-0731:free"
model="${INFRON_MODEL:-$primary}"
patch="$repo/modules/user/ai/dsh-infron.patch.yml"

case $model in
  *:free) ;;
  *)
    echo "dsh-infron: ${model} is not a :free id — the route bills it" >&2
    exit 2
    ;;
esac

if [ ! -f "$patch" ]; then
  echo "dsh-infron: ${patch} is missing — the route overlay is not where this wrapper expects it" >&2
  exit 2
fi

key="${INFRON_API_KEY:-}"
if [ -z "$key" ] && command -v sops >/dev/null 2>&1; then
  # The path is resolved in one place; this script only names the blob.
  # shellcheck source=scripts/task/lib/paths.sh
  . "$repo/scripts/task/lib/paths.sh"
  key="$(secret_get '["ai-services-shared-env"]' 2>/dev/null |
    sed -n 's/^INFRON_API_KEY=//p' | head -1)" || true
fi
if [ -z "$key" ]; then
  echo "dsh-infron: no INFRON_API_KEY (export it, or decrypt the shared sops blob here)" >&2
  exit 2
fi
export INFRON_API_KEY="$key"

if command -v dsh >/dev/null 2>&1; then
  overlays=(--patch "$patch")
  if [ "$model" != "$primary" ]; then
    overlay="$(mktemp)"
    trap 'rm -f "$overlay"' EXIT
    cat >"$overlay" <<EOF
- id: agent-default-model
  config:
    provider: infron
    model: "$model"
EOF
    overlays+=(--patch "$overlay")
  fi
  dsh --profile headless "${overlays[@]}" "$@"
  exit
fi

exec "$repo/scripts/infron-subagent.sh" "$@"
