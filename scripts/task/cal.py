#!/usr/bin/env python3
"""The Cal.com booking surface as command verbs.

Reads are public where Cal.com makes them public: slots and the booking POST
need no authentication at all. What the key buys is the account view — event
types by slug, and the booking record with its attendee — which is the thing
khal does not carry.

Every endpoint pins its own `cal-api-version`: Cal.com keys the schema to that
header, so one shared constant would silently change the shape of the others.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

# api.cal.com sits behind Cloudflare's signature rules, which 403 the default
# `Python-urllib/x.y` agent with "browser_signature_banned". An honest agent
# string is let through; the ban is on the generic default, not on programs.
UA = "nixconfig-cal/1.0 (+https://github.com/shaoyanji/nixconfig)"

API = "https://api.cal.com/v2"
BOOKING_URL = os.environ.get("CAL_BOOKING_URL", "https://cal.com/mattji").rstrip("/")
DEFAULT_TZ = os.environ.get("CAL_TIMEZONE", "Europe/Berlin")

VERSIONS = {
    "events": "2024-06-14",
    "slots": "2024-09-04",
    "bookings": "2026-05-01",
    "write": "2026-02-25",
}

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
SECRETS = os.path.join(ROOT, "modules", "secrets", "secrets.yaml")

_TOKEN = None


def token():
    global _TOKEN
    if _TOKEN is not None:
        return _TOKEN
    try:
        _TOKEN = subprocess.check_output(
            ["sops", "-d", "--extract", '["caldotcom"]', SECRETS],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""
    return _TOKEN


def api(method, path, version, *, body=None, query=None, auth=True):
    url = API + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Accept": "application/json", "User-Agent": UA, "cal-api-version": version}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if auth:
        value = token()
        if not value:
            sys.exit(
                "cal: no caldotcom in the secrets plane — this verb reads the account, "
                "which only an agent-backend host declares (frieren, delphi)"
            )
        headers["Authorization"] = "Bearer " + value
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        payload = error.read().decode("utf-8", "replace")
        try:
            message = json.loads(payload).get("error", {}).get("message") or payload
        except json.JSONDecodeError:
            message = payload
        sys.exit("cal: %s %s -> %s: %s" % (method, path, error.code, message.strip()))
    except urllib.error.URLError as error:
        sys.exit("cal: %s %s failed: %s" % (method, path, error.reason))


def zone(name):
    from zoneinfo import ZoneInfo

    try:
        return ZoneInfo(name)
    except Exception:
        sys.exit("cal: unknown time zone %r (name an IANA zone, e.g. Europe/Berlin)" % name)


def utc_start(text, tz_name):
    """A start the API accepts: UTC, seconds, `Z` — never a local wall clock."""
    cleaned = text.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(cleaned)
    except ValueError:
        sys.exit("cal: START must be 'YYYY-MM-DD HH:MM' or ISO 8601 (e.g. 2026-11-10T14:30+01:00)")
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=zone(tz_name))
    return parsed.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def local(iso, tz_name):
    """Render a server timestamp in the reader's zone instead of UTC."""
    parsed = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return parsed.astimezone(zone(tz_name)).strftime("%a %d %b %H:%M")


def event_types():
    return api("GET", "/event-types", VERSIONS["events"]).get("data", [])


def resolve_event(spec):
    """Slug or id to an event type id.

    With the key this is the account list, which is authoritative. Without it,
    the booking page's own `.md` document names the id — the same public route a
    stranger's agent would follow.
    """
    if spec.isdigit():
        return int(spec), None
    for item in event_types():
        if item.get("slug") == spec:
            return int(item["id"]), item
    url = "%s/%s.md" % (BOOKING_URL, spec)
    try:
        request = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(request, timeout=30) as response:
            document = response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        sys.exit("cal: no event type %r on %s (%s), and %s returned %s" % (spec, BOOKING_URL, "slug", url, error.code))
    except urllib.error.URLError as error:
        sys.exit("cal: cannot resolve %r: %s" % (spec, error.reason))
    match = re.search(r"Event type id:\s*(\d+)", document)
    if not match:
        sys.exit("cal: %s does not name an event type id" % url)
    return int(match.group(1)), None


