#!/usr/bin/env bash
# Prove the CalDAV service is a calendar, not a listener: PROPFIND the principal,
# then PUT a throwaway event, read it back and delete it. Radicale sat on delphi
# for nine days holding zero collections while `systemctl is-active radicale` was
# true the whole time — liveness was never the question.
#
# The password is the server's own user, decrypted here from the tracked sops
# file, so this runs as the operator rather than as root.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
. "$repo_root/scripts/task/lib/paths.sh"

url="${CALDAV_CHECK_URL:-https://delphi.cloudforest-kardashev.ts.net:8457}"
collection="${CALDAV_CHECK_COLLECTION:-personal}"
user="${CALDAV_CHECK_USER:-$(id -un)}"

for tool in sops curl; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "caldav-check: ${tool} is not on PATH" >&2
    exit 3
  fi
done
password="$(secret_get '["radicale"]["password"]' || true)"
if [ -z "${password}" ]; then
  echo "caldav-check: cannot read radicale/password with this identity" >&2
  exit 3
fi

base="${url}/${user}/${collection}"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

echo "caldav-check: probing ${base}"

# A principal that answers 404 here means the collection was never seeded; that
# is a real failure, not a missing fixture.
list="$(curl -s --max-time 15 -o /dev/null -w '%{http_code}' -u "${user}:${password}" \
  -X PROPFIND -H 'Depth: 1' -H 'Content-Type: application/xml' \
  --data '<?xml version="1.0"?><propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>' \
  "${base}/")"
case "${list}" in
  207 | 200) echo "caldav-check: ok — the collection answers PROPFIND with ${list}" ;;
  *)
    echo "caldav-check: FAIL PROPFIND returned ${list} (want 207); is the collection seeded and the password current?" >&2
    exit 1
    ;;
esac

uid="caldav-check-$(date +%s)-$$"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
cat >"${work}/probe.ics" <<ICS
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//nixconfig//caldav-check//EN
BEGIN:VEVENT
UID:${uid}
DTSTAMP:${stamp}
DTSTART:${stamp}
DTEND:${stamp}
SUMMARY:caldav delivery probe
END:VEVENT
END:VCALENDAR
ICS

put="$(curl -s --max-time 15 -o /dev/null -w '%{http_code}' -u "${user}:${password}" \
  -X PUT -H 'Content-Type: text/calendar; charset=utf-8' \
  --data-binary "@${work}/probe.ics" "${base}/${uid}.ics")"
case "${put}" in
  200 | 201) echo "caldav-check: ok — wrote a probe event with ${put}" ;;
  *)
    echo "caldav-check: FAIL PUT returned ${put} (want 200 or 201)" >&2
    exit 1
    ;;
esac

if ! curl -s --max-time 15 -u "${user}:${password}" "${base}/${uid}.ics" | grep -q "${uid}"; then
  echo "caldav-check: FAIL the probe event cannot be read back" >&2
  exit 1
fi
echo "caldav-check: ok — read the probe event back"

del="$(curl -s --max-time 15 -o /dev/null -w '%{http_code}' -u "${user}:${password}" \
  -X DELETE "${base}/${uid}.ics")"
case "${del}" in
  200 | 204) echo "caldav-check: ok — deleted the probe with ${del}" ;;
  *)
    echo "caldav-check: WARN delete returned ${del}; remove ${base}/${uid}.ics by hand" >&2
    ;;
esac

anon="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "${base}/" || true)"
case "${anon}" in
  401 | 403) echo "caldav-check: ok — anonymous read refused with ${anon}" ;;
  *)
    echo "caldav-check: FAIL anonymous read returned ${anon} (want 401 or 403)" >&2
    exit 1
    ;;
esac

echo "caldav-check: ok — ${base} is a writable, authenticated calendar"
