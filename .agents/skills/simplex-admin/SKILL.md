---
name: simplex-admin
description: SimpleX Chat fleet administration lives in a module — see modules/user/ai/skills/simplex-admin.
---

# SimpleX admin: one home

The procedure, the RPC client and the daemon wiring are the module copy:
`modules/user/ai/skills/simplex-admin/` (`SKILL.md` + `scripts/simplex-rpc.py`).
It wins on install — `modules/user/ai/skills/default.nix` prefers the runtime
tree "because it is the tree that carries scripts" — so a second copy here was
never installed and had already drifted (230 vs 233 lines).

Read the module, not this file. `hosts/frieren/infra-stack.nix` is the consumer
that references the script by path.
