#!/usr/bin/env bash
# Prove the Google Calendar credential is alive, in one request, and name which
# kind of death it had. `vdirsyncer.service` failed every 15 minutes for three
# days with "Server disconnected" per collection while the line that mattered was
# `(invalid_grant) Token has been expired or revoked` — sixteen hundred log lines
# around one fact that a token exchange states outright.
#
# A token is runtime state, not config: this reads it, exchanges its
# refresh_token for an access token, and touches no calendar.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
. "$repo_root/scripts/task/lib/paths.sh"

token="${GCAL_CHECK_TOKEN:-${XDG_CONFIG_HOME:-$HOME/.config}/vdirsyncer/google_token}"

for tool in sops curl jq python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "gcal-check: $tool is not on PATH" >&2
    exit 3
  fi
done

# No token is a legitimate state, not a failure: vdirsyncer.service carries
# ConditionPathExists on this file, so an un-consented host is skipped on purpose.
if [ ! -s "$token" ]; then
  echo "gcal-check: ok — no token at $token, so vdirsyncer.service is skipped by design"
  exit 0
fi

kind=$(python3 - "$token" <<'PY' 2>/dev/null || echo unknown
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("unreadable")
else:
    print("time-based" if d.get("refresh_token_expires_in") else "permanent")
PY
)

client_id="$(secret_get '["googleDrive"]["clientId"]' || true)"
client_secret="$(secret_get '["googleDrive"]["clientSecret"]' || true)"
if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
  echo "gcal-check: cannot read googleDrive credentials with this identity" >&2
  exit 3
fi

refresh="$(jq -r '.refresh_token // empty' "$token")"
if [ -z "$refresh" ]; then
  echo "gcal-check: FAIL the token file has no refresh_token — re-consent with" >&2
  echo "  .agents/skills/calendar/scripts/calendar-auth.sh auth --force" >&2
  exit 1
fi

work="$(mktemp)"
trap 'rm -f "$work"' EXIT
code="$(curl -s --max-time 20 -o "$work" -w '%{http_code}' \
  -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$client_id" \
  -d "client_secret=$client_secret" \
  -d "refresh_token=$refresh" \
  -d 'grant_type=refresh_token' || echo 000)"

case "$code" in
200)
  echo "gcal-check: ok — refresh token accepted ($kind grant), access token for $(jq -r '.expires_in // "?"' "$work")s"
  if [ "$kind" = "time-based" ]; then
    # Counted from the moment of consent, not from now: the file is written at
    # consent, so the issue time is expires_at minus expires_in.
    dies="$(python3 - "$token" <<'PY'
import datetime, json, sys
d = json.load(open(sys.argv[1]))
issue = d.get("expires_at", 0) - d.get("expires_in", 0)
dies = issue + d.get("refresh_token_expires_in", 0)
print(datetime.datetime.fromtimestamp(dies).strftime("%Y-%m-%d %H:%M"))
PY
)"
    echo "  warning: the grant is time-based and stops syncing at ${dies} — re-approve choosing permanent access" >&2
  fi
  ;;
400)
  err="$(jq -r '.error // "unknown"' "$work")"
  if [ "$err" != "invalid_grant" ]; then
    echo "gcal-check: FAIL $err: $(jq -r '.error_description // ""' "$work")" >&2
    exit 1
  fi
  echo "gcal-check: FAIL invalid_grant — the refresh token is dead; sync cannot work" >&2
  echo "  re-consent: .agents/skills/calendar/scripts/calendar-auth.sh auth --force" >&2
  if [ "$kind" = "time-based" ]; then
    echo "  this grant is time-based (refresh_token_expires_in set): pick permanent access this time" >&2
  fi
  echo "  dies again within a week → publish the OAuth consent screen (Testing caps refresh tokens at 7 days)" >&2
  exit 1
  ;;
*)
  echo "gcal-check: FAIL the token endpoint answered $code: $(head -c 200 "$work")" >&2
  exit 1
  ;;
esac
