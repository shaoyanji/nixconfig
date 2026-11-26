#!/usr/bin/env bash
# Gate on the fleet sentinel verdict: `ok` AND recent, or a named failure.
#
# The sentinel writes health.txt from a 15-minute timer, so the file is the
# verdict only while the timer runs. A stale `ok` is the failure this script
# exists for: after an outage, a stuck timer, or a host that lost the unit, the
# last thing written stays `ok` and every caller that reads the file alone keeps
# believing it. The age ceiling is 45 minutes — three missed passes — and can be
# moved with OPS_HEALTH_MAX_AGE_MIN for a different cadence.
#
# Exit: 0 ok and fresh, 1 degraded, stale or no sentinel.
set -uo pipefail

health=${OPS_HEALTH_FILE:-/var/lib/fleet-sentinel/www/health.txt}
status=${OPS_HEALTH_STATUS:-/var/lib/fleet-sentinel/www/status.json}
max_age_min=${OPS_HEALTH_MAX_AGE_MIN:-45}

case "$max_age_min" in
  '' | *[!0-9]*)
    echo "sentinel: OPS_HEALTH_MAX_AGE_MIN must be a whole number of minutes" >&2
    exit 2
    ;;
esac

if [ ! -r "$health" ]; then
  echo "sentinel: no health file at $health (fleet-sentinel not enabled/running?)"
  exit 1
fi

now=$(date +%s)
mtime=$(stat -c %Y "$health" 2>/dev/null || echo "$now")
age_min=$(( (now - mtime) / 60 ))
state=$(cat "$health")

if [ "$state" = "ok" ]; then
  if [ "$age_min" -gt "$max_age_min" ]; then
    echo "sentinel: ok but stale — last verdict ${age_min}m ago (ceiling ${max_age_min}m): the timer is not running"
    exit 1
  fi
  echo "sentinel: ok (${age_min}m ago)"
  exit 0
fi

echo "sentinel: $state (${age_min}m ago)"
jq -r '.reasons[]?' "$status" 2>/dev/null || true
exit 1