def show_events(as_json):
    data = event_types()
    if as_json:
        print(json.dumps(data, indent=2))
        return
    for item in data:
        print("%-8s %-10s %3s min  %s" % (item["id"], item.get("slug", ""), item.get("lengthInMinutes", ""), item.get("title", "")))


def show_slots(spec, days, tz_name, as_json):
    event_id, _ = resolve_event(spec)
    first = date.today()
    last = first + timedelta(days=days)
    payload = api(
        "GET",
        "/slots",
        VERSIONS["slots"],
        query={
            "eventTypeId": event_id,
            "start": first.isoformat(),
            "end": last.isoformat(),
            "timeZone": tz_name,
        },
        auth=False,
    )
    slots = payload.get("data") or {}
    if as_json:
        print(json.dumps(slots, indent=2))
        return
    if not slots:
        print("no free slots for %s in the next %d day(s)" % (spec, days))
        return
    for day in sorted(slots):
        times = [item["start"][11:16] for item in slots[day]]
        print("%s  %s" % (day, " ".join(times)))


def show_list(status, limit, tz_name, as_json):
    payload = api("GET", "/bookings", VERSIONS["bookings"], query={"status": status, "limit": limit})
    data = payload.get("data") or []
    if as_json:
        print(json.dumps(data, indent=2))
        return
    if not data:
        print("no %s bookings" % status)
        return
    for booking in data:
        attendee = (booking.get("attendees") or [{}])[0]
        print(
            "%s  %-10s %-8s %s <%s>"
            % (
                local(booking["start"], tz_name),
                booking.get("uid", ""),
                booking.get("status", ""),
                attendee.get("name") or booking.get("title", ""),
                attendee.get("email", ""),
            )
        )


def plan(lines):
    for line in lines:
        print(line)


def confirm(what):
    print(
        "cal: not sent — %s writes the calendar and mails the attendee.\n"
        "     re-run with YES=1 once the plan above is what you want." % what,
        file=sys.stderr,
    )
    sys.exit(2)


def book(args):
    tz_name = args.timezone or DEFAULT_TZ
    event_id, item = resolve_event(args.event)
    body = {
        "eventTypeId": event_id,
        "start": utc_start(args.start, tz_name),
        "attendee": {
            "name": args.name,
            "email": args.email,
            "timeZone": tz_name,
            "language": "en",
        },
    }
    if args.guests:
        body["guests"] = [guest.strip() for guest in args.guests.split(",") if guest.strip()]
    plan(
        [
            "event:    %s (id %s%s)" % (args.event, event_id, "" if item is None else ", " + item.get("title", "")),
            "start:    %s %s  (%s)" % (local(body["start"], tz_name), tz_name, body["start"]),
            "attendee: %s <%s>" % (args.name, args.email),
            "guests:   %s" % (", ".join(body.get("guests", [])) or "none"),
        ]
    )
    if args.dry_run:
        print("\nbody: " + json.dumps(body, sort_keys=True))
        return
    if not args.yes:
        confirm("a booking")
    result = api("POST", "/bookings", VERSIONS["write"], body=body).get("data") or {}
    print(
        "booked %s at %s (%s)"
        % (
            result.get("uid", "?"),
            local(result["start"], tz_name) if result.get("start") else body["start"],
            result.get("status", "?"),
        )
    )
    if result.get("location"):
        print("location: %s" % result["location"])


def find(uid):
    data = api("GET", "/bookings", VERSIONS["bookings"], query={"bookingUid": uid}).get("data") or []
    return data[0] if data else None


