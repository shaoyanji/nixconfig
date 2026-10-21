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
- Categorizes each subsystem row into:
  - `TIER_1_IMMEDIATE_REPAIR`: Subsystems experiencing regressions requiring instant in-place repair.
  - `TIER_2_STRATEGIC_HANDOFF`: Architectural dependencies or maintenance to log in `HANDOFF.md`.
  - `HEALTHY_MONITOR_ONLY`: Healthy operational services.
- Computes urgency scores (1.0 to 5.0) and routes to action handlers (`nixos_rebuild`, `service_restart`, `storage_scrub`, `database_vacuum`).

### 2. Triage `HANDOFF.md` Strategic Queue
```bash
~/.agents/skills/system-triage-decision/scripts/system-triage.sh --model julia-1 triage-handoff /home/devji/HANDOFF.md
```
- Evaluates queue items, computes priority scores (1.0 to 5.0), and tags items as `AUTONOMOUS_PROMOTION_CANDIDATE`, `BLOCKED_ON_HARDWARE_DEPENDENCY`, or `DOCUMENTED_UPSTREAM_GAP`.

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

Truth: `modules/user/ai/skills/default.nix` — the materialization of the module skills; this page is the procedure.
