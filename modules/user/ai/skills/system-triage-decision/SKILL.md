---
name: system-triage-decision
description: Autonomous system triage and architectural handover prioritization powered by System One decision models (Julia-1 and Laya). Evaluates SYSTEM.md and HANDOFF.md with calibrated confidence scoring, TIER 1/2 categorization, and threshold-gated remediation routing.
---

# System Triage Decision (System One AI Decision Models)

A specialized agent skill utilizing **System One decision models** (`julia-1` and `laya`) to perform structured, non-autoregressive triage across NixOS systems.

## What Are System One Decision Models?
Unlike autoregressive language models that generate unconstrained text tokens, System One decision models evaluate the decision space in a single fast forward pass, returning typed answers with calibrated probability distributions:
1. **`choice`**: Picks one option from a defined set with probabilities.
2. **`score`**: Places the input on an ordered numerical scale with confidence.
3. **`noul`**: Evaluates whether a condition holds (`yes`/`no`) with calibrated probability.
4. **`classify`**: Assigns category labels from a fixed taxonomy.
5. **`route`**: Directs input to an action handler with confidence rationale.

### Model Characteristics & Benchmark Limits on `frieren`
- **Julia-1 (Supersonic Labs):**
  - **Parameters:** 144M (`jhu-clsp/mmbert-small` encoder).
  - **Context Window:** Up to 8,192 tokens.
  - **Measured CPU Latency:** ~0.23 ms per decision (~4,250 decisions/sec).
  - **Context Latency:** 64 tokens: 0.18 ms; 512 tokens: 0.99 ms; 8,192 tokens: 15.46 ms.
  - **Best For:** High-throughput batch triage, long document context, offline CPU execution.
- **Laya (Convai Innovations):**
  - **Parameters:** 421M (`answerdotai/modernbert-large` encoder).
  - **Context Window:** Up to 512 tokens.
  - **Measured CPU Latency:** ~0.41 ms per decision (~2,410 decisions/sec).
  - **Best For:** High-precision option marker scoring, low-entropy decision routing.

## Usage Guide

The skill provides an executable CLI:
`~/.agents/skills/system-triage-decision/scripts/system-triage.sh`

### 1. Triage `SYSTEM.md` Health Scorecard
```bash
~/.agents/skills/system-triage-decision/scripts/system-triage.sh --model julia-1 triage-system /home/devji/SYSTEM.md
```
- The tier comes from the **Status column**, never from the model: `FAILED` → `TIER_1_IMMEDIATE_REPAIR`, `UNVERIFIED`/`WARN` → `TIER_2_STRATEGIC_HANDOFF`, `OK` → `HEALTHY_MONITOR_ONLY`. A status the table does not recognise is treated as `warn`, so an unknown word cannot pass as health.
- `overall_health_score` is weighted from the rows (`healthy=1.0`, `unverified=0.5`, `failed=0.0`), so a status change moves it. A document with no parsable rows is an `error`, not a clean bill.
- Per row it reports the model's own `model_suggestion` next to the tier, with `model_disagrees` and `confidence_gated` — a disagreement is a signal about the model, not a reason to call a failed subsystem healthy.
- Routes to action handlers (`nixos_rebuild`, `service_restart`, `storage_scrub`, `database_vacuum`, `verify_probe`, `advisory_note`) chosen from the row's subject; an `UNVERIFIED` row always asks for a re-measure, whatever it is about.

### 2. Triage `HANDOFF.md` Strategic Queue
```bash
~/.agents/skills/system-triage-decision/scripts/system-triage.sh --model julia-1 triage-handoff /home/devji/HANDOFF.md
```
- Tags each item `AUTONOMOUS_PROMOTION_CANDIDATE`, `BLOCKED_ON_HARDWARE_DEPENDENCY`, `DOCUMENTED_UPSTREAM_GAP`, `ALREADY_VERIFIED`, or `OPERATOR_DECISION_REQUIRED`.
- The category is a judgement, so the model may make it — but only at or above its `min_confidence_threshold` (0.70 julia-1, 0.75 laya). Below it the item's own status words decide and `decided_by` says `rules`; `model_suggestion` still shows what the model wanted.

### 3. Run Limit Benchmarks
```bash
~/.agents/skills/system-triage-decision/scripts/system-triage.sh --model julia-1 benchmark --iterations 100
~/.agents/skills/system-triage-decision/scripts/system-triage.sh --model laya benchmark --iterations 100
```

### 4. Raw Decision Queries
```bash
# Choice query
~/.agents/skills/system-triage-decision/scripts/system-triage.sh query --type choice \
  --state "Btrfs device error count is 0 on /dev/sda2 and /dev/sdb3" \
  --prompt "What is the storage health status?" \
  --options "HEALTHY" "DEGRADED" "CORRUPT"

# Noul query (boolean with calibrated confidence)
~/.agents/skills/system-triage-decision/scripts/system-triage.sh query --type noul \
  --state "PostgreSQL vacuum pgvector completed with 15 pages freed" \
  --prompt "Did the vacuum operation succeed?"
```

## One engine, resolved not copied

`scripts/system-triage.sh` runs `modules/services/systemone/engine.py` from the repo and falls back to the `systemone-decision` CLI. It keeps no vendored copy: the one it used to carry went stale and answered with the old tier logic for months (2026-10-23). Same for the served envelope — `task checks:decision:triage` is the gate.

Truth: `scripts/task/systemone.sh` (`task ops:decide`) — the engine call; this page is the judgment.
