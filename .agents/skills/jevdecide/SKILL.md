---
name: jevdecide
description: Jev decisions for hermes — TypeSafe Jev first, with openrouter, Laya and the in-repo scorer only as fallbacks; classify or choose with jev-decide, route a lane on calibrated probabilities, never let a model authorise an action.
version: 3.0.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [jev, decision, routing, gating, triage, eisen]
    related_skills: [router, task-plane]
---

# jevdecide — the decision lane

Jev answers one kind of question: given a state and a set of described options,
which option — with a probability. One forward pass, no generated text, about a
second and ~400 input tokens per call (measured 2026-11-06, TypeSafe).

Use it where a decision repeats, is cheap to encode, and is worth an audit trail.
Do not use it to write, summarise, plan or explain: it returns a label.

## The call, in its three shapes

`~/.local/bin/jev-decide` wraps the upstream CLI: the default provider is
**typesafe** (`JEV_PROVIDER` overrides), an explicit `--provider` wins, and a
transport failure (HTTP/dns/tls/timeout/connection/missing key) retries once on
the openrouter lane. Request-side errors never retry.

The openrouter lane pins `perplexity/pplx-decider-v1.3:free`
(probed 2026-11-24: exit 0, selected @ 0.87, ~0.35 s, zero cost) unless the
caller passed `--model`; `JEV_OPENROUTER_MODEL` overrides the pin. A missing key
prints `Set <NAME>_API_KEY …`, which the wrapper matches as `Set *API*` and
therefore treats as a transport failure worth one retry.

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
- An answer comes back on exit 2 with `status: needs_review` — that is a draft
  signal to read, not a failure to retry.

## Thresholds, and what they are not

- `--min-probability 0.8` and `--min-margin 0.15` are the fleet defaults; below
  either, the answer comes back `needs_review`.
- The probability is the model's own distribution, not a calibrated confidence,
  and it does not transfer between providers or models. Fit a threshold on your
  own data before gating anything that matters.
- A decision is a signal, never an authorisation. Delete, deploy, push and send
  still go through `confirm-before-destructive`.

## Which model answers a decision

One ladder, TypeSafe first. A step is reached only when the one above it cannot
answer, and every answer names the step that produced it.

| Step | Lane | Invocation | Trigger |
| :--- | :--- | :--- | :--- |
| 1 | **TypeSafe Jev** (cloud, most accurate at 0.966 macro on the public benchmark) | `jev-decide … --provider typesafe`, or `POST api.typesafe.ai/v1/systemone` | every call |
| 2 | openrouter `pplx-decider-v1.3:free` | the wrapper's single automatic retry | transport, auth, 402 or timeout from step 1 |
| 3 | **Laya** (local, `127.0.0.1:8090`) via the Eisen router `:8000` | `decide local …` | TypeSafe and openrouter both unreachable; input ≤ **512 tokens** |
| 4 | in-repo scorer (`systemone-decision`, `:8091`) | `systemone-decision …`, `task ops:categorize` fallback | no network path at all |

`jev-decide` is missing on some hosts (delphi has no copy on PATH). That is not a
reason to start at step 3 — call TypeSafe over HTTP instead:

```bash
set -a; . ~/.hermes/.env; set +a                       # TYPESAFE_API_KEY
jq -n --arg s "$STATE" --argjson q "$QUESTIONS" '{state: $s, questions: $q}' \
  | curl -fsS --max-time 25 -H 'content-type: application/json' \
      -H "authorization: Bearer $TYPESAFE_API_KEY" --data @- \
      https://api.typesafe.ai/v1/systemone
```

Details that bite:

- The Eisen router forwards the client's auth with a 25 s TypeSafe timeout and
  stamps `X-Decision-Provider` on every answer, so a switch is visible. A
  request-side error (4xx) returns TypeSafe's own response and is not re-asked of
  a weaker model.
- **A first-request 502 is working behaviour.** After idle, Laya's cold start can
  exceed 25 s, so the first decision 502s and the second succeeds. Retry; do not
  lengthen the timeout.
- **Laya's `confidence` is `1 − normalized entropy`**, so a Jev cutoff does not
  transfer, and it is not a drop-in: on large option sets it falls to ~0.43 where
  Jev holds 0.87. Inputs beyond its 512-token limit have no local lane: retry
  TypeSafe or hand the residue to a reasoner instead of truncating.
- Step 4 scores by lexical overlap (hash embeddings + softmax), not the 421M
  checkpoint; its confidence is low signal and it is offline-only.
  `/v1/systemone` on `:8091` is the self-hosted service; delphi answers it on 8444.
- **Kev-4B is deliberately not a lane**: the merged GGUF works in stock llama.cpp
  (tested 2026-10-17 on :8092), but the operator's recorded decision is no
  endpoint and no router wiring — its long-context accuracy is unvalidated. It
  exists on disk for direct tests only.

From a nushell shell (`modules/config/nu/decision.nu`) the same lane, with the
provider failure printed to stderr so a silent switch to the weaker local model
is visible:

```bash
decide models                                        # providers + readiness
decide "pick the backup tier" --options [ssd hdd tape]   # auto: Jev, then local
decide yes "the upstream is degraded" --state {msg: "502"}
decide score "rate severity" --criteria [ok degraded down]
decide jev …   ·   decide local …                    # force one side
```

**For graph-intent routing ("what touches frieren") no model is used at all.**
When no keyword rule matches, `ops:ask` returns the context bundle of the node the
question names instead of guessing a relation. The bench that produced that
decision, and the reasons the table it printed has to be read carefully, are in
`references/eisen-routing.md`.

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
there is no hook for it.

## Fail closed

- A paywall, a 402, a timeout or an unparseable body is a refusal, never a
  partial result. Report it; do not act on a defaulted label.
- No CLI on PATH: call the API directly (the curl above) before considering a
  fallback. No key either: say so and mark the judgement as simulation
  (`jev_called: false`, `provider: null`, `probability: null`). Never invent Jev
  output, and never let a step-3 or step-4 answer stand in for a TypeSafe one
  without saying that it did.
- Keys live in `~/.hermes/.env`, which a hermes turn already loads. In a bare
  shell: `set -a; . ~/.hermes/.env; set +a`.
- `jev-decide setup` reports key presence without a network call. Check presence,
  never print a value.

## Where the procedure lives

- Inbox cleanup — metadata first, bodies only when Jev is unsure, delete only a
  confident `DELETE`: `references/inbox-cleanup.md` and `assets/jev_inbox.py`.
- The fleet engine contract and the categoriser's error gate:
  `scripts/task/categorize.sh`, `flake/policies.nix#decision-engine-routing`.
- Eisen's router, the `/v1/systemone` request shape and the routing bench:
  `references/eisen-routing.md`.
- The text lane to pipe in: `cpg` (lane 1).

Truth: `modules/config/nu/decision.nu` — the classifier; this page is the routing.
