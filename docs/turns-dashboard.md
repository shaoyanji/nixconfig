# Agent turns, as a field

The turn log on delphi, read the way the mail archive is: one panel per turn,
pushed live, with a prompt box on every row.

`modules/services/turns-dashboard.nix` serves it on loopback `:8099`; the mount
`turns` in `hosts/delphi/configuration.nix` publishes it at
`https://delphi.cloudforest-kardashev.ts.net:8460`, where the prompt box works.
A second, prompt-less reader is the public mount at
`https://delphi.bountystash.com/turns/` (see below).

## What it is

- **A reader, not a store.** Turns come from the xs store through the
  authenticated shim (`:8093`) — the same contract `agents:xs:post` writes
  against. The dashboard holds its own bearer token
  (`agent-turns-token-dashboard`), declared in
  `services.agentTurns.additionalTokens` with the shim's group and mode `0440`:
  both ends read that file, because the shim loads every token at start and dies
  without it (measured 2026-11-06: `start-limit-hit`, exit 1, no log line).
- **Push, not poll.** The page is static and carries no turn markup; every turn
  arrives as an SSE patch (`mode inner` on connect, `mode prepend` after, `mode
  remove` for the placeholder). The wire is plain text and `web/app.js` is its
  whole reader — forty lines, no library, so the writer in `main.go` and the
  reader cannot drift behind a release note.
- **Why not Datastar.** It was the first client here and it never applied a
  frame: the pinned v1 beta speaks a binary SSE format, so hand-written text
  patches are delivered and discarded (measured 2026-11-07 in the browser: the
  page opened the stream and a raw `EventSource` in the same page received the
  frame, while the log stayed on its placeholder).
- **The site revalidates.** `Cache-Control: no-cache` on every static file: a
  page left open for hours would otherwise keep an old `app.js` across a deploy.
- **One prompt per row.** Each panel posts `{row, prompt}` to `/api/prompt`,
  which runs `hermes -z` as the login user with the turn's own context prepended
  to the instruction. The answer is pushed into that row; nothing reloads. The
  prompt and its outcome are appended to
  `/var/lib/turns-dashboard/prompts.jsonl`, and `GET /api/prompts` is the
  machine surface for the same record.
- **No scrollbar.** The log is a wheel: rows snap, the top and bottom fade, and
  scrolling past either end wraps to the other.

## Reading it

- `j` / `k` move card to card and outline the one you are on; `g` is the top,
  `G` the bottom, and `Shift`+arrows do the same for people who do not live in
  vim. The movement keys are inert while a prompt box has focus.
- `/` focuses the fuzzy finder. Every token has to land inside a word of a card —
  `umami` finds the umami turn, `trn` still finds `turn` — a subsequence over the
  whole card is not a finder (it matched 40/40), and the count reads
  `matched/total`. `esc` clears, `enter` jumps to the first match.
- `?` opens the key list (and a `?` button in the header does the same); while it
  is open, movement keys are inert and `esc` closes it. The list is generated from
  no data — it is nine rows of static markup, so a new binding is a second edit in
  the same commit.
- The finder lives in the URL: `?q=umami` is the same filtered view, applied when
  the history frame arrives, so a reload or a pasted link lands on it. It is
  `history.replaceState`, not `pushState` — typing must not fill the back button —
  and the query is relative, so it stays on whichever mount served the page.
- `▲ jump to top` is a real link (`href="#top"`). The anchor is re-attached after
  the history frame, which replaces every other child of `#log`.
- A turn that arrives while you are further down is announced as a toast (source,
  subject, first line); clicking it travels to that card. The scroll position is
  carried across the insert, so a new turn never yanks the page under you.

## Operating it

```bash
systemctl status turns-dashboard
journalctl -u turns-dashboard -n 40
curl -sN http://127.0.0.1:8099/api/stream | head -c 400      # the wire
curl -s  http://127.0.0.1:8099/api/prompts | tail -1          # what was asked
sudo tail -1 /var/lib/turns-dashboard/prompts.jsonl           # and answered
```

A prompt is an agent turn, and it costs what a turn costs: the service allows
two concurrent runs, each capped at four minutes.

## Why it runs as `devji`

Hermes reads its credentials and writes its sessions from that home, and a
prompt is the operator's own turn — running it as a service user would need a
second credential plane for no isolation the tailnet does not already give. The
unit therefore keeps no `NoNewPrivileges`: subagents escalate through the setuid
sudo wrapper.

## The public mount, and why it cannot prompt

`https://delphi.bountystash.com/turns/` is the same log for a reader with no
tailnet. nginx proxies a second reader (`services.turnsDashboard.publicPort`, a
loopback port) that runs `-read-only` and has no Hermes: its rows carry no prompt
form and `POST /api/prompt` answers 403, so that mount publishes the field and
cannot spend an agent turn. The tailnet mount on `:8460` stays the only browser
surface where a prompt can start.

Both mounts serve the same files, so the page's assets and stream are relative
(`style.css`, `api/stream`): an absolute `/api/stream` would leave the public page
streaming from the site root.

`task agents:xs:demo` is the proof, and it is cheap — no rebuild, no funnel:

```bash
task agents:xs:demo              # posture + one post + browser assert
```

It asserts the public posture first (rows present, no prompt form), opens the
page, posts one turn through the publisher `agents:xs:post` uses, and then
requires the frame on the public stream *and* the row in the open page while a
`window` marker set before the post survives — a page that navigated would have
cleared it.

A temporary Tailscale Funnel was the first way this was demonstrated (read-only
reader on loopback, `tailscale funnel --https=10000`, removed and verified gone).
It worked and it is no longer needed now that the public vhost exists.

## Not done

- The public mount has no authentication: it is readable by anyone with the URL,
  and it is read-only by construction rather than by policy.
- The log carries the newest turns at connect; older history is the store's
  (`agents:xs:list`), not a second paging protocol here.
- The demo is a run, not a CI gate: it needs delphi (the store and the token), so
  it stays an operator instrument (`agents:xs:demo`).
