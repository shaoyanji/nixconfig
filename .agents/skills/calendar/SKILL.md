---
name: calendar
description: "Google → vdirsyncer → khal → notification. scripts/calendar-auth.sh runs the one-time OAuth consent (ssh -L, not a funnel) and a verify that reports what khal really sees; covers the token gate and DMS toasts."
version: 0.2.0
platforms: [linux]
metadata:
  hermes:
    tags: [calendar, khal, vdirsyncer, oauth2, libnotify, dms, calcom]
    related_skills: [google-drive, infra]
---

# calendar — Google → vdirsyncer → khal → notification

Declared in `modules/calendar.nix`, imported by `modules/env.nix`. Google CalDAV
(`caldav.googleapis.com`) → `vdirsyncer` writes `.ics` into
`~/.local/share/calendars/google/` → `khal` reads them → `calendar-notify` polls
`khal list now 15m` and raises a libnotify toast, which DMS shows in its
notification center. A second account, `personal`, has the same shape against
the self-hosted Radicale on delphi — see § Radicale below.

| | |
| :--- | :--- |
| Token cache | `~/.config/vdirsyncer/google_token` |
| Client id / secret | sops plane: `googleDrive.clientId` / `.clientSecret`, declared as `sops.secrets.gdrive_client_{id,secret}` — vdirsyncer's `clientIdCommand`/`clientSecretCommand` are `cat` of the rendered secret |
| Default calendar | `Primary` |
| Sync timer | `vdirsyncer.timer`, `frequency = "*:0/15"` |
| Notify timer | `calendar-notify.timer`, `OnCalendar = "*:0/5"`, oneshot — exists only on a generation that declares a compositor |

## The self-hosted calendar (Radicale on delphi)

Built 2026-11-06 with ntfy and Vikunja, and unused until the collection was
seeded: the server answered 302, held zero calendars, and no client pointed at
it. `accounts.calendar.accounts.radicale` is the client half — named for the
server, because an account and its only collection both called `personal`
collide in khal and the calendar surfaces as `personal1`.

| | |
| :--- | :--- |
| URL | `https://delphi.cloudforest-kardashev.ts.net:8457/` (tailnet only; loopback 5232) |
| User / password | the fleet user; password `radicale/password` in sops, the same value the host renders into its htpasswd |
| Collection | `personal`, seeded by the Radicale unit's preStart, so the principal is never empty |
| Local copy | `~/.local/share/calendars/radicale/personal/` via `vdirsyncer-personal.timer` every 15 min |
| Phone | DAVx5: the URL above, same user and password; no public origin, so the phone must be on the tailnet |
| Gate | `task checks:caldav` — PROPFIND, then write, read back and delete a probe event |

Two sync units, not one, because the credentials are different kinds: `vdirsyncer`
carries the Google account behind `ConditionPathExists=…/google_token` (a host that
has not consented is skipped, not red), and `vdirsyncer-personal` carries Radicale
behind the sops password file. Gating both on the Google token would mean a host
set up for the self-hosted calendar never syncs; dropping the gate would make an
un-consented host red every 15 minutes.

khal keeps `default_calendar = "Primary"` (Google), so ask for the self-hosted one
explicitly: `khal list -a personal today 7d`. khal only sees what vdirsyncer last
wrote — `vdirsyncer sync calendar_radicale` is the immediate form (the pair is
`calendar_<account>`: home-manager's naming, not the account's).

## The two commands

```bash
scripts/calendar-auth.sh            # first sync: discover, wait for consent, sync, read back
scripts/calendar-auth.sh verify     # sync now, then show what khal can see
task checks:gcal                    # is the credential alive? one token exchange, no calendar traffic
```

The consent step is the reason this is a script: `vdirsyncer discover` keeps its
callback server alive **only while it runs**, so the browser step has to happen
inside that window, and the token file appearing is the success signal — not the
process exit code.

**The callback is `http://127.0.0.1:<port>` on the host** — `vdirsyncer` dynamically
binds to an ephemeral port (note: `8080` is occupied by `pihole-FTL` on frieren).
`scripts/calendar-auth.sh` parses the allocated port directly from the OAuth URL.

To complete the flow from another machine:
- **Option A (No SSH tunnel):** Approve the consent URL in your browser. When Google
  redirects to `http://127.0.0.1:<port>/?state=...&code=...` (which fails on your
  client), copy the full URL from the browser address bar and paste it into the script.
- **Option B (SSH tunnel):** Hold open the dynamically assigned port from your client:
  ```bash
  ssh -N -L <port>:127.0.0.1:<port> <host>
  ```

