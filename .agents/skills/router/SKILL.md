---
name: router
description: "Pick me first on a new request: classify it with jev-decide against this repo's sixteen playbooks, then run that playbook's steps and stop at its evidence gate."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux, darwin]
metadata:
  hermes:
    tags: ['router', 'mode', 'playbook', 'jev', 'triage', 'discipline']
    related_skills: ['jevdecide', 'task-plane', 'prove-it-works', 'agents-notes', 'confirm-before-destructive']
---

# router: choose the playbook before the first edit

A wrong-shaped turn does not look wrong while it runs. It looks efficient: the
edit is small, the command answers, the summary is fluent. It costs twice when
the shape was off — a fact question answered with a refactor, a host edit gated
by `nix flake check` on an 11 GiB machine, a rebuild used as a check.

This is pstack's `/poteto-mode` in this repo's vocabulary: one classification,
one playbook, one evidence gate. It grants nothing. A destructive step still
goes through `confirm-before-destructive`; a decision still belongs to a check.

## The turn, in four moves

1. **Name the ask in one sentence**, in the operator's words, with every host,
   task, path or unit it mentions left intact. That sentence is the classifier's
   input.
2. **Classify it** — by rule when the sentence names something, by `jev-decide`
   when two shapes are plausible. Rules come first because they are free and
   deterministic.
3. **Open the playbook** at `references/playbooks.md#<id>`, and copy its steps
   into the to-do list before the first edit. A playbook read after the edit is a
   rationalisation.
4. **Stop at the playbook's gate.** Report each claim as `measured`, `inferred`
   or `guess` (`prove-it-works`). The gate is the exit; a bigger gate is not a
   better one.

## Rules before the model

| The sentence names | Playbook | Why a rule suffices |
| :--- | :--- | :--- |
| a host, or a path under `hosts/` | `host-change` | one host is one scope, and the gate is per host |
| a path under `flake/` | `flake-change` | the projection assembles every configuration from there |
| a task name, or a file under `taskfiles/` | `task-change` | the task surface is the contract |
| a `SKILL.md`, a path under `docs/`, or a comment | `prose-change` | budgets and the census are mechanical |
| an `AGENTS.nix` note id, or `ops:notes:*` | `note-change` | the design record has its own contract |
| a question — what, which, why, has this been tried | `research` | no edit is the answer |
| a failing gate, a traceback, a symptom with no cause | `bug-fix` | the cause is unknown, so the space must be bisected |
| a live host's behaviour right now | `incident` | a config edit before `ops:health` is a guess |

Two rules cannot both fire on one sentence, which is the point. The model is
for the middle: "the deploy keeps failing after a flake bump" names a host, a
task and a symptom, and the right playbook depends on which one is the subject.

Graph questions already made this choice: `ops:ask` answers from keyword rules
and falls back to a node's context bundle, with no model on the path. The router
keeps the model for the one thing rules read badly — intent in prose.

## The jev call

The label set is `assets/labels.json`: one flat map of playbook id to a
description of what the reader *does*, written to be mutually exclusive. The
shape follows `scripts/task/categorize.sh`, which builds the same file for the
knowledge base's categories.

```bash
jev-decide classify --provider typesafe \
  --text "<the sentence from move 1, verbatim>" \
  --criteria .agents/skills/router/assets/labels.json \
  --min-probability 0.8 --min-margin 0.15
```

```json
{"decisions": {"category": {"status": "selected", "value": "host-change",
                            "probability": 0.91, "margin": 0.44}}}
```

- Exit `0` is `selected`, `2` is `needs_review`, `1` is an error. Branch on the
  code, never on the text of the body.
- Read `margin`, not only `probability`. Sixteen labels make a 0.82 with a 0.03
  margin a near-tie, and the top two are the only ones worth a second pass.
- `needs_review` is a draft signal. Run one duel over the top two ids — the same
  call with a two-key criteria file — and if that also ties, pick by the rule
  table and say which rule decided.
- No CLI, no key, a 402, a timeout: fall back to the rule table, and write
  `jev_called: false` with no probability. Never invent a label.

One call per turn. The router is a routing cost, not a research step; it does
not classify each file, and it does not re-classify after the first read.

## The sixteen playbooks

| Playbook | Ends on |
| :--- | :--- |
| `host-change` | `task checks:host HOST=<h>` |
| `chain-change` | `checks:host` on one host per affected chain |
| `flake-change` | `checks:host` on one active host per kind |
| `gate-change` | the new gate failing on the mistake it was written for |
| `task-change` | `checks:tasks` plus `check:verify` |
| `prose-change` | `checks:prose`, the prose budget and the census |
| `note-change` | every ref resolving, and `ops:notes` reading it back |
| `bug-fix` | the failing check that reproduced the symptom |
| `perf` | a measured number, before and after |
| `incident` | a unit's state and the sentinel ledger, not a rebuild |
| `secret` | a decrypt that works on the target host |
| `deploy` | `infra:deploy`'s validate phase, or a rollback |
| `research` | one source, named, with its scope |
| `decision` | a scored lane, with the threshold stated |
| `novel` | an `AGENTS.nix` note, or code that lands the answer |
| `publish` | the compiled surface, never a hand edit on a host |

Each section in `references/playbooks.md` carries: what lands there, the first
read, the steps, the gate, when to stop, and what it must not do.

## When the label is wrong

The first step of every playbook is a falsifier. If the first read shows a
different shape — the "host edit" is really a shared module, the "bug" is a
documented refusal — stop, say so, and reclassify. That is the router working,
not failing.

A misclassification that repeats is a rule waiting to exist: the fix belongs in
the rule table above or in `assets/labels.json`, not in a memory of the incident
(`correct`).

## Where the procedure lives

- The playbooks: `references/playbooks.md`.
- The labels: `assets/labels.json`, one flat map, no nesting.
- The decision lane, its models and its thresholds: `jevdecide`.
- Which task answers an intent: `task-plane`; `task help` and `task find:<word>`.
- The evidence rule and the claim labels: `prove-it-works`.
- The label-shape precedent, and the duel machinery: `scripts/task/categorize.sh`.
- A page's own budget, so this one cannot grow silently: `flake/prose-budget.nix`.
[[flake/policies.nix#agent-prose-budget]]
