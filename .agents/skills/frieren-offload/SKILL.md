---
name: frieren-offload
description: "Offload heavy agy tasks from netbook to frieren: the agentScheduler nightly jobs, their triage gate, the 4-tier agent cascade, and dispatch by hand when you cannot wait."
version: 0.2.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['frieren', 'offload', 'agy']
    related_skills: ['tmux', 'agents-notes']
---

# frieren-offload — put the heavy agent on the always-on host

netbook is 1.8 GiB of RAM: an indexing job, a container build or a long agent loop
exhausts it. frieren is always on and has the storage. The point is decoupling —
once dispatched, the netbook can be closed.

Facts about either host are `inventory.toml`; `nix eval .#inventory.hosts.<h>`
answers them without evaluating a config. ssh hosts are in `~/.ssh/config`
(`frieren` on the LAN, `frieren-ts` over Tailscale), so never paste the IP.

## The scheduler is the offload mechanism

Nightly work is declarative: `services.agentScheduler.jobs` in
`hosts/frieren/infra-stack.nix`, each an entry with `schedule`, `command`,
`workingDirectory` and an optional `lockFile`. Adding a job is an edit there and
a deploy of frieren, not a second cron.

| Job | When | What it runs |
| :--- | :--- | :--- |
| `agy-nightly-handoff` | 03:00 | `agyHandoffRunner` on `~/HANDOFF.md` |
| `agy-nightly-system` | 05:00 | `agySystemRunner` on `~/SYSTEM.md` |
| `audible-phased-liberation` | 00:00 | batch download, 50 GB cap, hard stop 02:50 |

Read the definitions first: `rg -n "agentScheduler" -A40 hosts/frieren/infra-stack.nix`.

### The 03:00 handoff runner

1. No `~/HANDOFF.md` → exit 0. Dropping that file is the whole interface:
   `scp HANDOFF.md frieren:~/HANDOFF.md`.
2. Archives it to `~/.agents/handoffs/HANDOFF-<timestamp>.md`.
3. **Triage gate:** `systemone-decision --model julia-1 triage-handoff` writes
   `/tmp/systemone-handoff-triage.json`. With no `AUTONOMOUS_PROMOTION_CANDIDATE`
   the run exits 0 without spending a token, which is why a handoff full of items
   blocked on hardware costs nothing. `FORCE_RUN=1` (or `--force`) skips the gate.
4. Runs the cascade with the triage report in the prompt.
5. **Leaves `HANDOFF.md` in place.** It is preserved for inspection on success
   and on failure; nothing deletes it.

### The 05:00 system runner

Deterministic checks first, no tokens: failed system and user units (`reset-failed`),
btrfs device stats, a fixed list of backup units, then the cascade for anything
that needs judgement. Archives to `~/.agents/system/` and also preserves the file.

### The agent cascade (same for both jobs)

Tier 1 `agy` → Tier 2 `freebuff-headless` → Tier 3 `hermes chat -q … --oneshot`
→ Tier 4 `crush run --quiet`; the first exit 0 wins, and agy fails on credit
exhaustion, so the fallbacks are real.

## Dispatch something now

Two routes (the old `agy-offload` helper is gone — do not look for it):

```bash
# a) queue it for 03:00 — survives logout, costs nothing until triage says go
scp HANDOFF.md frieren:~/HANDOFF.md

# b) run it immediately, in a session that outlives the tool call (see `tmux`)
ssh frieren "tmux new-session -d -s agent-job -c /var/lib/job -- \
  nix shell nixpkgs#... -c agy --dangerously-skip-permissions -p 'Read HANDOFF.md and execute it.'"
```

Use `/var/lib/<job>` for the working directory, not `$HOME`: hardened units with
`DynamicUser` + `ProtectHome` cannot read `/home`. Give each job its own directory
so two of them do not share a log or a `HANDOFF.md`.

Agent CLI flags: `agy` needs `--dangerously-skip-permissions` in a detached session
(no TTY to approve a prompt, so it would block forever); `crush` `run --quiet`;
hermes hangs them on the subcommand — `chat -q "$p" --oneshot -Q --run-budget 600`,
`-Q` keeping banner and footer out of the log, and tools need no `--yolo` under a
non-TTY (measured). Top-level `hermes -q … --oneshot` exits 2 without running.

## Watching it

```bash
ssh frieren "systemctl --user list-timers 'agy-nightly-*' --no-pager"
ssh frieren "journalctl --user -u agy-nightly-handoff.service -n 40 --no-pager"
ssh frieren "ls -lt ~/.agents/handoffs/ | head"
ssh frieren "grep -c '\"status\": \"OPEN\"' /tmp/systemone-handoff-triage.json"
```

A tier success line in the journal is the evidence; a green timer only says it fired
(`fleet-sentinel`).

Truth: `hosts/frieren/infra-stack.nix` — the jobs and their runners; this page is the procedure.
