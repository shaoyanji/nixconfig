#!/usr/bin/env python3
"""The agent turn log over Gemini: one program, four modes.

Run by the wrappers the capsule installs in `cgi-bin/` — `turns` (search),
`turns-latest`, `turns-live` and `turn` (one turn by id). It reads the same shim
the fleet's agents write through, on loopback, so the capsule shows the log the
coordination contract actually holds rather than a copy of it.

Why a CGI and not a page generated at build time: turns arrive all day, and a
capsule compiled at deploy time would answer yesterday's claims.

The token is read from a file, never from the environment: molly-brown starts a
CGI with an empty environment (`dynamic.go`: `cmd.Env = []string{}`), so a
service's `EnvironmentFile` never reaches this process. The wrapper passes the
path, and the file is a sops-rendered 0440 root:gemini — not part of the capsule
store path, which is world-readable by construction.
"""

import datetime
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = os.environ.get("AGENT_TURNS_API", "http://127.0.0.1:8093/v1/events")
TOKEN_FILE = os.environ.get("AGENT_TURNS_TOKEN_FILE", "")
TIMEOUT = 8
# The shim's maxLimit: one page is all a CGI can ask for, and a filtered read
# scans 2000 frames server-side, so `repo=` still reaches an old turn.
PAGE = 200
LATEST = 30
STALE_DAYS = 7
QUERY_LIMIT = 200
TITLE = 64
ACTION = 110
FULL = "text/gemini; charset=utf-8"

# Never through an http_proxy: the shim is loopback-only, and a proxy would turn
# a local read into a remote request.
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))

# Which field a hit landed in decides its rank, exactly as `xs-turn-query.jq`
# weighs it: a subject hit says what a turn is about, a body hit may be chance.
WEIGHTS = (
    ("subject", 3),
    ("action", 2),
    ("claims", 2),
    ("files_changed", 2),
    ("outcome", 1),
    ("rationale", 1),
    ("source", 1),
    ("commits", 1),
    ("branch", 1),
)


class Archive(Exception):
    """The log could not answer. A 40, never a 51: the turn may exist."""


def status(line):
    sys.stdout.write(line + "\r\n")
    sys.stdout.flush()


def document(body):
    sys.stdout.write("20 " + FULL + "\r\n")
    sys.stdout.write(body)
    sys.stdout.flush()


def token():
    path = TOKEN_FILE
    if not path:
        return os.environ.get("AGENT_TURNS_TOKEN", "").strip()
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError as error:
        raise Archive(f"cannot read the turn token ({error.strerror})")


def fetch(limit, **filters):
    params = {"limit": limit}
    params.update({key: value for key, value in filters.items() if value})
    url = API + "?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer " + token(),
            "User-Agent": "gemini-turns/1",
        },
    )
    try:
        with OPENER.open(request, timeout=TIMEOUT) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raise Archive(f"the turn log answered {error.code}")
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        raise Archive(f"the turn log did not answer ({error})")


def flat(value, limit):
    """One line, whitespace collapsed: gemtext is line-oriented."""
    text = " ".join((value or "").split())
    return text[: limit - 1] + "…" if len(text) > limit else text


def when(stamp):
    """`2026-11-05T15:19:00+01:00` as `2026-11-05 15:19`, the one form a row
    has room for."""
    text = stamp or ""
    return text[:16].replace("T", " ") if len(text) >= 16 else "—"


def age_days(stamp):
    try:
        then = datetime.datetime.fromisoformat((stamp or "").replace("Z", "+00:00"))
    except ValueError:
        return None
    if then.tzinfo is None:
        then = then.replace(tzinfo=datetime.timezone.utc)
    delta = datetime.datetime.now(datetime.timezone.utc) - then
    return delta.total_seconds() / 86400


def link(url, label):
    return f"=> {url} {label}"


def turn_url(turn):
    key = turn.get("_frame") or turn.get("id") or ""
    return "/cgi-bin/turn?" + urllib.parse.quote(key, safe="")


def field_text(turn, field):
    value = turn.get(field)
    if isinstance(value, list):
        return " ".join(str(item) for item in value)
    return "" if value is None else str(value)


def row(turn):
    """The one-line summary every list shows. The outcome goes last because it
    is the word an agent looks for (`in_progress`, `done`, `blocked`)."""
    return " · ".join(
        [
            when(turn.get("ts")),
            flat(turn.get("source"), 24),
            flat(turn.get("subject") or "—", TITLE),
            flat(turn.get("outcome"), 26),
        ]
    )


def list_row(turn, note=""):
    lines = [link(turn_url(turn), row(turn))]
    action = flat(turn.get("action"), ACTION)
    if action:
        lines.append("   " + action + (f" ({note})" if note else ""))
    return lines


def matches(turn, words):
    haystack = " ".join(field_text(turn, field) for field, _ in WEIGHTS).lower()
    return all(word in haystack for word in words)


def weight(turn, words):
    """The heaviest field any word hit — ranking by the most specific match,
    not by how many fields a common word happened to appear in."""
    best = 0
    for field, value in WEIGHTS:
        text = field_text(turn, field).lower()
        if value > best and any(word in text for word in words):
            best = value
    return best


