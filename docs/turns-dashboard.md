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
- **Push, not poll.** The page is static; every turn arrives as a Datastar SSE
  patch (`datastar-patch-elements`, `mode inner` on connect, `mode prepend`
  after). Datastar is pinned in Nix and served from the same origin — a page
  that needs a CDN is blank exactly when the tailnet is all you have.
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
- The log carries the newest 120 turns at connect; older history is the store's
  (`agents:xs:list`), not a second paging protocol here.
