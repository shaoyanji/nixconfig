---
name: correct
description: "Pick me when the operator has corrected the same mistake twice: turn each repeat into a gate. Architecture first, then types, then a lint naming the fix, then a test; prose and rules last."
version: 0.1.0
author: Lauren Tan (poteto), adapted for nixconfig
license: MIT
platforms: [linux, darwin]
metadata:
  hermes:
    tags: ['pstack', 'method', 'enforcement', 'rules', 'refactor']
    related_skills: ['prove-it-works', 'no-comments', 'checks', 'task-plane']
---

# correct: a rule nothing enforces is a repeat waiting to happen

Adapted from pstack (`correct`, MIT, cursor/plugins). Every contributor here is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that evaluates. Design the repo so a change that looks right from one file is right everywhere.

## 1. Find the mistake classes

Read the evidence, not the vibes: `git log --oneline -50`, `git log --grep=revert`, `AUDIT.md`, `task ops:notes KIND=open`, and every comment that explains a workaround.

Group them into classes. A class counts once it has happened twice.

The repo already keeps one such record: the "Agent Verification Protocol" in `AGENTS.md`. It is a table of corrections whose enforcement you can audit.

## 2. Fix each class at the highest level that works

| Level | What it looks like here | Example already in the tree |
| :--- | :--- | :--- |
| 1. Architecture | one owner per fact, one supported way per task, delete the old path | `lib/inventory.nix` compiles `inventory.toml`; `.#artifacts.docs` is a store path, never a committed copy |
| 2. Type or lint | a check whose error names the file or option to use instead | `checks:toml:lint`, `checks:tasks`, `checks.<system>.skills-schema` |
| 3. Test or gate | a runnable gate that fails on the real mistake | `checks:host` refuses a fleet sweep; `checks:flake` refuses below 16 GiB |
| 4. Docs and rules | prose in `AGENTS.md` or a skill | last resort: nothing fails when an agent skips it |

Walk that table downward and stop at the first level that holds. Two rules:

- If the pattern is already widespread, fail only when a change adds more, so the gate can land today.
- Before adding a script, walk the `task-plane` ladder: eval, jq, Nix lib, check, task, script, Go.

## 3. Prove the gate, then fix the instances

Every new check must fail on a real past mistake. Run it against the commit that had the bug, or against the file that still has it, and paste that output. A check that has never failed is a ritual.

Then fix the most frequent class, one commit each.

Exceptions go on the offending line with a reason and an expiry, never as a silent skip.

## 4. Keep the rule table

`AGENTS.md` and `.agents/SCHEMA.md` pair each rule with what enforces it. That table is the contract:

- When the operator corrects you, fix the mistake and add the rule.
- If the rule was already written and nothing enforces it, that is a repeat: climb the table in the same change.
- Drop a rule once its mistake cannot happen.

## Reply

Each class with its evidence, the level you picked, and why the level above it did not work.
