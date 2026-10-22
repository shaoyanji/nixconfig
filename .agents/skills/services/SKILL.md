---
name: services
description: "Legacy wrappers routing to canonical infra/checks/dev."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['services', 'legacy', 'infra', 'checks']
    related_skills: []
---

# services — legacy aliases, and nothing to add here

Every `services:*` task routes to a canonical `infra:*` task, and the deprecated
ones (`switch:`, `boot:`, `nixos-rebuild`, `*rebuild`, `push-*-rebuild`) are
one-line aliases in `taskfiles/services-legacy.yml`. They exist so old muscle
memory keeps working; **write the canonical name in anything new**.

`services:deploy:host:<h>` is a bare pass-through to `infra:deploy:host:<h>`, so
there is never a reason to prefer it. Three wrappers are not aliases:

| Task | What it adds |
| :--- | :--- |
| `services:rollback:host:<h>` | `infra:rollback:host:<h>`, then `services:evidence:rollback:host:<h>` |
| `services:validate:host:<h>` | systemd's overall state over ssh; `TARGET=` overrides transport, so a tailnet-aliased host can be checked over the LAN |
| `services:record:host:<h>` | `dev:git:stage`, then a commit saying the build succeeded on that host |

Resolve any of them to its target with `task --list-all --json | jq` rather than
trusting this table; the file is the contract.

Truth: `taskfiles/services.yml` and `taskfiles/services-legacy.yml` — the
executable contract; this page is the procedure.
