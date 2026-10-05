# Taskfile Map

## Scope
Quick reference to who owns each taskfile and where to go for lifecycle, deployment, and operator queries.

## Canonical ownership
- `Taskfile.yml` is the entrypoint; it loads the shards and hosts top-level helper menus (`deploy`, `logs`, `status`, `menu`).
- `taskfiles/infra.yml` is the canonical host lifecycle surface (`infra:*`) for plan/apply/deploy/rollback/logs and secrets management.
- `taskfiles/agents.yml` holds operator helpers, xs runtime wrappers, and OAuth/session management.
- `taskfiles/checks.yml` contains validation and health checks (host evals, Nix lint/format, sops drift, flake transitive-input sweep).
- `taskfiles/dev.yml` contains git/flake/local helper workflows, including site build/preview/deploy tasks.
- `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml` provide legacy compatibility wrappers routing to canonical `infra:*` tasks.

## File-by-file map
- `Taskfile.yml` – entrypoint with top-level menus
- `taskfiles/infra.yml` – host lifecycle, secrets, SOPS operations
- `taskfiles/agents.yml` – operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml` – validation and smoke checks (incl. `checks:flake:transitive`)
- `taskfiles/dev.yml` – git workflows, flake updates, site deployment
- `taskfiles/moto.yml` – Motorola Android (Termux) shell, file transfers, and Charmbracelet Wish/Gum menu
- `taskfiles/serv00.yml` – Serv00 FreeBSD hosting, Devil CLI, webserver lifecycle (jisifu.serv00.net), and Gum menu
- `taskfiles/dragoncourt.yml` – Alwaysdata Debian hosting, PHP/Wasm webserver (dragoncourt.alwaysdata.net), and Gum menu
- `taskfiles/envs.yml` – Envs.net Debian hosting, public_html / Gemini / Gopher, build pipeline (jisifu.envs.net), and Gum menu
- `taskfiles/bountystash.yml` – Bountystash Console (<14KB TCP budget), preview & Cloudflare Pages deployment, and Gum menu
- `taskfiles/services-core.yml` – minimal compatibility wrappers
- `taskfiles/services-legacy.yml` – deprecated aliases (marked `[deprecated]`)

## Truth boundaries
- `taskfiles/site-manifest.json` is the site/static deployment metadata source; query it through `scripts/task/site-target.sh` or `dev:site:*` wrappers.
- `scripts/task/*` are helper implementations only.
- `AGENTS.md` and `.agents/*` document routing/guidance; they do not execute.

## Common "where to look"
- Host deployment/lifecycle → `taskfiles/infra.yml` (`infra:*`)
- Operator helpers → `taskfiles/agents.yml` (`agents:menu`, legacy menus)
- Validation checks → `taskfiles/checks.yml` (`checks:*`)
- Git/flake workflows, site deployment → `taskfiles/dev.yml` (`dev:*`)
- Moto (Termux) operations & transfer → `taskfiles/moto.yml` (`moto:*`)
- Serv00 FreeBSD hosting & webserver → `taskfiles/serv00.yml` (`serv00:*`)
- Alwaysdata Debian hosting & webserver → `taskfiles/dragoncourt.yml` (`dragoncourt:*`)
- Envs.net Debian hosting & webserver → `taskfiles/envs.yml` (`envs:*`)
- Bountystash Console & Cloudflare Pages → `taskfiles/bountystash.yml` (`bountystash:*`)
- Legacy compatibility → `taskfiles/services-core.yml` and `taskfiles/services-legacy.yml`

## What not to assume
- Don't assume `Taskfile.yml` contains the lifecycle logic—open the individual taskfiles instead.
- Don't treat `.agents/*` as executable truth; tasks still live in the Taskfiles.
- Don't use `services:*` tasks for new workflows; prefer canonical `infra:*` or `dev:*` namespaces.