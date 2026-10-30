# Host Agent Contract

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
2. `AGENTS.md` § "Agent entry contract" — invariants and verification phases.
3. `.agents/SCHEMA.md` — where each kind of fact belongs.
4. `MANUAL.md` — services, access paths, the closed loop.
5. The owning skill for the subsystem (`task ops:skills`).

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

## Agent turns (before and after every turn, mandatory)

A fleet turn log lives on delphi so agents can see who is working on what, from
which base commit, before starting — and so a merge or test is checked against
real turns, not a stale chat report. It does not authorize a merge.

```bash
X=https://delphi.cloudforest-kardashev.ts.net:8449   # tailnet only
export AGENT_TURNS_TOKEN="$(sops -d ~/Documents/nixconfig/modules/secrets.yaml | yq -r '.["agent-turns-token"]')"
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" "$X/v1/events?repo=<repo>&limit=20" | jq '.events'
```

Read those turns first; if another agent claimed the same area or is
`in_progress` on the same subject, stop and report it instead of editing in
parallel. After the turn, `POST $X/v1/events` with the schema in `AGENTS.md`
§ "Agent turns" — summaries only, never secrets or transcripts. If the endpoint
is down, retry once, queue the entry in `~/.local/state/agent-turns/queue.jsonl`,
and replay it by UUID later.

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

## Where to write

| It is… | Write it to |
| :--- | :--- |
| A proposal / decision | an `AGENTS.nix` note (`task ops:notes`) |
| Open work | an `AGENTS.nix` note with `kind = "open"` / `"handoff"` |
| What happened | `AUDIT.md` (one line) |
| History | `docs/history/` |
| A procedure | `docs/` or a skill |
| A host fact | `inventory.toml` (`notes`) via `task dev:inventory:menu` |

Never create a new markdown file at the repo root. Never duplicate a fleet
table. If a command is written here, it must exist.
