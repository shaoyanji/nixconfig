#!/usr/bin/env python3
"""Play a Jellyfin library item on the living-room Philips over UPnP AVTransport.

The set is a MediaRenderer that answers nothing on SSDP, so discovery tools
never see it: the device description is only reachable by a direct GET on port
49152. Jellyfin's DLNA ContentDirectory (8096, a port the host firewall already
allows) hands out a tokenless <res> URL, and the set fetches that itself.

Verified 2026-11-11 on the 65OLED759/12: transport reaches PLAYING with a real
TrackDuration. Detail and the traps: `.agents/skills/philips-tv-cast`.
"""

import argparse
import html
import json
import re
import socket
import sys
import time
import urllib.request
import xml.sax.saxutils as sx

SERVICES = {"AVTransport": "avt", "ContentDirectory": "cd", "RenderingControl": "rcr"}


def soap(url, service, action, inner, timeout=10):
    body = (
        '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'
        f'<u:{action} xmlns:u="urn:schemas-upnp-org:service:{service}:1">{inner}</u:{action}>'
        "</s:Body></s:Envelope>"
    )
    req = urllib.request.Request(
        url,
        data=body.encode(),
        headers={
            "Content-Type": 'text/xml; charset="utf-8"',
            "SOAPACTION": f'"urn:schemas-upnp-org:service:{service}:1#{action}"',
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            return f.read().decode(errors="replace")
    except Exception as exc:  # noqa: BLE001 - the caller prints it
        return f"ERR {exc}"


def tag(xml, name):
    m = re.search(rf"<{name}>([^<]*)</{name}>", xml or "")
    return m.group(1) if m else None


def jellyfin_dlna_uuid(base):
    """The DLNA server uuid is the Jellyfin server id without dashes."""
    with urllib.request.urlopen(f"{base}/System/Info/Public", timeout=8) as f:
        info = json.loads(f.read().decode(errors="replace"))
    ident = str(info.get("Id") or "").replace("-", "")
    if not ident:
        sys.exit("play-on-tv: Jellyfin did not report a server id")
    return ident


def discover_dlna_uuid(base, timeout=3.0):
    """Read the DLNA uuid from the MediaServer's SSDP LOCATION.

    Nothing guarantees the DLNA uuid equals the Jellyfin server id, so ask the
    network first and keep the id as a fallback.
    """
    host = base.split("//", 1)[-1].split("/")[0].split(":")[0]
    msg = (
        "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n"
        'MAN: "ssdp:discover"\r\nMX: 2\r\n'
        "ST: urn:schemas-upnp-org:device:MediaServer:1\r\n\r\n"
    )
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(msg.encode(), ("239.255.255.250", 1900))
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                data, _ = sock.recvfrom(4096)
            except socket.timeout:
                break
            location = re.search(r"(?im)^LOCATION:\s*(\S+)", data.decode(errors="replace"))
            if not location or host not in location.group(1):
                continue
            found = re.search(r"/dlna/([0-9a-f]{32})/", location.group(1))
            if found:
                return found.group(1)
    finally:
        sock.close()
    return None


def browse(control, object_id, count=200):
    inner = (
        f"<ObjectID>{object_id}</ObjectID><BrowseFlag>BrowseDirectChildren</BrowseFlag>"
        f"<Filter>*</Filter><StartingIndex>0</StartingIndex>"
        f"<RequestedCount>{count}</RequestedCount><SortCriteria></SortCriteria>"
    )
    xml = soap(control, "ContentDirectory", "Browse", inner)
    if xml.startswith("ERR"):
        sys.exit(f"play-on-tv: browse failed: {xml}")
    result = re.search(r"<Result>(.*?)</Result>", xml, re.S)
    return html.unescape(result.group(1)) if result else ""


def containers(didl):
    out = []
    for m in re.finditer(r"<container\b([^>]*)>(.*?)</container>", didl, re.S):
        cid = re.search(r'id="([^"]*)"', m.group(1))
        title = re.search(r"<dc:title>([^<]*)<", m.group(2))
        out.append((cid.group(1) if cid else "?", title.group(1) if title else "?"))
    return out


def items(didl):
    out = []
    for m in re.finditer(r"<item\b(.*?)</item>", didl, re.S):
        body = m.group(1)
        title = re.search(r"<dc:title>([^<]*)<", body)
        res = re.search(r'<res[^>]*protocolInfo="[^"]*"[^>]*>([^<]*)<', body)
        out.append(
            (
                title.group(1) if title else "?",
                html.unescape(res.group(1)) if res else "",
            )
        )
    return out


def find_item(control, needle, max_depth=4):
    needle = needle.lower()
    queue, seen, depth = [("0", "")], set(), 0
    while queue and depth < max_depth:
        nxt = []
        for oid, path in queue:
            if oid in seen:
                continue
            seen.add(oid)
            didl = browse(control, oid)
            for cid, title in containers(didl):
                nxt.append((cid, f"{path}/{title}"))
            for title, url in items(didl):
                if needle in title.lower() and url:
                    return title, f"{path}/{title}", url
        queue, depth = nxt, depth + 1
    return None


def transport(ctrl):
    info = soap(ctrl, "AVTransport", "GetTransportInfo", "<InstanceID>0</InstanceID>")
    pos = soap(ctrl, "AVTransport", "GetPositionInfo", "<InstanceID>0</InstanceID>")
    return tag(info, "CurrentTransportState"), tag(pos, "RelTime"), tag(pos, "TrackDuration")


def wait_playing(ctrl, seconds):
    deadline = time.time() + seconds
    prev, state, rel, dur = None, None, None, None
    while time.time() < deadline:
        state, rel, dur = transport(ctrl)
        if state == "PLAYING" and rel and rel != "0:00:00":
            if prev is not None and rel != prev:
                return True, state, rel, dur
            prev = rel
        elif state == "STOPPED" and prev is not None:
            return False, state, rel, dur
        time.sleep(4)
    return False, state, rel, dur


def play(ctrl, url, title):
    didl = (
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        f'<item id="1" parentID="0" restricted="1"><dc:title>{sx.escape(title)}</dc:title>'
        '<upnp:class>object.item.videoItem.movie</upnp:class>'
        f'<res protocolInfo="http-get:*:*:*">{sx.escape(url)}</res></item></DIDL-Lite>'
    )
    soap(
        ctrl,
        "AVTransport",
        "SetAVTransportURI",
        "<InstanceID>0</InstanceID>"
        f"<CurrentURI>{sx.escape(url)}</CurrentURI>"
        f"<CurrentURIMetaData>{sx.escape(didl)}</CurrentURIMetaData>",
    )
    soap(ctrl, "AVTransport", "Play", "<InstanceID>0</InstanceID><Speed>1</Speed>")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--search", help="title substring to play")
    ap.add_argument("--list", action="store_true", help="list the library instead of playing")
    ap.add_argument("--stop", action="store_true", help="stop playback")
    ap.add_argument("--tv", default="192.168.3.26")
    ap.add_argument("--tv-port", default="49152")
    ap.add_argument("--jellyfin", default="http://192.168.3.25:8096")
    ap.add_argument("--wait", type=int, default=30, help="seconds to wait for PLAYING")
    ap.add_argument("--force", action="store_true", help="play over whatever is running now")
    ap.add_argument(
        "--transcode",
        action="store_true",
        help="retry with Static=false (then mp4) when direct play stalls; three fast attempts "
        "leave the set's player stuck in TRANSITIONING, so this is opt-in",
    )
    args = ap.parse_args()

    ctrl = f"http://{args.tv}:{args.tv_port}/avt_control"

    if args.stop:
        soap(ctrl, "AVTransport", "Stop", "<InstanceID>0</InstanceID>")
        state, rel, _ = transport(ctrl)
        print(f"stopped (state={state} rel={rel})")
        return 0

    if not (args.search or args.list):
        ap.error("give --search <title substring> or --list")

    if not args.list:
        state, _, _ = transport(ctrl)
        if state == "TRANSITIONING":
            sys.exit(
                "play-on-tv: the transport is stuck in TRANSITIONING and another set-uri makes it "
                "worse — run task media:stop first (Stop released it on 2026-11-11); power-cycle "
                "the set only if it stays stuck after that"
            )
        if state == "PLAYING" and not args.force:
            sys.exit("play-on-tv: something is already playing — task media:stop first, or pass --force")

    base = args.jellyfin.rstrip("/")
    uuid = discover_dlna_uuid(base) or jellyfin_dlna_uuid(base)
    control = (
        f"{args.jellyfin.rstrip('/')}/dlna/{uuid}/contentdirectory/control"
    )

    if args.list:
        didl = browse(control, "0")
        for _, title in containers(didl):
            print(title)
        return 0

    hit = find_item(control, args.search)
    if not hit:
        print(f"play-on-tv: no library item matches {args.search!r}", file=sys.stderr)
        return 1
    title, path, url = hit
    print(f"playing {path}")

    attempts = [(url, "direct play")]
    if args.transcode and "Static=true" in url:
        attempts.append((url.replace("Static=true", "Static=false"), "transcode, same container"))
        mp4 = re.sub(r"\.(mkv|mov|avi|webm|ts)(\?)", r".mp4\2", url)
        if mp4 != url:
            attempts.append((mp4.replace("Static=true", "Static=false"), "transcode to mp4"))

    for candidate, label in attempts:
        print(f"  attempt: {label}")
        play(ctrl, candidate, title)
        ok, state, rel, dur = wait_playing(ctrl, args.wait)
        if ok:
            print(f"PLAYING  rel={rel} dur={dur}  ({label})")
            return 0
        print(f"  not playing: state={state} rel={rel}", file=sys.stderr)

    print("play-on-tv: the set refused every variant of this file", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
