# Agent turns, as a field

The turn log on delphi, read the way the mail archive is: one panel per turn,
pushed live, with a prompt box on every row.

`modules/services/turns-dashboard.nix` serves it on loopback `:8099`; the mount
`turns` in `hosts/delphi/configuration.nix` publishes it at
`https://delphi.cloudforest-kardashev.ts.net:8460` and is the only exposure.

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

## Not done

- No authentication beyond the tailnet. The page can spend agent budget; the
  mount is the fence.
- The log carries the newest turns at connect; older history is the store's
  (`agents:xs:list`), not a second paging protocol here.
- No gate for the browser path yet: the live-update proof is a run, not a test
  (`clanker` serves the page against a mock shim; a row appended to the mock
  file appears in the open page).
