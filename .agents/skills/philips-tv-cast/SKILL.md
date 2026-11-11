---
name: philips-tv-cast
description: "Play a film from the NAS, or a YouTube video, on the living-room Philips 65OLED759 — UPnP AVTransport on 49152 for library files, YouTube Lounge for video, and the traps that make both look broken."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['tv', 'philips', 'upnp', 'dlna', 'jellyfin', 'cast', 'nas']
    related_skills: ['paste', 'infra']
---

# `philips-tv-cast` — the living-room set

The living-room display is a Philips **65OLED759/12** at `192.168.3.26` (Titan OS,
`titanos.local`). It has no Cast receiver, no DIAL, nothing on 8008/8009 — and it
answers **no SSDP at all**, which is why every discovery tool reports "no renderer".
It is one: a UPnP `MediaRenderer:1` (DMR-1.50) whose description is only reachable by
a direct GET on port 49152. Verified 2026-11-11 by playing *In the Mood for Love*
from the NAS end to end.

| Want | Path |
| :--- | :--- |
| a film or episode from the NAS | Jellyfin DLNA `<res>` URL → SOAP AVTransport on `:49152` |
| a YouTube video | `task ytcast url=<link>` (YouTube Lounge, VOD only; no `url=` opens a gum picker) |

## Play something from the NAS

```bash
task media:play Q=mood      # title substring, case-insensitive, browses the DLNA tree
task media:tv               # transport state right now
task media:stop
```

Under it is `scripts/task/play-on-tv.py`, which does three things:

1. Finds the DLNA uuid by M-SEARCH for the Jellyfin `MediaServer` and reading
   `/dlna/<uuid>/` out of its `LOCATION`, falling back to the server `Id` from
   `GET /System/Info/Public`: `…/dlna/<uuid>/contentdirectory/control`.
2. `Browse` that ContentDirectory breadth-first (4 levels), matching the title. The
   `arr` container is the Jellyfin/Plex-indexed video tree (`/srv/data/arr`); siblings
   are `Music`, `Pictures`, `YouTube`, `Playlists`, per-household folders.
3. `SetAVTransportURI` + `Play` on `http://192.168.3.26:49152/avt_control` with a
   DIDL-Lite `object.item.videoItem.movie` wrapper, then polls
   `GetTransportInfo`/`GetPositionInfo` until `PLAYING` and `RelTime` advances. One attempt
   only: `--transcode` adds `Static=false` (then `.mkv` → `.mp4`) retries, and those are
   opt-in because a second `Play` while the first is still `TRANSITIONING` wedges the player.

Exit 0 means the set really is playing: `PLAYING  rel=0:00:04 dur=1:38:40`.

## Traps

- **Do not trust "no renderer".** `M-SEARCH` to the set returns nothing; a direct GET of
  `http://192.168.3.26:49152/description.xml` returns the full device and its services
  (`AVTransport` `/avt_control`, `RenderingControl` `/rcr_control`, `ConnectionManager`
  `/cmr_control`). Scan the port, not the discovery.
- **Do not serve the file yourself.** A `python3 -m http.server` on frieren:8899 is
  dropped by the host firewall: the set goes `TRANSITIONING → STOPPED` and the server
  log shows only `127.0.0.1`. 8096 is already open, so let Jellyfin serve it.
- **`stream.mkv?...&amp;…` needs unescaping** to `&` before it goes into `CurrentURI`.
- **`Static=true` is direct play.** Fine for h264/aac MKV on this set; an exotic
  container/codec would need a transcode profile instead.
- **jointSPACE writes are closed.** `/6/input/key`, `/6/powerstate`, `/6/pair/request`
  return 403 and `/6/system` is readable, so no remote key press over HTTP: recovery
  from a stuck app needs the physical remote.
- **YouTube is VOD only.** A live stream wedges the set's YouTube app into ambient mode
  and nothing on the network recovers it. `task ytcast` refuses anything that is not
  `not_live`/`was_live` — and `ytcast` exit 0 only means Google accepted the cast, not
  that the set played it.
