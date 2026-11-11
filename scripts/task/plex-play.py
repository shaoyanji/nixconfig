#!/usr/bin/env python3
"""Play a Plex library item on the living-room set through Companion control.

The set's Plex app is a controllable client: it lists itself under the server's
/clients once open and signed in, and then /player/playback/playMedia tells it what
to play. Verification is the server's own /status/sessions, which the client keeps
up to date — an HTTP 200 from playMedia proves nothing on its own.

The token is read from Preferences.xml (PlexOnlineToken), never stored twice.
Detail and traps: `.agents/skills/philips-tv-cast`.
"""

import argparse
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

PREFS = "/srv/private/plex/Plex Media Server/Preferences.xml"


def token():
    try:
        with open(PREFS, errors="replace") as f:
            found = re.search(r'PlexOnlineToken="([^"]+)"', f.read())
    except OSError as exc:
        sys.exit(f"plex-play: cannot read {PREFS}: {exc}")
    if not found:
        sys.exit("plex-play: no PlexOnlineToken in Preferences.xml — the server is unclaimed")
    return found.group(1)


def fetch(url, timeout=10):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.status, response.read()


def xml_of(url, timeout=10):
    status, body = fetch(url, timeout)
    if status != 200:
        sys.exit(f"plex-play: {url.split('?')[0]} returned {status}")
    return ET.fromstring(body)


def clients(base, tok):
    root = xml_of(f"{base}/clients?X-Plex-Token={tok}")
    return [dict(el.attrib) for el in root]


def find_movie(base, tok, needle):
    """ratingKey of the first movie whose title contains needle."""
    search = xml_of(f"{base}/search?query={urllib.parse.quote(needle)}&X-Plex-Token={tok}")
    for el in search.iter("Video"):
        if el.get("type") == "movie" and needle.lower() in (el.get("title") or "").lower():
            return el.get("ratingKey"), el.get("title")
    for section in xml_of(f"{base}/library/sections?X-Plex-Token={tok}").findall("Directory"):
        if section.get("type") != "movie":
            continue
        listing = xml_of(f"{base}/library/sections/{section.get('key')}/all?X-Plex-Token={tok}")
        for video in listing.findall("Video"):
            if needle.lower() in (video.get("title") or "").lower():
                return video.get("ratingKey"), video.get("title")
    return None, None


def play(base, tok, client, rating_key, offset_ms=0):
    params = {
        "key": f"/library/metadata/{rating_key}",
        "machineIdentifier": xml_of(f"{base}/identity").get("machineIdentifier"),
        "address": client.get("address", ""),
        "port": client.get("port", "32500"),
        "protocol": client.get("protocol", "plex"),
        "commandID": "1",
        "offset": str(offset_ms),
        "X-Plex-Target-Client-Identifier": client.get("machineIdentifier", ""),
        "X-Plex-Token": tok,
    }
    url = f"{base}/player/playback/playMedia?{urllib.parse.urlencode(params)}"
    try:
        return fetch(url, timeout=15)[0]
    except Exception as exc:  # noqa: BLE001 - reported, not raised
        return f"ERR {exc}"


def wait_playing(base, tok, rating_key, seconds):
    """The client reports to the server, so a session with a moving offset is the proof."""
    deadline = time.time() + seconds
    state, prev = "no session", None
    while time.time() < deadline:
        try:
            root = xml_of(f"{base}/status/sessions?X-Plex-Token={tok}")
        except SystemExit:
            time.sleep(4)
            continue
        for video in root.findall("Video"):
            if video.get("ratingKey") != rating_key:
                continue
            player = video.find("Player")
            session = video.find("Session")
            state = player.get("state") if player is not None else "?"
            offset = session.get("viewOffset") if session is not None else None
            if offset and prev is not None and int(offset) > int(prev):
                return True, state, int(offset)
            prev = offset or prev
        time.sleep(4)
    return False, state, prev


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--search", help="movie title substring")
    ap.add_argument("--list-clients", action="store_true")
    ap.add_argument("--tv", help="client name/host substring; default is the only client")
    ap.add_argument("--wait", type=int, default=45)
    ap.add_argument("--base", default="http://127.0.0.1:32400")
    args = ap.parse_args()
    base, tok = args.base, token()

    found = clients(base, tok)
    if args.list_clients or not found:
        print(f"clients: {len(found)}")
        for c in found:
            print(f"  name={c.get('name')} product={c.get('product')} host={c.get('host')} "
                  f"address={c.get('address')} port={c.get('port')} id={c.get('machineIdentifier')}")
        if not found:
            sys.exit("plex-play: no controllable client — open the Plex app on the set and sign in")
        return 0 if args.list_clients else 0

    if args.tv:
        picked = [c for c in found
                  if args.tv.lower() in ((c.get("name") or "") + (c.get("host") or "")).lower()]
    else:
        picked = found
    if not picked:
        sys.exit(f"plex-play: no client matches {args.tv!r}; found {[c.get('name') for c in found]}")
    client = picked[0]

    if not args.search:
        ap.error("give --search <title>")

    key, title = find_movie(base, tok, args.search)
    if not key:
        sys.exit(f"plex-play: no movie matches {args.search!r}")
    print(f"playing {title} (ratingKey={key}) on {client.get('name')}")
    print(f"playMedia: http={play(base, tok, client, key)}")

    ok, state, offset = wait_playing(base, tok, key, args.wait)
    if ok:
        print(f"PLAYING  state={state} offset={offset/1000:.1f}s")
        return 0
    print(f"plex-play: the client did not report playback (state={state} offset={offset})",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
