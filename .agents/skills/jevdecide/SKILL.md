---
name: jevdecide
description: Jev decisions for hermes — classify or choose with jev-decide, route a lane on calibrated probabilities, never let a model authorise an action.
version: 2.0.0
tags: [jev, decision, routing, gating, triage]
platforms: [linux, macos]
---

# jevdecide — the decision lane

Jev answers one kind of question: given a state and a set of described options,
which option — with a probability. One forward pass, no generated text, about a
second and ~400 input tokens per call (measured 2026-11-06, TypeSafe).

Use it where a decision repeats, is cheap to encode, and is worth an audit trail.
Do not use it to write, summarise, plan or explain: it returns a label.

## The call, in its three shapes

Always name the provider. The CLI's default is OpenRouter, which answers HTTP 402
without credit; a silent default turns a decision into a payment error.

```bash
# 1. Classify one text against described labels
jev-decide classify --provider typesafe --text "…" --criteria /tmp/labels.json

# 2. Answer several questions about one state in one pass
jev-decide decide --provider typesafe /tmp/request.json

# 3. Validate that request without spending a call
jev-decide decide --provider typesafe --dry-run /tmp/request.json
```

`--text-file -` reads the text from stdin, which is what makes a pipeline work:

```bash
cpg chat -m gpt-6-luna -s advice-review "…" \
  | jev-decide classify --provider typesafe --text-file - --criteria /tmp/labels.json
```

## What comes back

```json
{"decisions": {"category": {"status": "selected", "value": "review_my_work",
                            "probability": 1.0, "margin": 0.86}}}
```

- `status` is `selected` or `needs_review`, and the exit code mirrors it:
  **0 selected, 2 needs review, 1 error**. Branch on the code, not on the text.
- `probability` is the top choice's share and `margin` the gap to the runner-up.
  Gate on both: a 0.82 with a 0.03 margin is nearly a tie.
- A `false` on a `noul` question means "no", not "missing".
- `usage.output_tokens` is 0. There is no prose to read, so do not ask for any.

## Thresholds, and what they are not

- `--min-probability 0.8` and `--min-margin 0.15` are the fleet defaults; below
  either, the answer comes back `needs_review`.
- The probability is the model's own distribution, not a calibrated confidence,
  and it does not transfer between providers or models. Fit a threshold on your
  own data before gating anything that matters.
- A decision is a signal, never an authorisation. Delete, deploy, push and send
  still go through `confirm-before-destructive`.

## Routing: the lane, not the model

The useful pattern is to let Jev choose which lane a request belongs to, then
carry that lane out yourself:

```bash
jev-decide classify --provider typesafe \
  --text "Should I ask another model to review this module before switching?" \
  --criteria /tmp/advice-lane.json
# selected ask_another_model at 0.91 → then make the cpg call
```

What it cannot do is choose the model or provider that answers an agent turn:
that is `fallback_providers` in the hermes config, resolved by the agent, and
there is no hook for it. For graph-intent routing ("what touches frieren") the
measured answer is keyword rules plus a context bundle, no model at all — the
numbers are in `decision-picker`.

## Fail closed

- A paywall, a 402, a timeout or an unparseable body is a refusal, never a
  partial result. Report it; do not act on a defaulted label.
- No CLI or no key: say so and mark the judgement as simulation
  (`jev_called: false`, `probability: null`). Never invent Jev output.
- Keys live in `~/.hermes/.env`, which a hermes turn already loads. In a bare
  shell: `set -a; . ~/.hermes/.env; set +a`.
- `jev-decide setup` reports key presence without a network call. Check presence,
  never print a value.

## Where the procedure lives

- Inbox cleanup — metadata first, bodies only when Jev is unsure, delete only a
  confident `DELETE`: `references/inbox-cleanup.md` and `assets/jev_inbox.py`.
- The fleet engine contract and the categoriser's error gate:
  `scripts/task/categorize.sh`, `flake/policies.nix#decision-engine-routing`.
- Choosing among Jev, Laya and Kev-4B: `decision-picker`.
- The text lane to pipe in: `cpg-advice`.