`verify` separates two failures that share an exit code: an auth rejection
(`invalid_grant`, `403 accessNotConfigured`) is fatal and named, while a
per-item error is warned about and the rest of the sync still counts.

**Known skipped item:** `WEBEX-MEETING%2BCENTER-6.0418931-1376670602.ics` on
`jisifu@gmail.com` — Google's multiget returns no properties for that href, so
vdirsyncer logs *"properties are missing"* and raises `NotFound` every run. One
event, not a sync failure; `verify` reports it under `skipped`.

## What decides whether it runs (no host lists)

Two declarative gates, both owned by the config rather than by a hostname:

- **Sync** — the credentials are declared (sops, above); the OAuth **token** is
  state, so `vdirsyncer.service` carries
  `ConditionPathExists=$XDG_CONFIG_HOME/vdirsyncer/google_token`. Where the token
  is absent the service is skipped (not failed): a host that has the credentials
  but has not consented yet has no red unit, and finishing the flow starts sync
  with no config change. This replaced a condition on
  `~/.config/rclone/rclone.conf`, which named rclone's file rather than the thing
  sync actually needs.
- **Notify** — `calendar-notify.{service,timer}` are `mkIf`
  `osConfig.programs.niri.enable`: the profile that installs the compositor
  (`modules/profiles/base-desktop-environment.nix`) sets it, so a headless
  generation (frieren's boot default) has no such unit at all, while its `desktop`
  specialisation and every desktop host do. The unit also carries the same
  token condition, because khal only has data after a sync.

The compositor side of that contract lives in `modules/user/desktop/niri.nix`:
niri's `spawn-at-startup` runs `systemctl --user import-environment WAYLAND_DISPLAY`
and starts `graphical-session.target`, which is what pulls in every
`WantedBy=graphical-session.target` session unit.

## Daily use

```bash
vdirsyncer sync                                  # immediate sync, no waiting for the timer
systemctl --user start calendar-notify.service   # one-shot probe of the next 15 min
systemctl --user status calendar-notify.timer
khal list today 7d                               # agenda; `ikhal` is the TUI
khal new 2026-10-20 14:00 15:00 "Team Meeting" :: Discuss project roadmap
```

The notifier deduplicates through `$XDG_RUNTIME_DIR/calendar-notified.cache`, so a
re-run inside the same event does not repeat the toast. An event is written to
that cache **only when `notify-send` succeeded** — a failed send (no session bus,
no notification daemon) is retried on the next tick instead of being swallowed
for the rest of the day. There is no display test in the script: the unit's
existence is the test.

To prove DMS rendering, bypass the notifier:

```bash
notify-send --app-name="Calendar" --urgency=normal \
  --icon="calendar-symbolic" --category="appointment" \
  "Calendar Test" "Meeting starts at 17:30 (Simulated)"
```

## The Cal.com booking surface (`task cal:*`)

Two authorities, and they answer different questions. **khal** is the calendar:
what is on it, when, from Google through vdirsyncer. **Cal.com** is the booking
surface in front of it: the event types someone can pick, the slots that are
free, and the booking record — who asked, with which address, under which uid.
khal never had that half, so a question about a booking is not a khal question.

```bash
task cal:events                          # slugs and ids of the page's event types
task cal:slots EVENT=15min DAYS=5        # public: no key, no account
task cal:list STATUS=upcoming LIMIT=10   # uids, attendee, start
task cal:book EVENT=15min START='2026-11-10 14:30' \
  NAME='…' ADDR='…'                     # prints the plan; needs YES=1 to send
task cal:cancel UID=<uid> REASON='…'     # same gate
task cal:reschedule UID=<uid> START='…'  # same gate
```

The three writes send an invitation and touch the real calendar, so the task
prints exactly what it will do and stops until `YES=1`. That is the
`confirm-before-destructive` policy, not politeness: `POST /v2/bookings` is a
public endpoint, which is the point of a booking page.

The attendee address is `ADDR`, not `EMAIL`: this Taskfile's root variables own
`EMAIL`, and a root variable wins over the command line.

Each endpoint pins its own `cal-api-version` — `2024-06-14` event types,
`2024-09-04` slots, `2026-05-01` bookings, `2026-02-25` the three writes.
Reusing one constant across them changes response shapes silently.

The account reads need `caldotcom` from the secrets plane, declared only where
the `agent-backend` trait is set (frieren, delphi). `cal:slots` works anywhere:
its `.md` document on the public page names the event id.

## When the calendar is out of reach

khal only knows what vdirsyncer last wrote, and a host without the token has no
local copy at all. Reach for `task cal:slots` and `task cal:list` first: they
answer synchronously and structurally. If the host cannot run them either, ask
the Cal.ai assistant at `mattji@my.cal.ai` — the constant is `user.calEmail` in
`modules/global/user.nix`. It reads the Cal.com calendar and answers a
scheduling question as mail, so a reply is the authority where a stale `.ics`
file is not. State the question and the window in the subject, for example
"Free 45 minutes next Tuesday afternoon?". Draft it with `himalaya message
write`; nothing in this skill sends on its own.

## Troubleshooting

- **403 accessNotConfigured** — the Google Cloud project lacks the CalDAV API
  (`caldav.googleapis.com`); the OAuth grant is fine, the API is not enabled.
- **Nothing appears after a sync** — check `khal list` sees the collection before
  blaming the timer: `vdirsyncer` writes files whether or not khal indexed them.
- **Expired token** — `scripts/calendar-auth.sh auth --force`; nothing else needs
  editing, because the client pair comes from the sops plane. Two kinds look
  identical from the journal and have different cures:
  - `refresh_token_expires_in` present in the token file means the consent
    granted *time-based* access and the token was born dead (52 seconds, once);
    re-approve choosing permanent access. The script refuses this at consent
    time now.
  - an OAuth app whose publishing status is **Testing** caps every refresh token
    at 7 days, so re-consent buys a week. Publish the consent screen.
- **Google escalates to an image CAPTCHA, and that is the real ceiling.** Tried
  2026-11-15 with `scripts/task/gcal-consent.sh` and the account password plus a
  live TOTP: identifier filled, `Next`, passkey challenge, `Try another way`,
  `Enter your password`, password filled, submitted — and the password page came
  back carrying *"Type the text you hear or see" / "enter the characters you see
  in the image above"*. After roughly six automated attempts Google adds that
  challenge to `/challenge/pwd`, and neither a password nor a passkey clears it;
  retrying is what earns it, so the driver now stops on the first sight of it
  (exit 4) and gives up on a cycling flow after 30 interactions (exit 6). Either
  run it with a human present who can solve one image, or make the passkey path
  win so the password page is never reached (`CAL_PASSKEY_FILE`; the primitive is
  `scripts/task/passkey-probe.sh`; the vault read is `task dev:passkey:fetch`).
- **A passkey cannot be typed, but it can be imported.** `scripts/task/passkey-probe.sh`
  proves the primitive without touching Google: a CDP virtual authenticator registers a
  credential on a local page, exports its PKCS8 private key, installs that key into a
  *second, empty* authenticator, and signs an assertion there — exit 0 means the
  vault → browser half of a headless passkey login is wired. `--from-vault FILE` takes
  the shape a Bitwarden item's `fido2Credentials` hold (`rpId`, base64url
  `credentialId`, base64 `privateKey`). Three facts bound the plan: `cloak` 0.3.0 is
  TOTP-only, and rbw — installed on every host and the fleet's vault client — prints
  `{id, folder, name, data, fields, notes, history}` from its `--raw`, which holds no
  `fido2Credentials`: bitwarden-cli is the only client that does, which is why
  `scripts/task/passkey-fetch.sh` exists. A passkey for the account must actually
  exist in Vaultwarden; and the
  Bitwarden *extension* is not the route on Linux because it breaks WebAuthn in
  Chromium outright (bitwarden/clients#17837). The RP ID must be a domain — a probe
  served on `127.0.0.1` is refused with "This is an invalid domain", so use
  `localhost`.
- **Headless re-consent works, but only with a display.** Tried 2026-11-15 on aarch64:
  `agent-browser` and `chromium --headless=new` are both refused at the password
  step ("Couldn't sign you in — This browser or app may not be secure"). The *same*
  Chromium binary under `xvfb-run` is accepted, and CDP over `node`'s built-in
  `WebSocket` drives it: email → (this account answers with a passkey prompt, so
  one **phone approval** is needed) → `google authenticator` code from
  `cloak view google` → a "update your password" speedbump → consent → the
  redirect lands on `127.0.0.1:<port>` **on this host**, so the code is exchanged
  locally and the token written. Keep the `--user-data-dir` profile -
  `~/.local/state/cdp-prof-headed` (it was /tmp until 2026-11-15, which a reboot
  empties): the cookies are the Google session, so the next consent skips the
  login and the phone tap. A consent driven this way produced a **permanent**
  grant where the paste-based exchange produced 604799 s.

Truth: `modules/calendar.nix` — the option surface; this page is the procedure.
