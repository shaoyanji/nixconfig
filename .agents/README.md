# Agent Context — Start Here

This directory is the **agent context plane**: a router, a schema, and skills.
It is not a second manual and it is not executable truth.

| You need | Go to |
| :--- | :--- |
| Fleet facts (host, hardware, role, status) | `nix eval --json .#inventory.hosts.<host>` — never a copied table |
| What touches X (structure, not prose) | `task ops:kg:host HOST=<host>` (or `ops:kg:skill`, `:doc`, `:tag`, `:comention`) — `.#knowledgeGraph`; `ops:ask Q=…` is the English sugar |
| What tasks exist / which answers an intent | `task help`, `task find:<word>`, `task --list-all --json` |
| How to operate the fleet | `AGENTS.md`, `MANUAL.md` |
| Why a design exists / what is next | `AGENTS.nix` notes — `task ops:notes` (`:host`, `:module`, `:search`) |
| How to author or promote a note | `skills/agents-notes/SKILL.md` (templates + promotion ladder) |
| What happened | `AUDIT.md`, `docs/history/` |
| A novel task, or "has this been tried?" | `task ops:notes:near Q="<the intent in your words>"` — ranked notes, each with its lineage and refs; `task ops:notes:lineage ID=<id>` for one note's ancestry |
| An experiment | `task ops:notes KIND=experiment` (`exp-NNN` notes) |
| A visual system for a new surface (page, deck, TUI skin) | `design/ryoku/DESIGN.md` — tokens, type scale, components, agent prompts |
| Host-specific deploy notes | `deploy/README.md`, `deploy/hosts/*.md` |
| A skill | `skills/<name>/SKILL.md` — index below is compiled |
| Which tool owns a data format (TOML, YAML, Nix, JSON, TOON) | [`SCHEMA.md`](SCHEMA.md) §1, "Formats, and the tool that owns each" |
| The rules for all of the above | [`SCHEMA.md`](SCHEMA.md) |

## Skills are compiled, not indexed by hand

The authoritative index is Nix:

```bash
nix eval .#agentSkills.count                      # count, ~0.12 s warm
nix eval --json .#agentSkills.byTag.nix | toon -e           # names tagged nix
nix eval --json .#agentSkills.skills.task-plane | toon -e   # one entry
nix build .#checks.x86_64-linux.skills-schema -L  # the gate
nix build .#artifacts.agent-skills-bundle                     # skills + index.json in one store path
```

`lib/skills.nix` parses each `SKILL.md` frontmatter, enforces the contract in
`SCHEMA.md`, and emits the index. A new skill is discovered by adding a
directory — there is no table to update, so there is no table to forget.

## The skills that matter most (pinnacles)

| Skill | Why it is a pinnacle |
| :--- | :--- |
| [`task-plane`](skills/task-plane/SKILL.md) | The control plane is hundreds of tasks (`task --list-all \| wc -l`); this is the intent→task router, cost tiers, and the authoring contract. Read it before adding a task. |
| [`nix-eval`](skills/nix-eval/SKILL.md) | The cheapest instrument ladder. Most "I need a script" questions are a 1-second eval. |
| [`master-toon`](skills/master-toon/SKILL.md) | TOON is how structured evidence (ledgers, inventories, logs) reaches an agent without burning context. Encode/decode, when **not** to use it. |
| [`knowledge-base`](skills/knowledge-base/SKILL.md) | Where knowledge lives, which store to query first, and the graph/prose/episodic split. |
| [`host-facts`](skills/host-facts/SKILL.md) | Answer host questions from the compiled registry, never by evaluating a config. |
| [`agents-notes`](skills/agents-notes/SKILL.md) | The design record: find the note near a novel intent, read its lineage, and promote an idea into a gate instead of a second markdown file. |
| [`fleet-sentinel`](skills/fleet-sentinel/SKILL.md) | The closed loop: how a failure is detected, recorded, and routed. |

## Skill families

| Family | Skills |
| :--- | :--- |
| Control plane | `task-plane`, `nix-eval`, `host-facts`, `checks`, `dev`, `infra`, `services` |
| Context & memory | `knowledge-base`, `master-toon`, `qmd`, `ai-memory` |
| Fleet services | `fleet-sentinel`, `home-assistant`, `paste`, `wikisearch`, `iventoy`, `burgernas` |
| Media & AI | `eisen-status`, `decision-picker`, `voice-loop`, `image-generate`, `stt` |
| Hosting | `moto`, `serv00`, `dragoncourt`, `envs`, `bountystash`, `apps`, `google-drive` |
| Method | `confirm-before-destructive`, `nixos-deploy`, `nix-preflight-editor`, `correct`, `no-comments`, `unslop`, `prove-it-works` (pstack, adapted), `tmux` |

## Materialization (fleet-wide)

`modules/user/ai/skills/default.nix` is the single materializer. It links two
sources into every agent's discovery path:

1. `.agents/skills/*` — the repo's documentation/ops skills (this directory).
2. `modules/user/ai/skills/*` — runtime skills that ship scripts (e.g.
   `simplex-admin`, `jev-ultrafast`).

Targets: `~/.agents/skills/<name>` and `~/.gemini/config/skills/<name>`.
`~/.agents/README.md` and `~/.agents/SCHEMA.md` are linked too, so a clone-less
agent still gets the contract. The bundle is the same tree CI validates.
`~/AGENTS.md` itself is `.#homeAgents.<host>` (`lib/home-agents.nix`): preamble +
compiled host card + persona, linked by activation, never rendered at runtime.

> Managed names are `force`-linked: a stale hand-copied skill directory is
> replaced on the next switch. Unmanaged names (e.g. a community skill installed
> by `npx skills`) are left alone. To make one canonical, add it to the repo.

## Truth boundaries

- `taskfiles/*.yml` — executable truth.
- `inventory.toml` / `modules.toml` — compiled data truth.
- `hosts/**/*.nix`, `modules/**/*.nix` — deployment truth.
- `.agents/*`, `AGENTS.md`, `MANUAL.md` — routing and procedure.
- `scripts/task/*` — helper implementations, never entrypoints.
