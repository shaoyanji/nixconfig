---
name: simplex-admin
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
description: SimpleX Chat fleet administration lives in a module — see modules/user/ai/skills/simplex-admin.
metadata:
  hermes:
    tags: [simplex, chat, rpc, daemon, coordination]
    related_skills: [agents]
---

# SimpleX admin: one home

The procedure, the RPC client and the daemon wiring are the module copy:
`modules/user/ai/skills/simplex-admin/` (`SKILL.md` + `scripts/simplex-rpc.py`).
It wins on install — `modules/user/ai/skills/default.nix` prefers the runtime
tree "because it is the tree that carries scripts" — so a second copy here was
never installed and had already drifted (230 vs 233 lines).

Read the module, not this file. `hosts/frieren/infra-stack.nix` is the consumer
that references the script by path.

Truth: `modules/user/ai/skills/simplex-admin/` — the skill's real home; this page is the pointer.
