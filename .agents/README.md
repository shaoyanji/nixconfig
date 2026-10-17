# Agent Guidance Index

## Skills (from Taskfiles)

Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md`:

| Skill | Source | Scope |
|-------|--------|-------|
| [`infra`](skills/infra/SKILL.md) | `taskfiles/infra.yml` | Host lifecycle, secrets, SOPS, store |
| [`agents`](skills/agents/SKILL.md) | `taskfiles/agents.yml` | Operator menu, xs, OAuth |
| [`checks`](skills/checks/SKILL.md) | `taskfiles/checks.yml` | Validation, smoke checks, nix lint |
| [`dev`](skills/dev/SKILL.md) | `taskfiles/dev.yml` | Git, flake, site, PRs, packages |
| [`services`](skills/services/SKILL.md) | `taskfiles/services-core.yml`, `services-legacy.yml` | Legacy wrappers |

## Cross-Cutting Skills (start here)

| Skill | Scope |
|-------|-------|
| [`task-plane`](skills/task-plane/SKILL.md) | Navigate 373 tasks by intent (`task help`, `task find:<x>`), cost tiers, what each gate proves, when NOT to add a task or script |
| [`nix-eval`](skills/nix-eval/SKILL.md) | Cheapest-instrument ladder for one-off questions: `/tmp` nix files, flake attr names, `hostChecks` assertion gates, substitutability — with measured costs and the evals that must never run here |
| [`host-facts`](skills/host-facts/SKILL.md) | Host description from the compiled inventory (field map + jq recipes) — never evaluate a config to answer "what is host X" |

## Specialized & Subsystem Skills

| Skill | Scope |
|-------|-------|
| [`home-assistant`](skills/home-assistant/SKILL.md) | Home Assistant, Mosquitto MQTT, host telemetry sensors, and Uptime-Kuma on frieren |
| [`paste`](skills/paste/SKILL.md) | Fleet paste bin (`pb`) for sharing files and logs over LAN/mesh (`paste.frieren.lan`) |
| [`burgernas`](skills/burgernas/SKILL.md) | Synology DS220j cold vault (BurgerNAS, `taskfiles/burgernas.yml`): WoL power, restic backup target, leech-only Transmission, aria2/AriaNg, sops-managed sudo credential |
| [`nixos-deploy`](skills/nixos-deploy/SKILL.md) | SSH-safe rebuild/activate sequence: `systemd-run` detachment, done-file polling, polkit activation workaround |
| [`iventoy`](skills/iventoy/SKILL.md) | PXE boot management, ISO image library (`/Volumes/data/isos`), and bare-metal OS provisioning |
| [`wikisearch`](skills/wikisearch/SKILL.md) | Offline Wikipedia and ArchWiki BM25 search via Kiwix (`wiki.frieren.lan`) |
| [`frieren-offload`](skills/frieren-offload/SKILL.md) | Offload heavy agy tasks from netbook/workstations to frieren |
| [`stt`](skills/stt/SKILL.md) | Speech-to-text via voxtype (numtide) daemon / headless transcription |

## Routing

- **Tasks**: `Taskfile.yml` loads the `taskfiles/*` shards. `task help` prints the intent map (namespace counts computed live) and `task find:<word>` searches names + descriptions; `task --list-all` remains the unfiltered list. See [Task Control Plane](docs/task-control-plane.md) for namespace policy and workflow examples.
- **Task graph integrity**: `task checks:tasks` (free) fails on duplicate task keys within a shard (YAML keeps the last, silently) and on dangling `task X` references. It is part of `task checks:quick`.
- **Host lifecycle tasks**: Canonical operations live under `infra:*` (`taskfiles/infra.yml`). Legacy `services:*` names wrap to `infra:*` via `taskfiles/services-core.yml`.
- **Docs**: `lib/docs.nix` generates the metadata pages (fleet inventory, modules registry, per-host) and the docs-site nav from the compiled registry. `nix build .#docs` / `.#docs-site` are the source of truth; `task docs:sync` refreshes `docs/generated/`, `task checks:docs:sync` proves the copy matches. Do not hand-edit `docs/generated/*`.
- **Deploy guidance**: Start with `.agents/deploy/README.md`; per-host notes live in `.agents/deploy/hosts/*.md`.
- **Task routing**: `AGENTS.md` provides the top-level task namespace summary.

## Provenance and Home Initialization

- **Home Entrypoint**: When working from `$HOME` (`~`), `~/Taskfile.yml` provides tautological access to all commands in `~/Documents/nixconfig/Taskfile.yml` with `dir: ~/Documents/nixconfig` and `flatten: true`.
- **Repo Root**: `~/Documents/nixconfig` (symlink to `/Volumes/data/projects/nixconfig`).
- **Guidance & Skills**: Materialized in `~/.agents/` via Home Manager (`modules/user/ai/codex.nix`).
- **Canonical Manual**: `AGENTS.md` (and mirrored at `~/AGENTS.md`) is the unified manual for both agents and operators.

## Truth boundaries

- `taskfiles/*.yml` are the **executable truth**.
- `~/Taskfile.yml` forwards directly to `~/Documents/nixconfig/Taskfile.yml`.
- `.agents/*` and `AGENTS.md` document routing, fleet matrix, and runbooks.
- `scripts/task/*` are helper implementations, not entrypoints.
