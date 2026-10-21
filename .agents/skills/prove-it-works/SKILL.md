---
name: prove-it-works
description: "Pick me before declaring any task done. Verify against the real artifact (run the task, read the actual value, inspect the diff), never a proxy, a self-report, or 'it evaluates'."
version: 0.1.0
author: Lauren Tan (poteto), adapted for nixconfig
license: MIT
platforms: [linux, darwin]
metadata:
  hermes:
    tags: ['pstack', 'method', 'verification', 'evidence']
    related_skills: ['correct', 'checks', 'nix-eval', 'task-plane']
---

# prove-it-works: check the thing, not a story about the thing

Adapted from pstack (`principle-prove-it-works`, MIT, cursor/plugins).

Unverified work has unknown correctness. Derived state is cheaper to read than the source, which is exactly why it gets mistaken for evidence. A wrong inference costs more than the read did.

## Check the real thing

- Process liveness: query the unit, not a pid file or a stale socket.
- A host fact: `nix eval .#inventory.hosts.<host>`; never a copied table or a memory.
- A closure: `nix build` or `task checks:build:route`, not "it evaluated".
- A secret: decrypt it once, not "sops drift reported clean last month".
- A gate: run it and keep its exit status, including when you pipe it through `head` or `grep`.

When verification fails, suspect the observation method first: a negative narinfo cache makes a warm cache look empty, a non-login ssh shell loses `PATH`, a stale `ControlMaster` socket hangs. `AGENTS.md` keeps the field notes for each.

## Label the claim

Each claim in the report is `measured`, `inferred`, or `guess`. This repo already asks for that in the Agent Verification Protocol; use its phase split so the label is honest:

- evaluation catches a config error,
- a build proves a closure,
- sizing plans a build,
- a MicroVM canary proves a unit runs.

An eval is not a build. A build is not a runtime test.

## Script the check when you can

The strongest proof is a deterministic command a reviewer can re-run, not a one-time eyeball. Prefer an existing `task checks:*` over a new script, and paste the command with its output.

Commit the artifact only for large or long-running work where the trail has to be auditable later.

Truth: `flake/policies.nix` — the rules this page applies are predicates there; this page is the procedure.
