# jev-decide decision format — reuseable schema for feeding idle panes

## Request JSON schema

{
  "state": "<lane context + recent xs turns + open claims + goals>",
  "questions": {
    "direction": {
      "type": "choice",
      "instructions": "<one sentence telling the model what to pick>",
      "criteria": {
        "<label>": "<description of that direction>",
        ...
      }
    }
  }
}

`state` feeds the model the lane context. `criteria` are the candidate directions with short descriptions.

## Invocation

jev-decide decide <request.json> \
  --provider typesafe \
  --min-probability 0.8 \
  --min-margin 0.15

Exit codes: 0 = selected, 2 = needs_review.

## Decision thresholds

- **status: selected** — probability ≥ 0.8 and margin ≥ 0.15. Drive the returned value immediately.
- **status: needs_review, margin ≥ 0.3** — decisive. Pick the top choice by margin and drive — no duel needed.
- **status: needs_review, margin < 0.3** — not decisive. Duel the top two with a second `jev-decide decide` call containing only those two criteria.
- **duel margin still < 0.15** — still not decisive. Pick the top choice by margin and drive. Never run a third decide call.

## Response shape

{
  "decisions": {
    "direction": {
      "status": "selected" | "needs_review",
      "value": "<chosen label>",
      "probability": <0-1>,
      "margin": <0-1>
    }
  },
  "response": {
    "answers": {
      "direction": {
        "choice": "<label>",
        "confidence": <0-1>,
        "probabilities": { "<label>": <0-1>, ... }
      }
    }
  }
}

## Notes

- Always feed context as `state` — recent xs turns, open claims, lane duties, goals.
- Keep `criteria` to 2–4 short, concrete options.
- `executes_actions: false` — jev-decide only recommends; the agent must execute.
