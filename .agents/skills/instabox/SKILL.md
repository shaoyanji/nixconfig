---
name: instabox
description: "Pick me to reach an InstaBox machine without their CLI: the API key in sops, an SSH token minted through the API, and `exec` when no ssh is needed."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Buffy
platforms: [linux]
metadata:
  hermes:
    tags: ['instabox', 'vps', 'ssh', 'api', 'builder', 'agent-vm']
    related_skills: ['codespace', 'infra', 'tmux']
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

## What is on the box

Measured 2026-11-06 on `clanker`: `docker`, `go`, `node`, `python3`, `git` are
present; **no nix, no nix-shell, no rsync**. A nix build there means installing
Nix first (a daemon and a store, i.e. the dependency the fleet does not want on
an ephemeral VM) — for fleet builds the answer stays `task dev:ci:trigger:<host>`
or `task infra:warm:*`, and this box is for the work that is not a closure
(an agent session, a container, a Go or Node build).
