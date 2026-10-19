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
| A proposal / decision | `ARCHITECTURE.md` |
| Open work | `TODO.md` or the repo `HANDOFF.md` |
| What happened | `AUDIT.md` (one line) |
| History | `docs/history/` |
| A procedure | `docs/` or a skill |
| A host fact | `inventory.toml` (`notes`) via `task dev:inventory:menu` |

Never create a new markdown file at the repo root. Never duplicate a fleet
table. If a command is written here, it must exist.
