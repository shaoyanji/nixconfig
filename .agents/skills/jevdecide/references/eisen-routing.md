# Eisen's decision router — request shape and the bench that shaped it

The router lives on Eisen: `:8000` → Jev, falling back to Laya (`127.0.0.1:8090`)
only — provider-side failures, never request-side errors, and every answer
stamped `X-Decision-Provider` so the lane is visible. Kev-4B is not a lane
(operator decision). The routing rule and the caveats are in the
`jevdecide` body; this file is the wire format and the measurement behind
"no model is used for graph routing".

## The request shape (`POST /v1/systemone`)

`questions` must be an **object** (not an array) mapping question ids to question
objects:

```json
{
  "state": {"customer": "A customer threatens to cancel because the price went up."},
  "questions": {
    "q1": {"type": "choice", "instructions": "What should the agent do?",
           "criteria": {"offer_discount": "Offer a discount.",
                        "let_them_go": "Let them cancel.",
                        "escalate": "Escalate."}}
  }
}
```

Question shapes: `choice` (n options) · `score` (ordinal) · `noul` (yes/no
probability). Response: `answers` (per question `choice` / `probabilities` /
`confidence`) plus `usage` with `output_tokens: 0` — a single forward pass.

Kev-4B has no endpoint at all (no nginx, no tailscale serve). Test it directly on
localhost through its own llama-server; the test that mattered is recorded in
`hosts/eisen/HANDOFF.md`.

## The graph-routing bench (2026-10-19, `task ops:bench:kg`)

When the decision is *graph-intent routing* — "what touches frieren" → which
query — the honest comparison needs three sets, because one flatters the rules and
the bundle cannot answer the third:

| router | rule-shaped | paraphrase | names no node | latency |
| :--- | ---: | ---: | ---: | ---: |
| keyword rules + context bundle (offline) | **14/14** | 10/10 (4 bundle) | 4/9 | 0 ms |
| hosted Jev | 13/14 | **9/10** | **7/9** | ~330 ms |
| in-repo `systemone-decision` | 5/14 | 1/10 | 4/9 | ~180 ms |

Read that table honestly. The 14/14 is independent evidence. The paraphrase 10/10
is not: four of those answers are the bundle, and their gold labels were written
from the same "a node-naming question means that node's context" policy the bundle
implements — `ops:bench:kg` prints `4 came from the bundle` so the number can be
discounted. On that set rules alone score 6/10 against Jev's **9/10**, and Jev's
single miss (declining "tell me about fern") is defensible. The third column is
where Jev genuinely wins: a question that names no node leaves the bundle nothing
to resolve, so the rules fall back to keywords (4/9).

Read the *shape* of the misses, not just the count. The rules' five are `UNKNOWN`
— a decline the caller can see and re-ask around — while Jev's two are confident
wrong intents, including labelling an off-topic question DOC_CONTEXT instead of
declining. A silent wrong relation is worse than a visible "no query matched" for
anything automated.

The model was dropped from `ops:ask` for reasons other than accuracy: the bundle
returns a superset, so it cannot mis-pick a relation, and it costs 0 ms offline
with no key against ~330 ms over the network. `KG_DECIDE_ALWAYS=1` still runs Jev
as an agreement check. The public-benchmark gap (Jev 0.966 vs Laya 0.583) is why
the cloud model stays the default for genuine decisions — Laya, Kev-4B and Jev
work on Eisen, not on graph routing.

## Kev-4B, as tested

Tested 2026-10-17 (`hosts/eisen/HANDOFF.md`): stock llama-server on :8092,
`POST /v1/systemone` with a cancel-threat state and one choice question returned
`offer_discount` (p 0.597, confidence 0.395). The server was killed after the
test: Kev gets no endpoint and is not wired into the router, whose fallback is
Laya only. The GGUF declares a 262,144-token context; its *validated* decision
context is not published, and the "8,192 tokens / 16× Laya" figure came from the
Kev-0.8b card rather than this model. Publisher metrics are unverified:
transfer-v4 0.838, breadth-v1 0.69, hard-v1 0.803, devtools-v1 0.756.

A note in `HANDOFF.md` also records that the earlier `decision-picker` page
overstated this wiring, which is why the rule here is the router's behaviour and
not a model-selection table an agent has to interpret.
