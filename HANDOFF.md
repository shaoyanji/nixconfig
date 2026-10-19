# HANDOFF — strategic queue

> **Two files, two jobs.**
>
> | File | Authority | Lifecycle |
> | :--- | :--- | :--- |
> | `/home/devji/HANDOFF.md` | live host state on frieren (daily audit findings, transient failures) | written by `agy-nightly-*`; local only |
> | `HANDOFF.md` (this file, repo) | cross-host architecture, migrations, decisions | edited by humans/agents; tracked |
>
> This file is a **queue**, not a diary. Detailed history moved to
> [`docs/history/handoff-2026-10.md`](docs/history/handoff-2026-10.md) and
> proposals live in [`ARCHITECTURE.md`](ARCHITECTURE.md). Budget: 150 lines.

## Active queue (2026-10-19)

| # | Item | Status | Blocker / next action |
| :--- | :--- | :--- | :--- |
| H-1 | **Fleet sentinel push** (ARCHITECTURE P1) | `ACCEPTED` | implement `pushUrl` + ingest + `ops:fleet`; no new port |
| H-2 | **Home `AGENTS.md` from Nix** (P4) | `ACCEPTED` | replace the activation-time Python call with a store symlink |
| H-3 | **DNS failover** (HC-3) | `BLOCKED` | no always-on second node; provisioning is hardware, not code |
| H-4 | **Resolver independence** (EXP-104/105) | `OPEN` | client fallback + health probe; can ship before H-3 |
| H-5 | **MQTT bus** (HC-5/EXP-007) | `BLOCKED` | HA requires a config-entry (no YAML/import path); needs one UI action, then the check can go green |
| H-6 | **Vault write path** (P2) | `ACCEPTED` | timer + inbox schema; depends on H-1 events |
| H-7 | **DMS sentinel widget** (P5) | `PROPOSED` | reads the existing loopback `status.json` |
| H-8 | **Canary promotion gate** (P6) | `PROPOSED` | CI runner with KVM |
| H-9 | **Closure budgets for remaining hosts** (EXP-110) | `OPEN` | adoption is local-only; run per host when online |
| H-10 | **`minyx` / `cassini` red host gates** | `OPEN` | `minyx`: `boot.kernelPackages` conflict → `mkDefault`; `cassini`: gate `freebuff-remote` to Linux |
| H-11 | **Restore drill through its unit** (EXP-111) | `OPEN` | needs one green `restic-drill.service` run, not another manual invocation |

## Standing rules for this queue

1. **One outcome per row.** If it has two exit criteria, it is two rows.
2. **`BLOCKED` names the blocker.** "Needs hardware", "needs a UI action",
   "needs a second resolver" — not "investigate".
3. **No design prose here.** A paragraph longer than three lines belongs in
   `ARCHITECTURE.md`; evidence belongs in `EXPERIMENTS.md`; history belongs in
   `docs/history/`.
4. **Promotion path:** `PROPOSED` → `ACCEPTED` (P-number in ARCHITECTURE) →
   `IN FLIGHT` → `DELIVERED` (one line in `AUDIT.md`) → removed from here.
5. **The daily host audit never edits this file.** It writes
   `/home/devji/HANDOFF.md`; a human or agent promotes a finding here with a
   commit.

## Recently closed (keep for one cycle, then move to history)

| Item | Closed | Evidence |
| :--- | :--- | :--- |
| Home `AGENTS.md` → `.#homeAgents.<host>` (P4) | 2026-10-19 | `lib/home-agents.nix`, store symlink on frieren |
| Context plane mk2 (skills compiled, schema, graph) | 2026-10-19 | `AUDIT.md` 2026-10-19 |
| Sentinel closed loop (frieren) | 2026-10-19 | `task ops:health`, `sentinel.frieren.lan` |
| Doc taxonomy + budgets | 2026-10-19 | `.agents/SCHEMA.md`, `task ops:docs:budget` |
| Restic password → sops + BurgerNAS target | 2026-10-14 | `services.restic.backups.frieren-burgernas` |
| NAS path governor | 2026-10-14 | `modules/profiles/nas-client.nix` |
| PostgreSQL collation refresh | 2026-10-13 | `AUDIT.md` 2026-10-13 |
| HC-1/2/4/6/7/8 implementation wave | 2026-10-12 | `docs/history/handoff-2026-10.md` |

## What the next operator should read, in order

1. `AGENTS.md` — invariants and the verification protocol.
2. `ARCHITECTURE.md` §0–§1 — where the layers are and which decisions bind.
3. `AUDIT.md` — current state, including what is known-red.
4. `TODO.md` — the P0/P1 stack.
5. `.agents/skills/task-plane/SKILL.md` — how to find the task, and why not to
   add one.
