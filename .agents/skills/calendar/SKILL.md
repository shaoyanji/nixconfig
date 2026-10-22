---
name: calendar
description: "Google Calendar sync via vdirsyncer OAuth2, khal CLI/TUI management, and automated dms notifications."
version: 0.1.0
platforms: [linux]
tags: [calendar, khal, vdirsyncer, libnotify, dms]
---

# calendar — Google → vdirsyncer → khal → notification

Declared in `modules/calendar.nix`, imported by `modules/env.nix`. Google CalDAV
(`caldav.googleapis.com`) → `vdirsyncer` writes `.ics` into
`~/.local/share/calendars/google/` → `khal` reads them → `calendar-notify` polls
`khal list now 15m` and raises a libnotify toast, which DMS shows in its
notification center.

| | |
| :--- | :--- |
| Token cache | `~/.config/vdirsyncer/google_token` |
| Client id / secret | extracted from `~/.config/rclone/rclone.conf` by the `google-client-id`/`-secret` scripts, so the credentials live in one file |
| Default calendar | `Primary` |
| Sync timer | `vdirsyncer.timer`, `frequency = "*:0/15"` |
| Notify timer | `calendar-notify.timer`, `OnCalendar = "*:0/5"`, oneshot |

## Hosts without the rclone credentials do not sync

`syncEnabled` is false on hosts in the module's `hostName` list (today: `delphi`),
because `vdirsyncer` there fails every 15 minutes with `NoSectionError: No section:
'gdrive'` — a permanently red user unit on a box with no Google credentials. The
list is in the module, not an option block; add a host there, not an override.

Adding a host that *should* sync needs `~/.config/rclone/rclone.conf` to exist
first, or the same error appears under its own name.

## Operational

```bash
vdirsyncer sync                     # immediate sync, no waiting for the timer
systemctl --user start calendar-notify.service   # one-shot probe of the next 15 min
systemctl --user status calendar-notify.timer
khal list today 7d                  # agenda; `ikhal` is the TUI
khal new 2026-10-20 14:00 15:00 "Team Meeting" :: Discuss project roadmap
```

The notifier only fires when `$WAYLAND_DISPLAY` or `$DISPLAY` is set, and it
deduplicates through `$XDG_RUNTIME_DIR/calendar-notified.cache`, so a re-run
inside the same event does not repeat the toast. Both are deliberate: a headless
host exits 0 instead of logging a failure every five minutes.

To prove DMS rendering, bypass the notifier:

```bash
notify-send --app-name="Calendar" --urgency=normal \
  --icon="calendar-symbolic" --category="appointment" \
  "Calendar Test" "Meeting starts at 17:30 (Simulated)"
```

## First sync on a host

`vdirsyncer discover` must keep running while you open its printed OAuth link and
approve — closing it makes the callback hit a refused localhost port. Then
`vdirsyncer sync` and `khal list today 7d`.

## Troubleshooting

- **403 accessNotConfigured** — the Google Cloud project lacks the CalDAV API
  (`caldav.googleapis.com`); the OAuth grant is fine, the API is not enabled.
- **Nothing appears after a sync** — check `khal list` sees the collection before
  blaming the timer: `vdirsyncer` writes files whether or not khal indexed them.
- **Expired token** — delete `google_token` and re-run `vdirsyncer discover`; the
  client id is re-derived from rclone at build time, so nothing else to edit.

Truth: `modules/calendar.nix` — the option surface; this page is the procedure.
