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
| Notify timer | `calendar-notify.timer`, `OnCalendar = "*:0/5"`, oneshot — exists only on a generation that declares a compositor |

## What decides whether it runs (no host lists)

Two declarative gates, both owned by the config rather than by a hostname:

- **Sync** — `vdirsyncer.service` carries
  `ConditionPathExists=%h/.config/rclone/rclone.conf`, the file its
  `google-client-id`/`-secret` scripts read. Where the file is absent the service
  is skipped (not failed), so a host without Google credentials has no red unit,
  and a host that gains the file starts syncing with no config change.
- **Notify** — `calendar-notify.{service,timer}` are `mkIf`
  `osConfig.programs.niri.enable`: the profile that installs the compositor
  (`modules/profiles/base-desktop-environment.nix`) sets it, so a headless
  generation (frieren's boot default) has no such unit at all, while its `desktop`
  specialisation and every desktop host do. The unit also carries the same
  `rclone.conf` condition, because khal only has data after a sync.

The compositor side of that contract lives in `modules/user/desktop/niri.nix`:
niri's `spawn-at-startup` runs `systemctl --user import-environment WAYLAND_DISPLAY`
and starts `graphical-session.target`, which is what pulls in every
`WantedBy=graphical-session.target` session unit.

## Operational

```bash
vdirsyncer sync                     # immediate sync, no waiting for the timer
systemctl --user start calendar-notify.service   # one-shot probe of the next 15 min
systemctl --user status calendar-notify.timer
khal list today 7d                  # agenda; `ikhal` is the TUI
khal new 2026-10-20 14:00 15:00 "Team Meeting" :: Discuss project roadmap
```

The notifier deduplicates through `$XDG_RUNTIME_DIR/calendar-notified.cache`, so a
re-run inside the same event does not repeat the toast. An event is written to
that cache **only when `notify-send` succeeded** — a failed send (no session bus,
no notification daemon) is retried on the next tick instead of being swallowed for
the rest of the day. There is no display test in the script: the unit's existence
is the test.

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
