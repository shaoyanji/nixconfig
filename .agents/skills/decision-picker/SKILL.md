---
name: decision-picker
description: Pick the right decision model on Eisen — Laya (fast, ≤500 tokens), Kev-4B (longer inputs, stronger), or TypeSafe Jev (cloud, best accuracy). Includes the routing rule, the confidence caveats, and when not to let a decision gate a destructive action.
---

# decision-picker

**Runs on:** Eisen (router :8000 → Jev → Laya; Kev-4B via its own llama-server on localhost).
**Use when:** a decision (choice / score / yes-no) is needed — SubZeroClaw's `DECISION` step, a gate before an action, or any "should I do X?" question.
**Pick me over:** calling Laya or Kev directly when you are unsure which fits — this skill is the router.

## The models

| Model | Where | Input limit | Speed | Accuracy (public benchmark) | When |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TypeSafe Jev** (cloud) | `https://api.typesafe.ai/v1/systemone` via router `/v1/decisions` | Large | Fast (cloud) | **0.966** macro | Default. Best accuracy. Needs network + API key. |
| **Laya** (local fallback) | `127.0.0.1:8090` via router fallback, on-demand | **512 tokens** (hard limit, base checkpoint) | Fast (CPU, ~0.4s for 4 questions) | 0.583 macro | ≤500-token inputs when Jev fails. Weaker — see caveats. |
| **Kev-4B** (local) | Own llama-server on localhost (NOT via llama-swap; no public endpoint) | Long (GGUF declares 262k, validated context **not published**) | Slower (~24s cold load, then fast) | Publisher: transfer-v4 0.838 (unverified) | >500-token inputs when Jev fails. Test on your own long inputs before trusting it. |

## Routing rule (what the router does)

1. **Jev first** (25s timeout). The router forwards the client's auth to Jev.
2. **On Jev failure, fallback to local.** The router picks by input length: ≤500 tokens → Laya; >500 tokens → Kev-4B.
3. **First-request 502 is working behavior, not a bug.** After idle, Laya's cold start can exceed the router's 25s timeout, so the first decision 502s. Retry — the second request succeeds (Laya is warm by then). Do not "fix" by lengthening the timeout.

## The request shape (`POST /v1/systemone`)

`questions` must be an **object** (not an array) mapping question-ids to question objects:

```json
{
  "state": {"customer": "A customer threatens to cancel because the price went up."},
  "questions": {
    "q1": {"type": "choice", "instructions": "What should the agent do?",
           "criteria": {"offer_discount": "Offer a discount.", "let_them_go": "Let them cancel.", "escalate": "Escalate."}}
  }
}
```

Question shapes: `choice` (n options) · `score` (ordinal) · `noul` (yes/no probability). Response: `answers` (per question: `choice`/`probabilities`/`confidence`) + `usage` (`input_tokens`, `output_tokens: 0` — a single forward pass, no generation).

## Confidence caveats (read before gating on a decision)

- **Laya's `confidence` is `1 - normalized entropy`.** A Jev cutoff does **not** transfer. Fit your own threshold on your own data.
- **Laya is not a Jev drop-in.** On the public benchmark Jev 0.966 vs Laya-base 0.583; on large option sets Laya falls to ~0.43 where Jev holds 0.87.
- **Kev-4B's validated decision context is not published.** It accepts long inputs, but long-context accuracy is unvalidated — test on your own long inputs before trusting it.
- **Do not let a decision model gate a destructive action on its own.** A decision is a signal, not an authorization. For a destructive step (delete / deploy / push / send), apply `confirm-before-destructive` — ask the user, do not let the model approve it.

## Kev-4B (no endpoint)

Kev-4B has **no public endpoint** (no nginx, no tailscale serve). Test it directly on localhost via its own llama-server (see the Kev test in HANDOFF.md). Do not expose it — it is a local fallback, not a service.
