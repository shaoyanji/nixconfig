---
name: agents
description: "Operator menus, xs runtime, OAuth/session management."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['agents', 'operators', 'xs']
    related_skills: []
---

# agents — the operator menu

`task agents:menu` is the interactive control plane, and the sub-commands it
offers are the surface: `rebuild`, `edit-config`, `update`, `load`, `browse`,
`new`, `incus`, `sudologinssh`, `help`, `status`, `check`, `deploy`, `logs`,
`exit`.

Everything the menu calls is also a top-level task (`browse-*`,
`edit-*`, `update`, `new`, `incus`, `sudologinssh`), which is why the menu is a
convenience and not an API — quote the task name, not the menu path. The
`browse`, `edit-config` and `update` entries are deprecated menus kept alive for
muscle memory; new work uses `edit-global`, `edit-sops`, `dev:flake:*` directly.

All OAuth work goes through `scripts/task/service-oauth.sh`, so a token problem is
a bug in that script, not in the task that wrapped it.

Truth: `taskfiles/agents.yml` — the executable contract; this page is the procedure.
