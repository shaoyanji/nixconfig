---
name: calendar
description: "Google Calendar sync via vdirsyncer OAuth2, khal CLI/TUI management, and automated dms notifications."
version: 0.1.0
platforms: [linux]
tags: [calendar, khal, vdirsyncer, libnotify, dms]
---

# calendar — Google Calendar, Khal & DMS Notifications

Declarative terminal calendar synchronization and desktop notification pipeline across NixOS workstations and servers.

## Architecture

```
Google CalDAV (OAuth2)
       │
       ▼ (caldav.googleapis.com)
  vdirsyncer (token in ~/.config/vdirsyncer/google_token)
       │
       ▼ (writes .ics files to ~/.local/share/calendars/google/)
     khal (CLI / TUI calendar)
       │
       ▼ (polls 'khal list now 15m' every 5 min)
calendar-notify (oneshot systemd user service)
       │
       ▼ (libnotify / notify-send)
  Dank Material Shell (DMS notification center on Niri)
```

## Declarative Configuration

- **Module**: `modules/calendar.nix` (imported by `modules/env.nix`).
- **Storage**: `~/.local/share/calendars/google/`
- **OAuth Credentials**: Extracted from `~/.config/rclone/rclone.conf` dynamically by hermetic nix derivation scripts (`google-client-id`, `google-client-secret`).
- **Token Cache**: `~/.config/vdirsyncer/google_token`
- **Default Calendar**: `Primary` (mapped to `jisifu@gmail.com`)

## Operational Cheatsheet

### 1. View & Manage Events

```bash
# Interactive TUI browser (vim keybindings, event editor)
ikhal

# Fast agenda view of today's schedule
khal agenda

# Upcoming events for the next 7 or 30 days
khal list today 7d
khal list today 30d

# Create a new event on Primary calendar
khal new 2026-10-20 14:00 15:00 "Team Meeting" :: Discuss project roadmap
```

### 2. Manual & Periodic Synchronization

The systemd user timer `vdirsyncer.timer` runs every 15 minutes. To trigger immediate synchronization:

```bash
vdirsyncer sync
```

### 3. Desktop Notification Daemon & Simulation

The systemd user timer `calendar-notify.timer` checks for upcoming events every 5 minutes and pushes alerts to DMS.

```bash
# Check timer and service status
systemctl --user status calendar-notify.timer
systemctl --user status calendar-notify.service

# Trigger a one-shot check immediately
systemctl --user start calendar-notify.service

# Directly simulate a notification to verify DMS toast rendering
notify-send \
  --app-name="Calendar" \
  --urgency=normal \
  --icon="calendar-symbolic" \
  --category="appointment" \
  "Calendar Test" \
  "Meeting starts at 17:30 (Simulated)"
```

## First-Time Setup on New Hosts

1. Rebuild and activate configuration:
   ```bash
   sudo nixos-rebuild switch --flake .?submodules=1#<host>
   ```
2. If `~/.config/vdirsyncer/google_token` is missing or expired, run discovery:
   ```bash
   vdirsyncer discover
   ```
   Open the printed Google OAuth authorization link in Zen/browser, approve access, and accept creating the local collections.
3. Perform initial collection sync:
   ```bash
   vdirsyncer sync
   ```
4. Verify khal index:
   ```bash
   khal list today 7d
   ```

## Troubleshooting

- **403 accessNotConfigured**: The Google Cloud project must have the `CalDAV API` (`caldav.googleapis.com`) enabled in Google Cloud Console.
- **Connection refused on localhost during OAuth**: Ensure `vdirsyncer discover` remains running in the background while approving the authorization link in the browser.
- **Headless host notifications**: `calendar-notify` checks `$WAYLAND_DISPLAY` and `$DISPLAY`; if neither is set, it exits cleanly (status 0) without spamming logs.