def describe(booking, tz_name):
    attendee = (booking.get("attendees") or [{}])[0]
    return "  %s  %s  %s <%s>" % (
        booking.get("uid", "?"),
        local(booking["start"], tz_name) if booking.get("start") else "?",
        attendee.get("name") or booking.get("title", "?"),
        attendee.get("email", ""),
    )


def cancel(args):
    tz_name = args.timezone or DEFAULT_TZ
    booking = find(args.uid)
    if not booking:
        sys.exit("cal: no booking with uid %s" % args.uid)
    plan(["cancelling:" + describe(booking, tz_name), "reason:    %s" % (args.reason or "—")])
    if not args.yes:
        confirm("a cancellation")
    api("POST", "/bookings/%s/cancel" % args.uid, VERSIONS["write"], body={"cancellationReason": args.reason or "Cancelled from the fleet"})
    print("cancelled %s" % args.uid)


def reschedule(args):
    tz_name = args.timezone or DEFAULT_TZ
    booking = find(args.uid)
    if not booking:
        sys.exit("cal: no booking with uid %s" % args.uid)
    new_start = utc_start(args.start, tz_name)
    plan(
        [
            "current:" + describe(booking, tz_name),
            "new:      %s %s" % (local(new_start, tz_name), tz_name),
            "reason:   %s" % (args.reason or "—"),
        ]
    )
    if not args.yes:
        confirm("a reschedule")
    body = {"start": new_start}
    if args.reason:
        body["reschedulingReason"] = args.reason
    result = api("POST", "/bookings/%s/reschedule" % args.uid, VERSIONS["write"], body=body).get("data") or {}
    print(
        "rescheduled -> %s at %s"
        % (result.get("uid", "?"), local(result["start"], tz_name) if result.get("start") else new_start)
    )


def main():
    parser = argparse.ArgumentParser(description="Cal.com booking surface")
    sub = parser.add_subparsers(dest="verb", required=True)

    events = sub.add_parser("events", help="list event types")
    events.add_argument("--json", action="store_true")
    events.set_defaults(run=lambda a: show_events(a.json))

    slots = sub.add_parser("slots", help="free slots for one event type")
    slots.add_argument("--event", required=True)
    slots.add_argument("--days", type=int, default=5)
    slots.add_argument("--timezone")
    slots.add_argument("--json", action="store_true")
    slots.set_defaults(run=lambda a: show_slots(a.event, a.days, a.timezone or DEFAULT_TZ, a.json))

    listing = sub.add_parser("list", help="bookings, newest by status")
    listing.add_argument("--status", default="upcoming", choices=("upcoming", "unconfirmed", "recurring", "past", "cancelled"))
    listing.add_argument("--limit", type=int, default=20)
    listing.add_argument("--timezone")
    listing.add_argument("--json", action="store_true")
    listing.set_defaults(run=lambda a: show_list(a.status, a.limit, a.timezone or DEFAULT_TZ, a.json))

    create = sub.add_parser("book", help="create a booking")
    create.add_argument("--event", required=True)
    create.add_argument("--start", required=True)
    create.add_argument("--name", required=True)
    create.add_argument("--email", required=True)
    create.add_argument("--guests")
    create.add_argument("--timezone")
    create.add_argument("--yes", action="store_true")
    create.add_argument("--dry-run", action="store_true")
    create.set_defaults(run=book)

    drop = sub.add_parser("cancel", help="cancel a booking")
    drop.add_argument("--uid", required=True)
    drop.add_argument("--reason")
    drop.add_argument("--timezone")
    drop.add_argument("--yes", action="store_true")
    drop.set_defaults(run=cancel)

    move = sub.add_parser("reschedule", help="move a booking")
    move.add_argument("--uid", required=True)
    move.add_argument("--start", required=True)
    move.add_argument("--reason")
    move.add_argument("--timezone")
    move.add_argument("--yes", action="store_true")
    move.set_defaults(run=reschedule)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
