#!/usr/bin/env bash
# checks:hermes — exercise the hermes surface without spending a token.
#
# Why the call-site section exists (2026-11-05): the agent cascade's Tier 3 ran
# `hermes -q "$prompt" --oneshot`. `-q` is an option of the `chat` subcommand,
# so argparse exited 2 before any model call — "'<prompt>' is not a `hermes`
# command" — and every job that reached Tier 3 fell through to Tier 4. That
# held for as long as the tier existed, and nothing noticed, because the only
# observer was an 03:00 job whose failure was a quiet WARN line. The check
# below reads the flags `hermes --help` publishes rather than a list kept here,
# so it keeps holding when the CLI changes.
#
# Everything is local and deterministic: no model call, no ssh, no writes.
# Exit 0 = clean, 1 = a defect.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

ok() { printf '  ok    %s\n' "$*"; }
warn() { printf '  warn  %s\n' "$*"; }
bad() {
  printf '  FAIL  %s\n' "$*" >&2
  fail=1
}
skip() { printf '  skip  %s\n' "$*"; }

# --- 1. call sites -----------------------------------------------------------
# A top-level invocation whose first argument is a flag must use a flag the
# top-level parser accepts. Subcommand invocations (`hermes chat …`) are left
# alone: an unknown subcommand fails loudly on its own.
echo "== call sites"
if ! command -v hermes >/dev/null 2>&1; then
  skip "hermes not on PATH — call sites not validated"
else
  # Published top-level flags: those in the `usage:` block plus those in the
  # top-level `options:` section (exactly two spaces of indent, so the
  # four-space subcommand list under `positional arguments:` is excluded).
  help_text="$(hermes --help 2>&1)"
  top_flags="$({
    printf '%s\n' "$help_text" | awk 'NR <= 8'
    printf '%s\n' "$help_text" | awk '/^options:/ { opts = 1; next } opts && /^  -/ { print }'
  } | grep -oE -- '-{1,2}[a-zA-Z][a-zA-Z-]*' | sort -u)"
  sites=0
  while IFS=: read -r where _line flag; do
    sites=$((sites + 1))
    if grep -qxF -- "$flag" <<<"$top_flags"; then
      ok "$where: top-level $flag is published by hermes"
    else
      bad "$where: $flag is not a hermes top-level flag (it is likely a \`hermes chat\` option) — the tier exits 2 before running anything"
    fi
  done < <(
    # Comment lines are skipped on purpose: the cascade carries the broken
    # form in prose to explain why it is gone, and prose is not a call site.
    find "$repo/hosts" "$repo/scripts" "$repo/taskfiles" -type f \
      \( -name '*.nix' -o -name '*.sh' \) -print0 2>/dev/null |
      xargs -0 -r awk '
        {
          line = $0
          sub(/^[ \t]+/, "", line)
          if (line ~ /^#/) next
          if (!match($0, /hermes(_bin")? +-{1,2}[a-zA-Z][a-zA-Z-]*/)) next
          m = substr($0, RSTART, RLENGTH)
          n = split(m, parts, " ")
          print FILENAME ":" FNR ":" parts[n]
        }' | sed "s|^$repo/||"
  )
  [ "$sites" -gt 0 ] || warn "no top-level hermes call sites found — is the cascade still declared?"
fi

# --- 2. gateway -------------------------------------------------------------
echo "== gateway"
home="${HOME:-/home/devji}"
state="$home/.hermes/gateway_state.json"
if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user cat hermes-gateway >/dev/null 2>&1; then
  skip "no hermes-gateway user unit on this host"
elif ! systemctl --user is-active --quiet hermes-gateway; then
  bad "hermes-gateway is $(systemctl --user is-active hermes-gateway), not active"
else
  ok "hermes-gateway active"
  if command -v jq >/dev/null 2>&1 && [ -r "$state" ]; then
    # needs_attention is the daemon's own sticky signal: it survives a platform
    # reconnecting, so it is the honest health bit. A transient ConnectError
    # warning in the journal is not.
    attention="$(jq -r '(.platforms // {}) | to_entries[] | select(.value.needs_attention == true) | .key' "$state" 2>/dev/null)"
    [ -z "$attention" ] || bad "platform(s) flagged needs_attention: $(echo "$attention" | tr '\n' ' ')"
    jq -r '(.platforms // {}) | to_entries[] | "  ok    platform \(.key): \(.value.state)"' "$state" 2>/dev/null
    state_age=$(( $(date +%s) - $(stat -c %Y "$state") ))
    [ "$state_age" -lt 900 ] ||
      warn "gateway_state.json last written ${state_age}s ago — the daemon may be wedged"
  fi
fi

# --- 3. derived credential file --------------------------------------------
# ~/.hermes/.env is generated from the rendered file plus ~/.hermes/.env.local
# (hermes-env-sync). Values are never read, only drift: the question is whether
# a rotated sops key reached the file hermes actually loads.
echo "== secrets"
rendered=/run/secrets/rendered/hermes.env
dotenv="$home/.hermes/.env"
if [ ! -r "$rendered" ]; then
  skip "$rendered not readable (sops not rendered on this host)"
elif command -v hermes-env-sync >/dev/null 2>&1; then
  if drift="$(hermes-env-sync --check 2>&1)"; then
    ok "$dotenv matches $rendered (+ $(wc -l <"$home/.hermes/.env.local" 2>/dev/null || echo 0) local key(s))"
  else
    bad "credential file drifted: $drift"
  fi
elif [ ! -e "$dotenv" ]; then
  warn "no $dotenv and no hermes-env-sync on PATH yet — switch this host to install it"
else
  # Pre-switch fallback: compare key names only, report the same drift shape.
  keys() { grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | tr -d '=' | sort -u; }
  only_rendered="$(comm -23 <(keys "$rendered") <(keys "$dotenv"))"
  if [ -n "$only_rendered" ]; then
    bad "rendered keys absent from $dotenv: $(echo "$only_rendered" | tr '\n' ' ')"
  else
    warn "hermes-env-sync is not installed yet; key names match but values are unverified"
  fi
fi

# --- 4. config version & persona -------------------------------------------
echo "== config"
persona="$repo/modules/user/ai/hermes-persona/config.yaml"
if grep -qE '^_config_version:' "$persona"; then
  ok "persona config.yaml is version-stamped ($(grep -m1 -oE '^_config_version: *[0-9]+' "$persona" | grep -oE '[0-9]+'))"
else
  bad "persona config.yaml has no _config_version — hermes reads it as v0 and reports drift on every doctor"
fi
if command -v hermes >/dev/null 2>&1; then
  version_line="$(hermes doctor 2>&1 | grep -m1 'Config version' || true)"
  case "$version_line" in
    *"up to date"*) ok "${version_line#"${version_line%%[![:space:]]*}"}" ;;
    *) bad "hermes reports: ${version_line:-<no config version line>}" ;;
  esac
fi
for f in config.yaml SOUL.md AGENTS.md; do
  if [ ! -e "$home/.hermes/$f" ]; then
    warn "$home/.hermes/$f missing"
  elif [ ! -e "$(readlink -f "$home/.hermes/$f")" ]; then
    bad "$home/.hermes/$f is a dangling symlink"
  else
    ok "$home/.hermes/$f resolves"
  fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "hermes surface: DEFECT(S) above" >&2
  exit 1
fi
echo "hermes surface: clean"