def search(query):
    words = [word for word in query.lower().split() if word]
    payload = fetch(PAGE)
    events = payload.get("events") or []
    hits = [turn for turn in events if matches(turn, words)]
    if not hits:
        document(
            f"# Nothing matches “{flat(query, QUERY_LIMIT)}”\n\n"
            f"No turn in the newest {len(events)} mentions all of those words.\n\n"
            "=> /cgi-bin/turns search again\n"
            "=> /cgi-bin/turns-latest the newest turns\n"
        )
        return
    # `ts` is RFC 3339 with an offset; the date prefix alone orders a fleet log
    # well enough and never raises on a stamp the shim accepted.
    hits.sort(key=lambda turn: (weight(turn, words), turn.get("ts") or ""), reverse=True)
    noun = "turn" if len(hits) == 1 else "turns"
    lines = [f"# {len(hits)} {noun} for “{flat(query, QUERY_LIMIT)}”", ""]
    for turn in hits:
        lines += list_row(turn)
    lines += [
        "",
        link("/cgi-bin/turns", "search again"),
        link("/cgi-bin/turns-latest", "newest turns"),
        link("/cgi-bin/turns-live", "what is claimed now"),
    ]
    document("\n".join(lines) + "\n")


def latest():
    payload = fetch(LATEST)
    events = payload.get("events") or []
    if not events:
        document("# The turn log is empty\n")
        return
    lines = [f"# Newest {len(events)} turns", ""]
    for turn in events:
        lines += list_row(turn)
    lines += [
        "",
        link("/cgi-bin/turns", "search the log"),
        link("/cgi-bin/turns-live", "what is claimed now"),
    ]
    document("\n".join(lines) + "\n")


def live():
    """One row per subject: the newest turn for it, when that turn is still
    `in_progress`. Stale ones are printed and marked, because an agent that died
    mid-turn must not read as a claim someone is holding."""
    payload = fetch(PAGE)
    events = payload.get("events") or []
    newest = {}
    for turn in events:
        subject = turn.get("subject") or ""
        if subject and subject not in newest:
            newest[subject] = turn
    claims = [turn for turn in newest.values() if turn.get("outcome") == "in_progress"]
    if not claims:
        document(
            "# Nothing is claimed right now\n\n"
            f"The newest {len(events)} turns leave no subject `in_progress`.\n\n"
            "=> /cgi-bin/turns-latest the newest turns\n"
        )
        return
    lines = [f"# {len(claims)} open claim{'s' if len(claims) != 1 else ''}", ""]
    for turn in claims:
        days = age_days(turn.get("ts"))
        note = ""
        if days is not None and days > STALE_DAYS:
            note = f"stale: {int(days)} days old"
        lines += list_row(turn, note)
    lines += [
        "",
        "A claim is the newest turn on a subject with outcome `in_progress`. "
        f"Past {STALE_DAYS} days it is printed as stale: the agent may be gone, and "
        "the gate does not fail on it.",
        "",
        link("/cgi-bin/turns", "search the log"),
        link("/cgi-bin/turns-latest", "newest turns"),
    ]
    document("\n".join(lines) + "\n")


def read(key):
    payload = fetch(PAGE)
    events = payload.get("events") or []
    wanted = key.lower()
    hits = [
        turn
        for turn in events
        if wanted in str(turn.get("id") or "").lower() or wanted in str(turn.get("_frame") or "").lower()
    ]
    if not hits:
        status("51 no turn with that id in the newest page")
        return
    turn = hits[0]
    lines = [
        f"# {flat(turn.get('subject') or '(no subject)', 200)}",
        "",
        " · ".join(
            [
                when(turn.get("ts")),
                flat(turn.get("source"), 40),
                flat(turn.get("outcome"), 60),
            ]
        ),
        "",
        f"id: {turn.get('_frame') or turn.get('id')}",
    ]
    if turn.get("branch"):
        lines.append(f"branch: {flat(turn.get('branch'), 120)}")
    if turn.get("base_commit"):
        lines.append(f"base: {flat(turn.get('base_commit'), 60)}")
    action = flat(turn.get("action"), 400)
    if action:
        lines += ["", action]
    rationale = flat(turn.get("rationale"), 4000)
    if rationale:
        lines += ["", "```text", rationale, "```"]
    claims = turn.get("claims") or []
    if claims:
        lines += ["", "## Claims"] + [f"* {flat(item, 200)}" for item in claims]
    files = turn.get("files_changed") or []
    if files:
        shown = files[:25]
        lines += ["", f"## Files ({len(files)})"] + [f"* {flat(item, 200)}" for item in shown]
        if len(files) > len(shown):
            lines.append(f"* (+{len(files) - len(shown)} more — see `agents:xs:list ID=…`)")
    commits = turn.get("commits") or []
    if commits:
        lines += ["", "## Commits"] + [f"* {flat(item, 60)}" for item in commits]
    lines += [
        "",
        link("/cgi-bin/turns", "search the log"),
        link("/cgi-bin/turns-latest", "newest turns"),
        link("/cgi-bin/turns-live", "what is claimed now"),
    ]
    document("\n".join(lines) + "\n")


def main(argv):
    mode = argv[1] if len(argv) > 1 else "search"
    # The CGI contract hands the query over still percent-encoded. `+` is left
    # alone on purpose: a search for C++ is not a search for C.
    query = urllib.parse.unquote(os.environ.get("QUERY_STRING", "")).strip()[:QUERY_LIMIT]
    try:
        if mode == "search":
            if not query:
                status('10 Search the turn log — words, e.g. gemini capsule')
                return 0
            search(query)
        elif mode == "latest":
            latest()
        elif mode == "live":
            live()
        elif mode == "read":
            if not query:
                status("10 turn id (frame id or client UUID, a prefix is enough)")
                return 0
            read(query)
        else:
            status("40 unknown mode")
            return 0
    except Archive as error:
        status("40 " + flat(str(error), 120))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
