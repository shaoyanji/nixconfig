#!/usr/bin/env bash
# Prove the push channel end to end: publish a probe, then read it back out of
# the server's cache. A push server that is merely "configured" is how ntfy sat
# on delphi for nine days with an empty cache — the unit was active, the manual
# said it worked, and nothing ever published, so the failure this gate has to
# catch is delivery, not liveness.
#
# The password is the server's own `fleet` user, decrypted here from the tracked
# sops file, so this runs as the operator (devji), not as root.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
. "$repo_root/scripts/task/lib/paths.sh"

url="${NTFY_CHECK_URL:-http://127.0.0.1:8096}"
topic="${NTFY_CHECK_TOPIC:-fleet}"
user="${NTFY_CHECK_USER:-fleet}"

if ! command -v sops >/dev/null 2>&1; then
  echo "ntfy-check: sops is not on PATH; run this from the dev shell" >&2
  exit 3
fi
password="$(secret_get '["ntfy"]["fleet-password"]' || true)"
if [ -z "$password" ]; then
  echo "ntfy-check: cannot read ntfy/fleet-password with this identity" >&2
  exit 3
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "ntfy-check: curl is not on PATH" >&2
  exit 3
fi

marker="ntfy-check-$(date +%s)-$$"
echo "ntfy-check: publishing a probe to ${url}/${topic} as ${user}"

code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
  -u "${user}:${password}" \
  -H 'Title: ntfy delivery check' -H 'Tags: test' \
  --data "${marker}" "${url}/${topic}")"
if [ "${code}" != "200" ]; then
  echo "ntfy-check: FAIL publish returned ${code} (want 200)" >&2
  exit 1
fi

# The cache is the proof: the server buffers for 12 h, so a message that
# published but cannot be read back would never reach a phone either.
for _ in 1 2 3 4 5; do
  if curl -s --max-time 5 -u "${user}:${password}" "${url}/${topic}/json?poll=1&since=10m" \
    | grep -q "${marker}"; then
    echo "ntfy-check: ok — the probe is cached and readable at ${url}/${topic}"
    anon="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 --data x "${url}/${topic}" || true)"
    case "${anon}" in
      401 | 403) echo "ntfy-check: ok — anonymous publish refused with ${anon}" ;;
      *)
        echo "ntfy-check: FAIL anonymous publish returned ${anon} (want 401 or 403): the topic is writable by anyone on the tailnet" >&2
        exit 1
        ;;
    esac
    exit 0
  fi
  sleep 1
done

echo "ntfy-check: FAIL the probe published but never appeared in the cache" >&2
exit 1
