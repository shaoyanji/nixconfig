# Taskfile map

## Scope
Quick reference to who owns each taskfile and where to go for lifecycle, deployment, and operator queries.

## Canonical ownership
- `Taskfile.yml` is the entrypoint; it loads the shards and hosts top-level helper menus (`deploy`, `logs`, `status`, `menu`).
- `taskfiles/infra.yml` is the canonical host lifecycle surface (`infra:*`) for plan/apply/deploy/rollback/logs and secrets management, and it owns the detached job surface (`infra:job:*`) that long tasks are started through.
- `taskfiles/agents.yml` holds operator helpers, xs runtime wrappers, and OAuth/session management.
- `taskfiles/check.yml` is the uniform entry to that surface: `check:leaf`,
  `check:host`, `check:cache` and `check:list` over `taskfiles/checks.toml` (one
  row per gate and its kind; `check:verify` keeps the two in step).
- `taskfiles/checks.yml` contains validation and health checks (host evals, Nix lint/format, sops drift, flake transitive-input sweep).
- `taskfiles/codespace.yml` owns GitHub Codespaces as a mode (`codespace:*`) for work that runs in someone else's remote devcontainer: the file transport `gh codespace cp` cannot do, a push that happens on the host holding the git auth, a reset for the post-rewrite clone, and a stop that waits for `Shutdown`.
- `taskfiles/deals.yml` owns price watching (`deals:*`): `deals:page` reads deal cards off a rendered board and `deals:ingest` pipes them into private-deals, which owns the index.
- `taskfiles/dev.yml` contains git/flake/local helper workflows, including site build/preview/deploy tasks.
- `taskfiles/instabox.yml` owns InstaBox machines (`instabox:*`) as a dependency-free surface: the HTTP API with the sops key, an SSH token minted through it for a plain `ssh`, and `exec` when no shell is needed. Skill: `.agents/skills/instabox`.
- `taskfiles/services-core.yml` holds the canonical `services:*` wrappers (`services:validate:*`, `services:record:*`, `services:rollback:*`, `services:evidence:*`) that route to `infra:*`; `taskfiles/services-legacy.yml` is the deprecated wildcard-alias layer (`switch:*`, `boot:*` — a Task `aliases:` entry cannot carry `*`).
- Rebuild flags have exactly one home: `scripts/task/rebuild-flags.sh` renders
  builders / substitutes / flakes and nothing else, so a switch task states the host and
  the flake ref, never a flag. [[flake/policies.nix#rebuild-flags-are-finite]]
- `taskfiles/data.yml` is the canonical NAS surface (`data:*`) for the `/Volumes/data` taxonomy, hygiene, permissions and the portable tool library.
- `taskfiles/lifecycle.yml` owns host commissioning and decommissioning (`lifecycle:*`), which is provisioning a host, not operating one.
- `taskfiles/mail.yml` owns forwarding aliases on the ImprovMX domain (`mail:*`): a disposable address per service, its declared expiry in `modules/config/mail-aliases.toml`, and the drift check between the two. It needs the network and a sops key, so it is operator surface, never a build gate.
- **Format convention:** taskfiles are YAML (`task` reads nothing else), inventories are TOML (`checks.toml`, `modules.toml`, `inventory.toml`, `closure-budgets.toml` — parsed by `builtins.fromTOML`), and machine manifests are JSON (`site-manifest.json`, read by `scripts/task/site-target.sh`). One format per role; there is no second parser to keep honest.
- **When a new shard is warranted:** a taskfile owns one `namespace:*` over one domain (a host family, a service, a plane). Add a file when the namespace is new *and* has a script or skill behind it; add a task to an existing shard when the namespace already exists. An include-only aggregator is never a file — `Taskfile.yml` lists every shard directly, so the include graph is the ownership map. [[flake/policies.nix#taskfiles-include-is-ownership]]
- The task surface is also the **edge caller's tool set**: `agents:call` derives its tools
  from `scripts/task/lib/taskfile_graph.py by-name`, so a callable verb is a task, not a second registry. Read-only
  verbs prefetch on any validated call (TOON out), the graph repairs the argument's type,
  `ops:ask` answers when the call names nothing, and a reasoning model is the *last* hop.
  [[flake/policies.nix#edge-caller-before-reasoning]]
- **Which quadrant goes where** (`agents:call` emits it as `pareto:`): small and
  non-reducible → needle3, a lookup; reducible → `decompose`, refused before the engine so
  no tool can half-answer it; large (a judgement, an operation, or a task whose body can
  build) → `reason`, and such a task is never on the surface at all.
- `taskfiles/ops.yml` owns observation and the context plane: `ops:health`, `ops:ledger[:toon]`, `ops:sentinel:*`, `ops:skills*`, `ops:kg*`, `ops:ask[:jev]`, `ops:q`, `ops:context`, `ops:docs:budget`, `ops:bench:evals`, `ops:bench:kg`. These read a live system or a compiled artifact; they are not build gates.

## File-by-file map
- `Taskfile.yml` – entrypoint with top-level menus
- `taskfiles/infra.yml` – host lifecycle, secrets, SOPS operations, and the detached job runner (`infra:job:*`, implemented by `scripts/task/job.sh`)
- `taskfiles/agents.yml` – operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml` – validation and smoke checks (incl. `checks:tasks` task-graph gate, `checks:host`, `checks:flake:transitive`)
- `taskfiles/codespace.yml` – GitHub Codespaces over `gh cs ssh` (list, exec, file transport, repo-matched push, sync, stop, delete), implemented by `scripts/task/codespace.sh`
- `taskfiles/dev.yml` – git workflows, flake updates, site deployment, and the generated docs pipeline (`docs:build` / `docs:site` / `docs:sync`)
- `taskfiles/moto.yml` – Motorola Android (Termux) shell, file transfers, and Charmbracelet Wish/Gum menu
- `taskfiles/neocities.yml` – dragoncourt.neocities.org: gum post authoring (new/edit/publish/draft/delete), listing + feed render, preview and deploy
- `taskfiles/serv00.yml` – Serv00 FreeBSD hosting, Devil CLI, webserver lifecycle (jisifu.serv00.net), and Gum menu
- `taskfiles/dragoncourt.yml` – Alwaysdata Debian hosting, PHP/Wasm webserver (dragoncourt.alwaysdata.net), and Gum menu
- `taskfiles/envs.yml` – Envs.net Debian hosting, public_html / Gemini / Gopher, build pipeline (jisifu.envs.net), the git.envs.net forge (`envs:git:*`, implemented by `scripts/task/gitenvs.sh`), and Gum menu
- `taskfiles/pythonanywhere.yml` – PythonAnywhere Flask CMS (jisifu.pythonanywhere.com) over the REST API: health reload logs, single-file push/pull — no ssh
- `taskfiles/bountystash.yml` – Bountystash Console (<14KB TCP budget), preview & Cloudflare Pages deployment, and Gum menu
- `taskfiles/burgernas.yml` – Synology DS220j cold vault (BurgerNAS): WoL power, restic backup target, leech-only Transmission, aria2/AriaNg, and Gum menu
- `taskfiles/apps.yml` – Job application workflow via `bin/appflow` (status updates, email radar, Typst builds, three-way sync, GitHub push/pull)
- `taskfiles/bitlockerpremium.yml` – Windows 11 Pro (HP EliteBook 830 G7) over Tailscale OpenSSH, Scoop/Nushell shells, file transfers, and Gum menu
- `taskfiles/deals.yml` – deal cards off a rendered board (`deals:page`) and their pipe into private-deals (`deals:ingest`)
- `taskfiles/data.yml` – NAS storage taxonomy and hygiene, permissions, media unindexing, portable tool library (`data:*`)
- `taskfiles/lifecycle.yml` – commissioning a new host, decommission audit and cleanup (`lifecycle:*`)
- `taskfiles/mail.yml` – ImprovMX forwarding aliases: temporary per-service addresses, expiry pruning, registry drift (`mail:*`), implemented by `scripts/task/mail-alias.sh`
- `taskfiles/ops.yml` – sentinel/ledger, compiled skill index, knowledge graph, document budgets, eval benchmarks
- `taskfiles/services-core.yml` – canonical `services:*` wrappers routed to `infra:*`
- `taskfiles/services-legacy.yml` – deprecated wildcard aliases (`switch:*`, `boot:*`)

## Truth boundaries
- `taskfiles/site-manifest.json` is the site/static deployment metadata source; query it through `scripts/task/site-target.sh` or `dev:site:*` wrappers.
- `lib/docs.nix` owns every generated doc page and the docs-tree layout: pages come from the compiled `.#inventory` and `modules.toml`, and `nix build .#artifacts.docs` is the ONLY copy (nothing generated is committed). The rendered site is `lib/aki-site.nix` (`task docs:site`), whose navigation is compiled from the knowledge graph.
- `scripts/task/*` are helper implementations only.
- `AGENTS.md` and `.agents/*` document routing/guidance; they do not execute.

## Common "where to look"
- Host deployment/lifecycle → `taskfiles/infra.yml` (`infra:*`)
- A rebuild or any long task → `task infra:job:start RUN=<task>`, then `infra:job:status` for its exit code
- Operator helpers → `taskfiles/agents.yml` (`agents:menu`, legacy menus)
- Validation checks → `taskfiles/checks.yml` (`checks:*`)
- A GitHub Codespace → `taskfiles/codespace.yml` (`codespace:*`), procedure in `.agents/skills/codespace`
- Observation, skills, knowledge graph → `taskfiles/ops.yml` (`ops:*`)
- Git/flake workflows, site deployment → `taskfiles/dev.yml` (`dev:*`)
- NAS storage taxonomy, hygiene, permissions, tool library → `taskfiles/data.yml` (`data:*`)
- Commissioning or retiring a host → `taskfiles/lifecycle.yml` (`lifecycle:*`)
- Moto (Termux) operations & transfer → `taskfiles/moto.yml` (`moto:*`)
- Serv00 FreeBSD hosting & webserver → `taskfiles/serv00.yml` (`serv00:*`)
- Alwaysdata Debian hosting & webserver → `taskfiles/dragoncourt.yml` (`dragoncourt:*`)
- Envs.net Debian hosting & webserver → `taskfiles/envs.yml` (`envs:*`)
- PythonAnywhere Flask CMS over the REST API → `taskfiles/pythonanywhere.yml` (`pythonanywhere:*`)
- Windows 11 workstation over Tailscale OpenSSH → `taskfiles/bitlockerpremium.yml` (`bitlockerpremium:*`)
- Bountystash Console & Cloudflare Pages → `taskfiles/bountystash.yml` (`bountystash:*`)
- BurgerNAS cold vault (Synology DS220j) & Transmission → `taskfiles/burgernas.yml` (`burgernas:*`)
- Job application pipeline, email flow & sync → `taskfiles/apps.yml` (`apps:*`)
- Legacy compatibility → `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml`

## What not to assume
- Don't assume `Taskfile.yml` contains the lifecycle logic—open the individual taskfiles instead.
- Don't treat `.agents/*` as executable truth; tasks still live in the Taskfiles.
- Don't use `services:*` tasks for new workflows; prefer canonical `infra:*` or `dev:*` namespaces.