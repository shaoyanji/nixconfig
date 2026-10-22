---
name: infra
description: "Host lifecycle: plan, apply, deploy, rollback, logs."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['infra', 'host', 'lifecycle', 'deploy']
    related_skills: []
---

# infra — host lifecycle, and the caveats `desc` cannot carry

`task find:<word>` finds these by name and `task --list-all --json` gives the
whole set with descriptions, so this page lists only what the description does
not say. Cost tiers, what each gate proves and the build-budget rules live in
`task-plane` and `AGENTS.md`; do not re-derive them here.

## Remote hosts

| Task | What the description omits |
| :--- | :--- |
| `infra:deploy:host:<h>` | gate → plan → apply → validate in one run. For ONE host you have decided to change, not a fleet pass. A `preserved` host warns and exits 0 before any ssh (revive with `ALLOW_PRESERVED=1`). |
| `infra:plan:host:<h>` | substitutes the closure, applies nothing. The pre-build instrument. |
| `infra:apply:host:<h>` | assumes the closure is already built and cached; no gate. |
| `infra:rollback:host:<h>` | remote generation switch. `:apply` alone re-runs just that step when the first half landed. |
| `infra:logs:host:<h>` | `UNIT=` defaults to `go-backend`, except on netbook, whose variant follows the whole journal when `UNIT` is empty. |
| `infra:wol:eisen` | magic packet; eisen is asleep unless woken. |

Never build *on* the target host: `infra:warm:host:<h>` on the builder (or
`dev:ci:trigger:<h>`), then `checks:build:route` to confirm the cache serves it.
The reasoning and the measurements are in `AGENTS.md` (*Agent Verification
Protocol*).

## Local rebuilds

`infra:rebuild:{nixos,darwin,home-manager}` switch this machine; the switch is
the build and the check, so run no gate first. `infra:rebuild:{wsl,orb}` exist for
guckloch (WSL2) and OrbStack, which are not `nixos-rebuild` hosts.
`infra:boot:<os>` runs `<os>-rebuild boot`: it writes the next generation into the
bootloader without switching, which is how you stage a change that only proves
itself at boot (and the only honest way to test one).

## Store maintenance

`infra:store:gc` frees paths no root references. `infra:store:collect-garbage` is
`nix-collect-garbage -d`: it deletes every old generation, so every rollback
target goes at once. The weekly timer (`--delete-older-than 10d`) is the version
that keeps a rollback, so reach for the manual one deliberately.
`infra:store:optimise` is the write-heavy one: a full hard-link pass over the
whole store, so it is the first thing to skip on eMMC or a metered link, not GC.

## Secrets

Two encrypted planes and one CA; the file list, `.sops.yaml` anchors and the
rekey procedure are `docs/sops-rekey.md`. What is worth knowing here:

- `infra:secrets:edit:taskfile` also refreshes `~/Taskfile.yml` — the encrypted
  operator Taskfile is the source, the home copy is derived.
- `infra:sops:update-keys` rekeys every file after `.sops.yaml` changes; a file
  that no longer decrypts is `scripts/task/sops-drift-check.sh`, not a guess.
- `infra:sops:get:*` and `infra:api:get:<key>` need age keys, so they fail in a
  fresh clone or a sandbox. Evaluation never does.

## After a deploy that degrades a host

Check the closed loop before blaming the config: `task ops:health` reads the
sentinel ledger (`fleet-sentinel` skill), and a green socket is not a successful
job. Then roll back, then read `infra:logs`.

Truth: `taskfiles/infra.yml` — the executable contract; this page is the procedure.
