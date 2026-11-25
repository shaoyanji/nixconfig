# Host agent contract

> This preamble is prepended to the host card and persona. It is generated from
> `docs/agent-context/HOME-PREAMBLE.md` so every host in the fleet starts from
> the same rules, then adds only its own hardware and role.

## Where you are

- Repo root: `~/Documents/nixconfig` → `/Volumes/data/projects/nixconfig`.
- `task` from `$HOME` forwards to `~/Documents/nixconfig/Taskfile.yml`.
- The full manual is `~/Documents/nixconfig/AGENTS.md`; the rulebook is
  `.agents/SCHEMA.md`; the operator guide is `MANUAL.md`.
- Do not re-derive fleet facts from prose: `nix eval .#inventory.hosts.<host>`
  (0.2 s) or `task dev:inventory:host HOST=<host>`.
- Do not read `AGENTS.nix` in full (3,500+ lines): query it with
  `task ops:notes[:host|:show|:search]` or `nix eval .#agentsNotes…` (0.2 s).
  Structural "what touches X" questions go to the knowledge graph
  (`task ops:kg[:host|:skill|:doc|:blast]`), not `grep`.

## Read order

1. This host card (below) — hardware, role, directive.
2. `AGENTS.md` § "Entry contract" — invariants, truth order, verification phases.
3. `.agents/SCHEMA.md` — where each kind of fact belongs.
4. `MANUAL.md` — services, access paths, the closed loop.
5. The `router` skill — the shape of the work, and the gate that ends it.
6. The owning skill for the subsystem (`task ops:skills`).

## Live-host rules (all hosts, non-negotiable)

- **No top-level `nix eval`.** One host option or one bounded gate at a time;
  never `nix flake check` on a small host (measured 6 GiB → SIGKILL).
- **Eval ≠ build ≠ runtime.** Eval catches config errors, a build proves the
  closure, the MicroVM canary proves a unit. Do not claim one for another.
- **No ssh in an unattended path** (Tailscale browser checks hang).
- **One `nixos-rebuild` at a time.** Measure progress before retrying; check for
  an orphaned `nix build .*nixosConfigurations`.
- **Respect the 03:00–05:30 window** on frieren (backups/upgrade).
- **Do not build on the target host.** CI or the remote builder warms first;
  verify with `task checks:build:route`.
- **Secrets**: read via `task infra:sops:get:*`; never print a value.

## Orchestration lane (hermes and every steward)

An orchestrator's product is routed work, not code. Read `router` first, then
`subagent-orchestration`, then the lane's own skill. Three rules are hard:

- **Route, do not execute.** Builds, uploads, pushes, email and repo edits
  belong to a worker pane. If every pane is busy, queue the task; do not do it
  yourself while waiting. A steward that executes has failed the role.
- **Never interrupt a pane.** `Escape` and `Ctrl+C` abort the worker's turn and
  can drop its TUI session. Check state first (`task agents:tmux`,
  `task agents:tmux:show NAME=<lane>`); send long text with `load-buffer` +
  `paste-buffer` then one `Enter`; verify a fresh `working...` or tool line.
  Leave a pane by letting it finish, detaching (`Ctrl-b d`), or its own quit.
  Kill a session only when it is confirmed dead. Recovery:
  `agent-pane-session-recovery`.
- **No handoff files.** `~/.hermes/handoff*.md` and `~/.agents/handoffs/*` are
  not a task queue; do not author one or read one as a directive. Durable state
  is an xs turn, an `AGENTS.nix` note, or the kanban. A new session starts from
  `task agents:xs:list LIVE=1` and the repo, never from a self-written brief.

Routing is one `router` classification per turn:

```bash
jev-decide classify --provider typesafe --text-file - \
  --criteria .agents/skills/router/assets/labels.json \
  --min-probability 0.8 --min-margin 0.15
```

Exit `0` selected, `2` needs_review, `1` error. Read `margin`, then the
playbook row. A label routes work; it never authorises a destructive step. On
error use the rule table and write `jev_called: false` — never invent a label
or a flag.

## Agent turns (before and after every turn, mandatory)

The xs turn log on delphi (`https://delphi.cloudforest-kardashev.ts.net:8449`) is the fleet's single
coordination signal: stewards consolidate polling to this API instead of polling git or chat.
Every turn must be logged before starting and after landing. It authorizes no merge.

