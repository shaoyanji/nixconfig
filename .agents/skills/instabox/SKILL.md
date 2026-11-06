---
name: instabox
description: "Pick me to reach an InstaBox machine without their CLI, and to use clanker as the fleet's offload box: the API key in sops, an SSH token minted through the API, `exec` when no ssh is needed, and detached jobs for background builds."
version: 0.2.0
author: Shaoyan Ji (shaoyanji), Buffy
platforms: [linux]
metadata:
  hermes:
    tags: ['instabox', 'vps', 'ssh', 'api', 'builder', 'agent-vm', 'offload']
    related_skills: ['codespace', 'infra', 'tmux', 'task-plane']
---

# instabox — machines over HTTP and plain ssh

| | |
| :--- | :--- |
| Surface | `task instabox:*` (`taskfiles/instabox.yml`) |
| Implementation | `scripts/task/instabox.sh` — `curl`, `jq`, `ssh` |
| Key | `INSTABOX.API.KEY` in `modules/secrets/apikeys.yaml` (`INSTABOX_API_KEY` overrides) |
| API | `https://api.instabox.sh`, header `X-API-Key: ibk_…` |
| `clanker` | `m_agq3fp4qk6ohhviucwvdizryk4` — 4 vCPU (EPYC), 8 GiB, 20 GiB on `/data`, user `user` with sudo + docker |

Nothing here installs the provider CLI. It is a Node/TypeScript program with a
login, a config directory and a wholesale dependency tree; every call this skill
makes is one HTTP request, and everything is already in the closure (`curl`,
`jq`, `openssh`) or in sops.

## The three transports, narrowest first

1. **`exec` — one API call, no ssh.** `task instabox:exec -- clanker 'nproc'`.
   Returns stdout, stderr and the command's exit status; mints nothing and needs
   no `known_hosts`. This is the path for an unattended agent.
2. **`ssh` — a real shell.** `task instabox:ssh -- clanker`, or
   `task instabox:ssh -- clanker 'uname -a'`. Use it for an interactive session, a
   pty, or a port forward.
3. **`token` — print the ssh line** for a tool that cannot read sops. The line
   *is* the credential (see below), so treat it as a password.

## SSH without their CLI

The gateway terminates SSH, so a connection is `ssh -p <port> <token>@<host>`
with a token as the login — no key is placed on the machine and no config block
is maintained. Mint one with the API:

```bash
curl -sS -H "X-API-Key: $INSTABOX_API_KEY" -H 'Content-Type: application/json' \
  -d '{"name":"fleet-agent","ttlSeconds":604800}' \
  https://api.instabox.sh/v1/machines/<m_…>/ssh-tokens | jq -r .command
```

Reference: <https://instabox.sh/docs/api-reference/connections/issue-an-ssh-token-for-a-plain-%60ssh%60-command-without-a-key>.
The script caches that reply in `~/.cache/nixconfig-instabox/<id>.ssh.json`
(mode 0600) and re-mints two minutes before expiry, so an ssh costs one API call
a week rather than one a connection. `DELETE /v1/machines/<id>/ssh-tokens`
revokes every token of the machine at once.

The gateway's host key is what a first connection asks to confirm; the script
pins it with `StrictHostKeyChecking=accept-new` into a cache `known_hosts`
instead of a prompt that would hang an unattended run.

## Traps that cost a run

- **`name` is for people, `m_…` is for the API.** Every path takes the id; the
  script resolves a name by listing the workspace, so a renamed machine is one
  wrong answer, not a silent create.
- **The run clock is a hard stop.** `autoSuspendAfterSeconds` is 1800 and
  `maxRunMinutes` 120 on this workspace: a build that outlives the window is
  suspended mid-flight. Check `instabox:get NAME | jq -r .state` before blaming
  the command, and keep long work restartable.
- **`wake` is not `resume`.** An auto-suspended machine wakes; a stopped one
  starts. A machine that answered 404 may simply be in another workspace — a key
  reaches only its own, and another workspace's machine is indistinguishable
  from a missing one.
- **Delete needs a confirmation header** on keys minted after the rollout
  (`409 delete_confirmation_required`). This skill never deletes.
- **Commands are one shell string** (`bash -lc`), so a quote-sensitive command
  belongs in a file on the machine, not inline.

## clanker as a job box (`task clanker:*`)

`clanker` is a permanent fleet fixture as of 2026-11-06 (plan:
`AGENTS.nix` note `clanker-offload-fixture`), driven by
`scripts/task/clanker.sh`. It is a 4 vCPU / 8 GiB Instabox VM, so it takes the
work that is measured in minutes and has a result to copy back — not state.

| What | How |
| :--- | :--- |
| One-time bring-up | `task clanker:up` — single-user Nix at `$HOME/.nix-profile`, `nix.conf` with the fleet substituters, `max-jobs = 4`, `cores = 1`, `sandbox = false` |
| The toolbox | `task clanker:profile` — sends the tree, builds `.#homeConfigurations.clanker` (`role:lean`: git, gh, go, go-task, ripgrep, jq, yq, tmux, direnv, rsync, shellcheck) and runs the generation's own `activate` |
| A closure build | `task clanker:nix -- '.#hostChecks.x86_64-linux.fern' --wait` |
| A Go binary | `task clanker:go -- ./modules/services/turns-dashboard --wait` |
| Anything else | `task clanker:job -- '<cmd>'`, then `clanker:wait`, `clanker:logs`, `clanker:result` |

**The job is a directory**, not a process: `/data/jobs/<id>/{cmd.sh,log,exit}`. The
wrapper writes `exit` last, so the *absence* of `exit` is what "running" means — a
pid file would go stale across the suspend the box does to itself. `setsid` starts
it, so closing the ssh channel does not kill it; the 120-minute run clock does, and
that is why long work is written to resume from its log.

**The tree travels as `git archive HEAD`**, so a build uses the last commit, not
what is in your working tree. Commit first, or the box builds yesterday.

**No credential goes there that can write to a cache.** Measured 2026-11-06: a
build on clanker warms nothing, because the box holds no cachix or R2 key, and a
result comes back only through `clanker:result` (a tar, since the image has no
rsync). Giving it one is a deliberate temporary exception, never a default.

## What is on the box

Measured 2026-11-06 on `clanker`, after `clanker:up` + `clanker:profile`: Ubuntu,
4 vCPU / 8 GiB, home `$HOME=/data/home` (on the `/data` disk — activation refuses
any other `homeDirectory`), single-user Nix at `/data/home/.nix-profile` with a
3.3 GiB store, and the lean profile's `gh`, `go`, `go-task`, `jq`, `yq`, `tmux`,
`ripgrep`, `rsync`, `direnv`. **`rsync` exists only through the profile** — the
image itself ships docker, go, node and python3 but no rsync and no nix.
