---
name: dev
description: "Git, flake updates, site deploy, PRs, packages."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['dev', 'git', 'flake', 'site']
    related_skills: []
---

# dev — what the descriptions leave out

80 `dev:*` tasks, each with a `desc`:

```bash
task --list-all --json | jq -r '.tasks[] | select(.name|startswith("dev:")) | "\(.name)\t\(.desc)"'
```

This page keeps only the four traps that a description cannot warn about.

## Git

- `quick-push` commits **and** pushes. `build-push` commits and does **not** push,
  despite the name. `ai-commit` is interactive, `ai-commit-push` adds the push,
  `quick-push-safe` stashes and restores around it.
- Prefer `dev:git:stage` over `git add -A`: it warns when the staged set includes
  a `.sops.yaml` recipient drift, the one change that silently breaks a host's
  decryption.

## Flake

`update-complete` is the whole workflow (branch, update, merge). Use
`update-branch` + `merge-update` when you want to read the lock diff first, and
`update-transitive` for pins a root update misses. After adding a host,
`dev:flake:update-garnix` syncs `garnix.yaml` or CI never builds it.

## Site — two different sites

`dev:site:*` publishes from `taskfiles/site-manifest.json` (via
`scripts/task/site-target.sh`); its `list`/`show`/`preview`/`deploy` name a target
from that file. The **fleet docs site** is not in it: that is `task docs:site`
(`.#fleet-docs-site`) and `task docs:build` (`.#docs`).

## Closure analysis is not verification

`dev:closure:*` reads the store DB to answer "what is big, what will be fetched".
It proves nothing about correctness, so it is build preparation — pair it with a
build, never use it instead of one. `dev:fmt` is `checks:nix:fix`; `nixpkgs-fmt`
is not installed and would rewrite most of the tree.

Truth: `taskfiles/dev.yml` — the executable contract; this page is the procedure.