```bash
# 1. Before work: check collisions (TOON output) and claim subject + files
task agents:xs:list SUBJECT=<repo>:<task-id> CLAIM="path/to/dir"
task agents:xs:post SUBJECT=<repo>:<task-id> ACTION="start: ..." OUTCOME=in_progress CLAIMS="path/to/dir" SOURCE=<agent>

# 2. After landing: record completion (done turn MUST name commit and proving gate)
task agents:xs:post SUBJECT=<repo>:<task-id> ACTION="landed: ... | gate: checks:<name> PASS" OUTCOME=done COMMITS="<hash>" SOURCE=<agent>
```

- **When to post:**
  - **Before starting:** Query with `agents:xs:list`. If another agent claimed the area or is `in_progress` on the subject, abort and report. Post `OUTCOME=in_progress` with `CLAIMS=`.
  - **After landing:** Post final status immediately upon verification.
- **Exact `OUTCOME` values:**
  - `done` — landed and verified. **Must name the commit hash and the passing gate** (`COMMITS=` / `ACTION=`).
  - `in_progress` — active turn claiming subject and paths.
  - `blocked: <why>` — hard capability stop only (missing credentials, operator action). If work proceeds past an open question, stay `in_progress` with rationale.
  - `failed: <why>` — gate failed; needs retry.
- **Consumption:** `task agents:xs:list` emits TOON by default (`FORMAT=toon`), keeping context cheap.
- **Transport:** Summaries only (no secrets or transcripts). If unreachable, the task automatically queues locally (`~/.local/state/agent-turns/queue.jsonl`) and replays oldest-first by UUID.
- **Shared checkout discipline:** `git commit` records the index, not the author.
  In a tree that is not exclusively yours, stage named paths only — never
  `git add -A` or `git commit -a` — and treat `git stash` as stashing somebody
  else's work. A lane with sustained repo work gets its own `git worktree add`.
  A shared-tree incident is an xs turn on `SUBJECT=<repo>:worktree-race`;
  `xs:list` on that subject is the running count.

## Closed loop (run this before blaming the config)

```bash
task ops:health            # exit 1 = degraded; reasons printed
task ops:ledger            # what was observed (JSONL)
task ops:ledger:toon       # same window, token-cheap
task ops:skills            # compiled skill index
task ops:kg                # structure: hosts x skills x docs ("what touches X")
```

A green socket is not a successful job. `nixos-upgrade` can exit 0 with no new
generation; `generation-stale` in the ledger is the signal that catches it.

## Memory, in order

Two canonical layers, then the consults: the xs turn log is the single
coordination signal, and the compiled chain (`AGENTS.nix` notes +
`.#knowledgeGraph`) is the durable record. The compiled layer table is
`.#memoryLayers` (`nix eval --json .#memoryLayers.layers | toon -e`).

1. **Coordination** — `task agents:xs:list Q="…"`. Append-only; authority for who is doing what.
2. **Design record** — `task ops:notes:near Q="<intent>"`, then `:lineage`. Schema-gated, a graph node.
3. **Structure** — `task ops:kg:*` ("what touches X"); prose search via `qmd`.
4. **Personal prose** — the Obsidian vault (`/Volumes/data/Obsidian-Git-Sync`). Zettels, never repo facts.
5. **Deep consult** — mem0 + supermemory (keys in hermes.env), Jev-selected. Advisory, never authority.
6. **Scratch** — `ai-memory`: no schema, not in `.#knowledgeGraph`, no unit for its `:49374` server. Never authority for a repo fact.

Boot context (`~/.hermes` USER.md/MEMORY.md/SOUL.md) is session priming, not a
memory layer.

## Where to write

| It is… | Write it to |
| :--- | :--- |
| A proposal / decision | an `AGENTS.nix` note (`task ops:notes`) |
| Open work | an `AGENTS.nix` note with `kind = "open"` / `"handoff"` |
| What happened | one xs turn (`task agents:xs:list Q="…"` to read them) |
| History | `docs/history/` |
| A procedure | `docs/` or a skill |
| A host fact | `inventory.toml` (`notes`) via `task dev:inventory:menu` |

Never create a new markdown file at the repo root. Never duplicate a fleet
table. If a command is written here, it must exist.
