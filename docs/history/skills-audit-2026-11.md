# Skills audit: November 2026

Full census of `.agents/skills/` (63 skills) taken during the tmux-skills-audit
turn. Method: mechanical pass (frontmatter + description present, repo-path
references resolve) followed by hand verification of every candidate failure —
skill-relative paths, submodule paths, host runtime paths, template
placeholders, glob patterns, and external-project paths are *not* broken refs.
Decisions: `KEEP` as-is, `MERGE` into another skill, `DELETE`, `REWRITE`.

## What the gates already enforce

`skills-schema` (lib/skills.nix) requires frontmatter + description; the
cites-truth rule requires every skill to name at least one resolvable repo path
or policy citation; `#agent-prose-budget` pins each body to a measured line
count. The audit's job was the drift those gates cannot see: a *second* stale
ref next to a resolving one, a tool removed from the closure, a dead task name.

## Findings — all fixed in the same commit

- `agents` cited `scripts/task/service-oauth.sh`, deleted in 6cc689f8; OAuth is
  now per-skill (`calendar`/`google-drive` scripts) — line rewritten.
- `dev` cited `dev:flake:update-garnix`/`garnix.yaml`; garnix was dropped in
  d5b7baa2 and the task's `yq -i` on a missing file plus `git add garnix.yaml`
  made `dev:flake:update`/`update-complete` fail outright — task removed, call
  sites strip `garnix.yaml`, skill line rewritten.
- `tmux` Truth line cited `modules/shell/base.nix`; tmux enables in
  `modules/shell/default.nix` — fixed.
- `pdfvision`/`parallel-cli` document tools slashed from the closure in
  430d3f68 — kept (procedures stay valid; both tools fetch ad-hoc via
  `nix shell github:numtide/llm-agents.nix#…`), with a not-installed note added.
- `crush` tombstone carried a dangling `related_skills: [hermes-agent]` — no
  such skill exists; dropped.

Verified false positives: `apikeys.yaml` lives in the secrets submodule by
design (no committed mirror); `stt`/`voice-loop`/`atuin`/`calendar`/
`google-drive` scripts are skill-relative; `lib/*` hits were `/var/lib/*` host
paths; `bountystash`/`envs` scripts belong to their external project repos;
`<host>`/`<job>` are templates; `modules/services/thing.nix` is an example.

## Table

| skill | decision | note |
| --- | --- | --- |
| agent-browser | KEEP | browser automation; `pdfvision` hand-off line stays valid (ad-hoc fetch) |
| agents | KEEP | `service-oauth.sh` ref fixed to per-skill auth scripts |
| agents-notes | KEEP | `thing.nix` is a placeholder example, not a real ref |
| ai-memory | KEEP | memory layer, documented in `.#memoryLayers` |
| antigravity | KEEP | updated last commit (on-demand `nix run` convention) |
| apisfreellm | KEEP | external free-API surface |
| apps | KEEP | job-application pipeline, task-backed |
| atuin | KEEP | `atuin-bootstrap.sh` is skill-relative |
| bountystash | KEEP | `scripts/*` live in the bountystash repo, not nixconfig |
| brainstorm | KEEP | divergence discipline, AGENTS.nix note exit |
| burgernas | KEEP | NAS ops, task-backed |
| calendar | KEEP | skill-local `calendar-auth.sh` exists |
| checks | KEEP | phase-discipline skill; `scripts/task/*.sh` glob resolves |
| codespace | KEEP | codespace workflow |
| confirm-before-destructive | KEEP | shared policy; `parallel-cli` example still fetchable |
| correct | KEEP | repeat-mistake gate ladder |
| cpg | KEEP | chatplayground lanes |
| crush | KEEP | deliberate tombstone; dangling `hermes-agent` ref dropped |
| data | KEEP | storage taxonomy |
| dev | KEEP | dead garnix task removed; skill line fixed |
| dragoncourt | KEEP | alwaysdata hosting |
| eisen-status | KEEP | read-only LLM-stack probe |
| envs | KEEP | `publish.sh` belongs to the envs project repo |
| fleet-sentinel | KEEP | `/var/lib/fleet-sentinel` is a host path |
| frieren-offload | KEEP | `lib/<job>` is a template placeholder |
| google-drive | KEEP | skill-local `drive-auth.sh` exists |
| home-assistant | KEEP | frieren HA/MQTT control |
| host-facts | KEEP | `<host>` templates resolve to generated docs at query time |
| image-generate | KEEP | Eisen image endpoint |
| infra | KEEP | deploy/rollback runbook |
| instabox | KEEP | `apikeys.yaml` = secrets-submodule path, correct by design |
| iventoy | KEEP | PXE ops on frieren |
| jevdecide | KEEP | decision routing |
| knowledge-base | KEEP | `.agents/notes` is the runtime notes dir |
| mail-alias | KEEP | `apikeys.yaml` submodule path, correct |
| mail-archive | KEEP | `*.sql` globs resolve under existing module dirs |
| master-toon | KEEP | `ledger.jsonl` is a host path |
| microvm | KEEP | delphi/frieren guests |
| moto | KEEP | Termux over tailscale |
| neocities | KEEP | `apikeys.yaml` submodule path, correct |
| nix-eval | KEEP | eval-cost ladder |
| nixos-deploy | KEEP | deploy procedure |
| no-comments | KEEP | comment-census rationale |
| officecli | KEEP | `related_skills: [pdfvision]` valid |
| ontology | KEEP | kg node/edge discipline |
| parallel-cli | KEEP | tool slashed from closure; not-installed note added |
| paste | KEEP | `/var/lib/paste` is a host path |
| pdfvision | KEEP | tool slashed from closure; not-installed note added |
| philips-tv-cast | KEEP | TV casting procedure |
| prove-it-works | KEEP | verification gate discipline |
| qmd | KEEP | knowledge-store CLI |
| reasonix | KEEP | Tier-3 model runner, live dispatch route |
| router | KEEP | intent-shape front door |
| serv00 | KEEP | serv00 hosting |
| services | KEEP | legacy redirect pointer to `taskfiles/services.yml` |
| simplex-admin | KEEP | thin pointer to `modules/user/ai/skills/simplex-admin` (canonical) |
| stt | KEEP | `stt.sh` is skill-relative |
| task-plane | KEEP | taskfile discipline; `lib/*.nix` glob resolves |
| tmux | KEEP | name-addressed capture surface added this turn; `base.nix` ref fixed |
| unslop | KEEP | prose-vocabulary gate |
| voice-loop | KEEP | scripts are skill-relative |
| wikisearch | KEEP | `/var/lib/kiwix` host paths |
| xs-turns | KEEP | turn-log discipline |

**Totals: 63 KEEP, 0 MERGE, 0 DELETE, 0 REWRITE.** No merge or delete earned:
the two thin pointers (`services`, `simplex-admin`) route queries rather than
duplicate content; the slashed-tool skills document procedures that stay valid
under ad-hoc fetch; the only dead code was references, and references are what
this commit repairs. A separate skill registry lives at
`modules/user/ai/skills/` (hermes-side, 6 skills) — outside `.agents/skills`
scope, pointed at by `simplex-admin`.
