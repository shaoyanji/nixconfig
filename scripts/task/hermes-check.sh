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
  # The unit's PATH is what the daemon and every child it spawns resolve tools
  # from, and node/npm/npx and ffmpeg are dependencies of the gateway itself.
  # Neither is guaranteed by a profile after a switch: measured 2026-11-22,
  # ffmpeg survived only because a profile happened to carry it and node was
  # absent entirely, so `gateway.py`'s node probe and the audio/discord ffmpeg
  # calls would have failed. Assert the unit names both, and that they resolve
  # through that PATH, rather than trusting the module text.
  gateway_path="$(systemctl --user show hermes-gateway -p Environment 2>/dev/null |
    tr ' ' '\n' | sed -n 's/^Environment=PATH=//p; s/^PATH=//p' | head -1)"
  if [ -z "$gateway_path" ]; then
    warn "hermes-gateway unit exposes no Environment PATH — node/ffmpeg unasserted"
  else
    for want in nodejs ffmpeg; do
      case ":$gateway_path:" in
      *"$want"*) ok "hermes-gateway PATH names $want" ;;
      *) bad "hermes-gateway PATH has no $want — the unit lost the path modules/user/ai/hermes-user.nix adds" ;;
      esac
    done
    missing=""
    for bin in node ffmpeg; do
      env -i PATH="$gateway_path" bash -c "command -v $bin >/dev/null 2>&1" 2>/dev/null ||
        missing="$missing $bin"
    done
    if [ -z "$missing" ]; then
      ok "hermes-gateway PATH resolves node and ffmpeg"
    else
      bad "hermes-gateway PATH does not resolve:${missing}"
    fi
  fi
  # The unit file is not the running process: a unit switched but not restarted,
  # or a wrapper that rewrites PATH, leaves systemd's Environment and the
  # daemon's own environ disagreeing. /proc holds the environment the kernel
  # handed the daemon at exec, which is what every child it spawns inherits.
  main_pid="$(systemctl --user show -p MainPID --value hermes-gateway 2>/dev/null)"
  if [ -z "$main_pid" ] || [ "$main_pid" = "0" ] || [ ! -r "/proc/$main_pid/environ" ]; then
    warn "no readable /proc environ for hermes-gateway — live PATH unasserted"
  else
    live_path="$(tr '\0' '\n' <"/proc/$main_pid/environ" | sed -n 's/^PATH=//p' | head -1)"
    if [ -z "$live_path" ]; then
      warn "hermes-gateway process has no PATH in its environ"
    else
      for want in nodejs ffmpeg; do
        case ":$live_path:" in
        *"$want"*) ok "hermes-gateway process PATH names $want" ;;
        *) bad "hermes-gateway process PATH has no $want (unit and runtime disagree — restart the unit)" ;;
        esac
      done
      missing=""
      for bin in node ffmpeg; do
        env -i PATH="$live_path" bash -c "command -v $bin >/dev/null 2>&1" 2>/dev/null ||
          missing="$missing $bin"
      done
      if [ -z "$missing" ]; then
        ok "hermes-gateway process PATH resolves node and ffmpeg"
      else
        bad "hermes-gateway process PATH does not resolve:${missing}"
      fi
    fi
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
# The gateway's own unit is denied to agent turns: on 2026-11-22 a Telegram turn
# ran `systemctl --user restart hermes-gateway` mid-answer, and every stop after
# that paid the 60 s shutdown watchdog because a 30 s cron drain plus teardown
# crossed the leash. The protection is YAML-only — nothing in the unit or the
# wrapper carries it — so it is asserted here, together with the shortened
# drain, or the next config edit silently hands the daemon back to its agents.
if ! command -v yq >/dev/null 2>&1; then
  skip "yq not on PATH — approvals.deny unasserted"
else
  # -r matters: without it every rule arrives JSON-quoted and no rule matches.
  deny="$(yq -p yaml -o json -r '.approvals.deny // [] | .[]' "$persona" 2>/dev/null)"
  missing=""
  for rule in \
    "systemctl --user restart hermes-gateway*" \
    "systemctl --user stop hermes-gateway*" \
    "systemctl --user kill hermes-gateway*" \
    "systemctl restart hermes-gateway*" \
    "systemctl stop hermes-gateway*" \
    "hermes gateway restart" \
    "hermes gateway stop"; do
    grep -qxF -- "$rule" <<<"$deny" || missing="$missing|$rule"
  done
  if [ -z "$missing" ]; then
    ok "approvals.deny keeps agent turns off the gateway's own unit ($(grep -c . <<<"$deny") rules)"
  else
    bad "approvals.deny lost self-unit rule(s): $(tr '|' ' ' <<<"$missing" | sed 's/^ *//')"
  fi
  # `// empty` is jq syntax and yq v4 errors on it, which read as "absent".
  drain="$(yq -p yaml -o json -r '.agent.cron_drain_timeout // ""' "$persona" 2>/dev/null)"
  case "$drain" in
    '' | *[!0-9]*)
      bad "agent.cron_drain_timeout is absent or not a number (${drain:-none}) — a stop waits the 30 s default and can cross the 60 s shutdown watchdog"
      ;;
    *)
      if [ "$drain" -le 10 ]; then
        ok "agent.cron_drain_timeout=$drain stays under the shutdown watchdog"
      else
        bad "agent.cron_drain_timeout=$drain is above 10 s — a stop can cross the watchdog again"
      fi
      ;;
  esac
fi
if command -v hermes >/dev/null 2>&1; then
  # Exit 3 is the deny verdict; the text is what names the reason.
  verdict="$(hermes approvals test 'systemctl --user restart hermes-gateway' 2>&1 || true)"
  if grep -q 'user-deny' <<<"$verdict"; then
    ok "live verdict: the self-unit restart is denied to agent turns"
  else
    bad "live verdict does not deny \`systemctl --user restart hermes-gateway\`: $(grep -m1 'verdict' <<<"$verdict" || echo 'no verdict line')"
  fi
fi
if command -v hermes >/dev/null 2>&1; then
  version_line="$(hermes doctor 2>&1 | grep -m1 'Config version' || true)"
  case "$version_line" in
    *"up to date"*) ok "${version_line#"${version_line%%[![:space:]]*}"}" ;;
    *) bad "hermes reports: ${version_line:-<no config version line>}" ;;
  esac
fi
for f in config.yaml SOUL.md AGENTS.md USER.md MEMORY.md; do
  if [ ! -e "$home/.hermes/$f" ]; then
    warn "$home/.hermes/$f missing"
  elif [ ! -e "$(readlink -f "$home/.hermes/$f")" ]; then
    bad "$home/.hermes/$f is a dangling symlink"
  else
    ok "$home/.hermes/$f resolves"
  fi
done

echo "== handoff loop"
handoff_found=0
for f in "$home/.hermes/handoff.md" "$home/.hermes/HANDOFF.md"; do
  if [ -e "$f" ]; then
    bad "handoff file exists: $f — MEMORY.md forbids a handoff channel"
    handoff_found=1
  fi
done
if [ -d "$home/.hermes/handoffs" ]; then
  bad "handoff directory exists: $home/.hermes/handoffs — MEMORY.md forbids a handoff channel"
  handoff_found=1
fi
[ "$handoff_found" -eq 0 ] && ok "no handoff files"

echo
if [ "$fail" -ne 0 ]; then
  echo "hermes surface: DEFECT(S) above" >&2
  exit 1
fi
echo "hermes surface: clean"
