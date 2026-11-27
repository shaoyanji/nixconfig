---
name: hermes-pane-context-restore
description: Restore a stalled Hermes pane from the xs live queue and the repo, never from a handoff file.
version: 0.2.0
author: Matt Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['hermes', 'tmux', 'context-restore', 'orchestration', 'fleet']
    related_skills: ['tmux', 'xs-turns', 'agent-turns', 'router']
---

# Hermes Pane Context Restore

Recover a Hermes agent in a tmux pane after model failover, context loss, or a
stuck draft buffer. The context comes from the fleet's coordination log and the
repository — **never from a handoff file**. `~/.hermes/MEMORY.md` § "No handoff
channel" is the rule, and `task checks:hermes` fails on `~/.hermes/handoff*.md`
or `~/.hermes/handoffs/`.

## When to use

- The pane shows failover warnings and stopped producing turns.
- The compose buffer holds text that will not submit.
- The agent lost the active tasks and is asking what to do.

Do not use when the pane is working: a live turn looks idle between tool calls.

## Prerequisites

- The pane name from `task agents:tmux` (the map, not a guessed index).
- `task agents:xs:list LIVE=1` answers, or its offline queue does.
- Both the pane and this session share `~/.hermes` on the same host.

## Procedure

1. **Prove it is stalled before touching it.** Check the pane for a fresh
   working line and the last turn's output. `MEMORY.md` § Pane control: never
   send `Escape` or `Ctrl+C` to a pane that is working — it aborts the worker's
   turn and can drop the session. If the pane is mid-turn, leave it and re-check.
2. **Read the coordination state, not a narrative.** `task agents:xs:list
   LIVE=1` gives one row per unresolved subject: `in_progress`, `blocked` and
   `failed` are the live ones, and the newest entry per subject decides. This is
   what replaces a handoff file.
3. **Read the repo record for the subject.** `task ops:notes:near Q="<intent>"`
   for the decision, `task ops:notes:lineage ID=<id>` for its history. Do not
   read `AGENTS.nix` in full.
4. **Hard-reset only a stalled pane.** `tmux send-keys -t <pane> C-c`, then
   `tmux send-keys -t <pane> 'hermes chat' C-m`. Wait for the prompt.
5. **Re-inject a short pointer, never a brief.** One line naming the live queue
   and the repo is enough:
   `tmux send-keys -t <pane> 'Run task agents:xs:list LIVE=1 and continue its top live subject from the repo.' C-m`.
   Long directives queue in the TUI draft buffer, truncate, or fail to submit.
6. **Verify by action.** The pane should run the list and start on the top
   subject. A rendered prompt is not proof; a tool call is. If nothing happens
   after two C-c + restart cycles, escalate to the operator with what the queue
   said.

## Writing the continuation instead of a handoff

| It is… | Write it to |
| :--- | :--- |
| What happened, and what is still open | one xs turn — `task agents:xs:post` with `OUTCOME=in_progress` and the next step in `RATIONALE` |
| A decision or proposal | an `AGENTS.nix` note (`agents-notes` skill) |
| Open work | an `AGENTS.nix` note with `kind = "open"` / `"handoff"` |
| A procedure | `docs/` or a skill |

An xs turn is retrievable by subject and source; a handoff file is a defect that
the gate refuses and that a new session should not read as a directive queue.

## Pitfalls

- **Handoff loop.** The old version of this skill told the agent to write
  `~/.hermes/handoff.md`; that produced a self-referential loop (the agent
  briefing itself mid-chat) and failed `task checks:hermes`. Do not recreate it,
  not even as `handoff.done` or under `backups/`.
- **Failover resets context.** Every model hop starts fresh; rebuild from the
  live queue instead of continuing a half-finished thought.
- **Quoting.** Keep the tmux message one short line; substance belongs in the
  repo, not in `send-keys`.
- **Authority.** The queue says what is live; it authorises nothing. Delete,
  deploy, push and send still need the operator.

## Verification

`task checks:hermes` must report `no handoff files`, the pane must run a tool
call from the pointer, and the continuation must exist as an xs turn or an
`AGENTS.nix` note rather than a markdown brief.

Truth: `scripts/task/xs-turn-list.sh` — the live queue this restores from; this page is the procedure.