- **A cast is queued, not raised.** `ytcast` returned 0 on 2026-11-11 while the set was
  showing Bloomberg TV and nothing changed on screen; the video played the instant the
  YouTube app was opened by hand. Nothing on the network opens that app — it is the one
  step that needs the remote, and `rc=0` proves only that the queue entry exists.
- **Never re-send while the set is `TRANSITIONING`.** On 2026-11-11 three attempts in a
  row (direct, then two transcodes) left the player on a black loading wheel with the
  previous channel's audio behind it, and every later `SetAVTransportURI` — including one
  for a file that had played fine an hour before — stayed `TRANSITIONING`. `Stop` and an
  empty `CurrentURI` report `STOPPED`/`NO_MEDIA_PRESENT` but do not clear the overlay, and
  there is no key API to clear it. `task media:stop` (`Stop`) did return the transport to
  `STOPPED`, and the next single attempt played, so Stop first and only power-cycle a
  transport that stays stuck; the on-screen overlay clears with Back on the remote. The
  script refuses to send while `TRANSITIONING` for exactly this reason.
- **Container decides direct play.** `/arr/In the Mood for Love` resolves to `stream.mkv`
  and plays. `/arr/Gravity` is an h264/aac mp4 that Jellyfin's DLNA layer advertises as
  `video/quicktime` with a `.mov` path, and the set refuses it — the extension, not the
  codec, is the tell. The script direct-plays only `mkv`/`mp4`/`m4v` and otherwise asks for
  the `.mp4` variant with `Static=false`, declaring `video/mp4` in the DIDL. That transcode
  reports a bogus `TrackDuration` (10 s) while `RelTime` climbs past it: not a truncation.
  Do not read Jellyfin's journal for fetch evidence — it logs no access, so a count of 0
  says nothing about whether the set pulled the file.
- **The `YouTube` container is not a film library.** `/YouTube/Nix in 100 Seconds` was
  accepted and sat in `TRANSITIONING` until the wait expired, on direct play and on the
  transcode retry; `/arr` is what this set plays. A stuck `TRANSITIONING` means the item's
  stream is not for this renderer, not that the network failed.
- **Stopping the renderer restores the previous input.** Ending the DLNA stream handed the
  set straight back to Bloomberg TV, so `media:stop` doubles as "put my channel back".

## Plex: the better path, not wired yet

frieren runs Plex Media Server 1.43.4 on 32400 with a `Movies` library, and the set has a
native Plex app — but playback cannot be driven from here yet, for three concrete reasons:

- the server is **unclaimed** (`curl :32400/identity` → `claimed="0"`), so there is no
  plex.tv token, and `{{.SECRETS}}` holds no Plex key;
- `:32400/clients` returns `size="0"` — Companion control needs the app listed there, and
  it only registers while it is open and signed in;
- the TV's app listens on nothing when closed (`32500`, `3005`, `8324` all refused), so
  there is no client to address.

To wire it — claiming needs **no Plex Pass**, an account is free and so is the claim:

1. `https://www.plex.tv/claim` while signed in returns a `claim-…` token valid about four
   minutes;
2. from frieren: `curl -X POST 'http://127.0.0.1:32400/myplex/claim?token=claim-…'`, or open
   `http://192.168.3.25:32400/web` from the LAN and sign in there;
3. `curl :32400/identity` then reads `claimed="1"` and `PlexOnlineToken` lands in
   `Preferences.xml` — that file is the proof, not the web page;
4. reopen the Plex app on the set, signed in to the same account, and `/clients` grows by
   one; then `playMedia` against `/clients/<id>` with that token.

The claim token is a credential: keep it on the command line, never in a note, a commit or
the journal. Until all four steps exist, the DLNA path above is the one that works, paying a
transcode for `.mov` sources.

## If nothing plays

```bash
curl -s http://192.168.3.26:49152/description.xml | head -40   # renderer present?
curl -s  http://192.168.3.25:8096/System/Info/Public          # Jellyfin up + Id
task media:tv                                                  # STOPPED vs PLAYING
```

`STOPPED` with a `TrackURI` set means the set accepted the URI and could not fetch it:
check that the URL loads from another LAN host before blaming the renderer.
