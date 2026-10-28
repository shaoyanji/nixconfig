# Taskfile Map

## Scope
Quick reference to who owns each taskfile and where to go for lifecycle, deployment, and operator queries.

## Canonical ownership
- `Taskfile.yml` is the entrypoint; it loads the shards and hosts top-level helper menus (`deploy`, `logs`, `status`, `menu`).
- `taskfiles/infra.yml` is the canonical host lifecycle surface (`infra:*`) for plan/apply/deploy/rollback/logs and secrets management, and it owns the detached job surface (`infra:job:*`) that long tasks are started through.
- `taskfiles/agents.yml` holds operator helpers, xs runtime wrappers, and OAuth/session management.
- `taskfiles/checks.yml` contains validation and health checks (host evals, Nix lint/format, sops drift, flake transitive-input sweep).
- `taskfiles/dev.yml` contains git/flake/local helper workflows, including site build/preview/deploy tasks.
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` provide legacy compatibility wrappers routing to canonical `infra:*` tasks.
- `taskfiles/data.yml` is the canonical NAS surface (`data:*`) for the `/Volumes/data` taxonomy, hygiene, permissions and the portable tool library.
- `taskfiles/lifecycle.yml` owns host commissioning and decommissioning (`lifecycle:*`), which is provisioning a host, not operating one.
- `taskfiles/services.yml` is an include-only aggregator: it flattens `services-core.yml` and `services-legacy.yml` and declares no tasks of its own.
- `taskfiles/ops.yml` owns observation and the context plane: `ops:health`, `ops:ledger[:toon]`, `ops:sentinel:*`, `ops:skills*`, `ops:kg*`, `ops:ask[:jev]`, `ops:context`, `ops:docs:budget`, `ops:bench:evals`, `ops:bench:kg`. These read a live system or a compiled artifact; they are not build gates.

## File-by-file map
- `Taskfile.yml` – entrypoint with top-level menus
- `taskfiles/infra.yml` – host lifecycle, secrets, SOPS operations, and the detached job runner (`infra:job:*`, implemented by `scripts/task/job.sh`)
- `taskfiles/agents.yml` – operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml` – validation and smoke checks (incl. `checks:tasks` task-graph gate, `checks:host`, `checks:flake:transitive`)
- `taskfiles/dev.yml` – git workflows, flake updates, site deployment, and the generated docs pipeline (`docs:build` / `docs:site` / `docs:sync`)
- `taskfiles/moto.yml` – Motorola Android (Termux) shell, file transfers, and Charmbracelet Wish/Gum menu
- `taskfiles/serv00.yml` – Serv00 FreeBSD hosting, Devil CLI, webserver lifecycle (jisifu.serv00.net), and Gum menu
- `taskfiles/dragoncourt.yml` – Alwaysdata Debian hosting, PHP/Wasm webserver (dragoncourt.alwaysdata.net), and Gum menu
- `taskfiles/envs.yml` – Envs.net Debian hosting, public_html / Gemini / Gopher, build pipeline (jisifu.envs.net), and Gum menu
- `taskfiles/bountystash.yml` – Bountystash Console (<14KB TCP budget), preview & Cloudflare Pages deployment, and Gum menu
- `taskfiles/burgernas.yml` – Synology DS220j cold vault (BurgerNAS): WoL power, restic backup target, leech-only Transmission, aria2/AriaNg, and Gum menu
- `taskfiles/apps.yml` – Job application workflow via `bin/appflow` (status updates, email radar, Typst builds, three-way sync, GitHub push/pull)
- `taskfiles/bitlockerpremium.yml` – Windows 11 Pro (HP EliteBook 830 G7) over Tailscale OpenSSH, Scoop/Nushell shells, file transfers, and Gum menu
- `taskfiles/data.yml` – NAS storage taxonomy and hygiene, permissions, media unindexing, portable tool library (`data:*`)
- `taskfiles/lifecycle.yml` – commissioning a new host, decommission audit and cleanup (`lifecycle:*`)
- `taskfiles/services.yml` – include-only aggregator for `services-core.yml` + `services-legacy.yml` (no tasks declared here)
- `taskfiles/ops.yml` – sentinel/ledger, compiled skill index, knowledge graph, document budgets, eval benchmarks
- `taskfiles/services-core.yml` – minimal compatibility wrappers
- `taskfiles/services-legacy.yml` – deprecated aliases (marked `[deprecated]`)

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
- Observation, skills, knowledge graph → `taskfiles/ops.yml` (`ops:*`)
- Git/flake workflows, site deployment → `taskfiles/dev.yml` (`dev:*`)
- NAS storage taxonomy, hygiene, permissions, tool library → `taskfiles/data.yml` (`data:*`)
- Commissioning or retiring a host → `taskfiles/lifecycle.yml` (`lifecycle:*`)
- Moto (Termux) operations & transfer → `taskfiles/moto.yml` (`moto:*`)
- Serv00 FreeBSD hosting & webserver → `taskfiles/serv00.yml` (`serv00:*`)
- Alwaysdata Debian hosting & webserver → `taskfiles/dragoncourt.yml` (`dragoncourt:*`)
- Envs.net Debian hosting & webserver → `taskfiles/envs.yml` (`envs:*`)
- Windows 11 workstation over Tailscale OpenSSH → `taskfiles/bitlockerpremium.yml` (`bitlockerpremium:*`)
- Bountystash Console & Cloudflare Pages → `taskfiles/bountystash.yml` (`bountystash:*`)
- BurgerNAS cold vault (Synology DS220j) & Transmission → `taskfiles/burgernas.yml` (`burgernas:*`)
- Job application pipeline, email flow & sync → `taskfiles/apps.yml` (`apps:*`)
- Legacy compatibility → `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml`

## What not to assume
- Don't assume `Taskfile.yml` contains the lifecycle logic—open the individual taskfiles instead.
- Don't treat `.agents/*` as executable truth; tasks still live in the Taskfiles.
- Don't use `services:*` tasks for new workflows; prefer canonical `infra:*` or `dev:*` namespaces.