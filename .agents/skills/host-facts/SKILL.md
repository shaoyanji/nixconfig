---
name: host-facts
description: "Answer 'what is host X / which hosts exist / what runs there' from the compiled inventory and repo files — never by evaluating a NixOS configuration. Includes the inventory field map and jq/yq recipes."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['inventory', 'hosts', 'fleet', 'facts', 'no-eval']
    related_skills: ['nix-eval', 'task-plane', 'infra']
---

# host-facts — describe a host without compiling it

A host description is **data**, not a configuration. `inventory.toml` is parsed
once by `lib/inventory.nix` and surfaced as `.#inventory`, so these questions
cost 0.15–0.35 s and force **no** `nixosConfiguration`.

| Question | Command | Cost |
| :--- | :--- | :--- |
| One host's record | `nix eval --json .#inventory.hosts.<h>` | ~0.3 s |
| Every host | `task dev:inventory:json` (store-cached build) | first call only |
| Agent-facing digest | `task dev:inventory:feed` (store-cached build) | first call only |
| Host names the flake builds | `task dev:flake:get-hosts` | 2.4 s cold / 0.08 s warm |
| Repo-side notes, per host | `.agents/deploy/hosts/<host>.md`, `hosts/<host>/` | file read |
| Cross-host summary table | `.agents/fleet-matrix.md` | file read |

`task dev:inventory:host HOST=<h>` wraps the first row. Do **not** answer these
with `nix eval .#nixosConfigurations.<h>.config.*` — that is the whole module
system for one string.

## Field map (as of 2026-10-17)

```
hostname  role  kind  arch  status  status_detail  category
desktop_environment  flake  ci  is_nix  managed  persona
system_type  users  network  software  hardware{...}  notes[]
```

`hardware` carries `cpu`, `gpu`, `ram`, `model`, `storage_layout`,
`storage_type`, `display`, `battery` — the fields EXP-107 relies on to decide
what a host may be asked to build.

## jq recipes

```bash
# one host, only the fields you need
nix eval --json .#inventory.hosts.fern \
  | jq -c '{hostname, arch, kind, status, role}'

# every active host that is NOT x86_64-linux (cross-arch build targets)
nix eval --json .#inventory \
  | jq -r '.hosts[] | select(.status == "active" and .arch != "x86_64-linux") | "\(.hostname)\t\(.arch)"'

# who is a NixOS host under CI, and on which flake output
nix eval --json .#inventory \
  | jq -r '.hosts[] | select(.kind == "nixos") | "\(.hostname)\t\(.ci // "-")"'

# RAM / CPU of one host, without touching its config
nix eval --json .#inventory.hosts.frieren | jq -r '.hardware | "\(.cpu)\n\(.ram)"'

# free-form commentary lives in notes[]
nix eval --json .#inventory.hosts.fern | jq -r '.notes[]'
```

Raw-file fallback (only when the flake cannot evaluate, e.g. no nix at all):

```bash
yq -o=json '.hosts.fern' inventory.toml | jq -c '{hostname, role, notes}'
```

Prefer the compiled path: it is defaults-normalised, schema-checked, and carries
derived counts, so two consumers cannot disagree. `checks:inventory:compiled`
enforces that agreement; `checks:inventory:sync` enforces docs/LLM cards.

## Sequencing rule (from EXP-103 → EXP-107)

Before asking "can this host build X", read its tier/constraints from the
inventory rather than trying it. `fern` is documented as a 15 W dual-core,
8 GB machine with "avoid heavy compilation loops"; the rule is enforced read-only
by `checks:build:route` and satisfied by `infra:warm:host:<h>` on the builder.

## Common traps

- `.#inventory` is the whole registry — `--json .#inventory` alone is fine
  (data only) but `.#nixosConfigurations` alone forces every host config.
- `status = "preserved"` hosts may not evaluate at all (`minyx` has a
  `boot.kernelPackages` conflict); do not treat "registered" as "buildable".
- `--raw` on a numeric field prints digits but is not typed JSON; use `--json`
  when the value feeds a script.
