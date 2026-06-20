---
name: dev
description: Development workflows — git operations, flake updates, site deployment, PR management, packages, and formatting. Derived from taskfiles/dev.yml.
---

# dev — Development Workflows

Git, flake, site deployment, PR management, and package workflows.

## Git operations

| Task | Description |
|------|-------------|
| `dev:git:quick-push` | Commit/push with AI commit message (gmc) |
| `dev:git:quick-push-safe` | Same with auto-stash/restore |
| `dev:git:build-push` | Commit/push after successful build |
| `dev:git:ai-commit` | Stage tracked + interactive AI commit |
| `dev:git:ai-commit-push` | Stage tracked + AI commit + push |
| `dev:git:quick-pull` | Pull with submodules + reload Taskfile |
| `dev:git:prehook` | Refresh Taskfile from secrets + stage |
| `dev:git:posthook` | Push current branch (with error handling) |
| `dev:git:status` | Show branch, status, stashed changes |
| `dev:git:stash-push` | Stash with message |
| `dev:git:stash-pop` | Pop most recent stash |

## Flake management

| Task | Description |
|------|-------------|
| `dev:flake:update-branch` | Create/force-push update branch |
| `dev:flake:merge-update` | Merge update branch into main |
| `dev:flake:update-complete` | Full update workflow in one command |
| `dev:flake:update:bountystash` | Update only bountystash input |
| `dev:flake:get-hosts` | List nixosConfigurations hostnames |
| `dev:flake:update-garnix` | Sync garnix.yaml with current hosts |

## Site deployment

| Task | Description |
|------|-------------|
| `dev:site:list` | List targets from site-manifest.json |
| `dev:site:show:<target>` | Show target metadata |
| `dev:site:build:<target>` | Build target |
| `dev:site:preview:<target>` | Preview target |
| `dev:site:deploy:<target>` | Deploy target |
| `dev:site:build` | Build default target |
| `dev:site:preview` | Preview default target |
| `dev:site:deploy` | Deploy default target |

Uses `scripts/task/site-target.sh`. Source of truth: `taskfiles/site-manifest.json`.

## Package management

| Task | Description |
|------|-------------|
| `dev:pkgs:list` | List custom packages from flake |
| `dev:pkgs:update:<pkg>` | Update package version/hash |
| `dev:config:hash-update` | Refresh sha256 for config/*.json files |

## Pull requests

| Task | Description |
|------|-------------|
| `dev:pr:list` | List open PRs (by @me or all) |
| `dev:pr:create` | Create PR from current branch (opens browser) |
| `dev:pr:checkout:<num>` | Checkout PR by number |
| `dev:pr:review:<num>` | Review/approve PR in browser |
| `dev:pr:status` | CI status for current branch |

## Formatting

| Task | Description |
|------|-------------|
| `dev:fmt` | Format all Nix files with alejandra in-place |
