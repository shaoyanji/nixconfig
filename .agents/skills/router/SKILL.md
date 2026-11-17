---
name: router
description: "Pick me first on a new request: classify it with jev-decide against this repo's sixteen playbooks, then run that playbook's steps and stop at its evidence gate."
version: 0.1.1
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux, darwin]
metadata:
  hermes:
    tags: ['router', 'mode', 'playbook', 'jev', 'triage', 'discipline']
    related_skills: ['jevdecide', 'task-plane', 'prove-it-works', 'agents-notes', 'confirm-before-destructive']
---

# router: choose the playbook before the first edit

A wrong-shaped turn looks efficient while it runs. This is pstack's
`/poteto-mode` in this repo's vocabulary: one classification, one playbook, one
gate. It grants nothing — a destructive step still goes through
`confirm-before-destructive`, and a decision still belongs to a check.

## The turn, in four moves

1. Name the ask in one sentence, with every host, task, path and unit intact.
2. Classify it: by rule when the sentence names something, by `jev-decide` when
   two shapes are plausible.
3. Open the row for that label in `references/playbooks.md` and copy it into the
   to-do list before the first edit.
4. Stop at its gate, and label each claim `measured`, `inferred` or `guess`.

## Rules before the model

| The sentence names | Playbook |
| :--- | :--- |
| a host, or a path under `hosts/` | `host-change` |
| a path under `flake/` | `flake-change` |
| a task name, or a path under `taskfiles/` | `task-change` |
| a `SKILL.md`, `docs/`, or a comment | `prose-change` |
| an `AGENTS.nix` id, or `ops:notes:*` | `note-change` |
| a question — what, which, why, has this been tried | `research` |
| a failing gate, a traceback, a symptom with no cause | `bug-fix` |
| a live host's behaviour right now | `incident` |

Two rules cannot both fire, which is the point. The model is for the middle:
"the deploy keeps failing after a flake bump" names a host, a task and a
symptom, and the subject decides. `ops:ask` made the same choice for graph
questions: keyword rules first, a node's bundle when none fires, no model.

## The jev call

Labels are `assets/labels.json`, one flat map of id to what the reader does.

```bash
jev-decide classify --provider typesafe --text "<the sentence>" \
  --criteria .agents/skills/router/assets/labels.json \
  --min-probability 0.8 --min-margin 0.15
```

Exit `0` is selected, `2` needs_review, `1` an error: branch on the code. Read
`margin`, not only `probability` — at sixteen labels, 0.82 with a 0.03 margin is
a tie. On `needs_review`, duel the top two with a two-key criteria file; if that
ties too, pick by the rule table and say which rule. On an error, use the rules
and write `jev_called: false`. One call per turn.

## When the label is wrong

The first cell of a playbook row is a falsifier. If the first read shows a
different shape, stop, say so and reclassify. A misclassification that repeats
belongs in the rule table or `assets/labels.json`, not in a memory of the
incident (`correct`).

## Where the procedure lives

- Playbooks, one row each: `references/playbooks.md`.
- Labels: `assets/labels.json`, flat, no nesting.
- Which task answers an intent: `task-plane`; `task help`, `task find:<word>`.
- The decision lane: `jevdecide`. The evidence rule: `prove-it-works`.
- The rule behind the gate: [[flake/policies.nix#router-labels-are-routed]].
- This page's own budget: `flake/prose-budget.nix`. [[flake/policies.nix#agent-prose-budget]]
