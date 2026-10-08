# MEMORY.md (Unified Architecture)

## Scope

Governs memory operations, heartbeat checks, and logging flows across all tiers with BM25 hybrid search.

## Silent Replies

Reply ONLY `NO_REPLY` when a command explicitly asks for a silent memory/logging response.

## Heartbeats

**Trigger Conditions** (if ANY met → describe the issue):

- Error rate >5% in last 10 operations
- Response latency >2s from any tier
- Failed retrieval from primary tier (xs)
- Quota usage >85%
- BM25 index staleness >1 hour

**Default Response** (if none above):

- `HEARTBEAT_OK`

## Memory Tiers (Unified)

| Tier            | Purpose                                                 | Search Method    | Latency | Retention          | Indexing        |
| --------------- | ------------------------------------------------------- | ---------------- | ------- | ------------------ | --------------- |
| **context**     | Working memory (real-time, event sourcing)              | Direct lookup    | <10ms   | 24h (auto-archive) | None            |
| **qmd**         | Personal notes & queries (semantic/keyword hybrid)      | BM25 + vector    | <200ms  | Permanent          | Live BM25 index |
| **supermemory** | Philosophical/prose/context layer                       | BM25 + semantic  | <300ms  | Permanent          | Live BM25 index |
| **mem0**        | Structured TOON format (`infer:false` preserves format) | BM25 exact-match | <150ms  | Permanent          | Live BM25 index |
| **grep**        | Session recovery (fallback)                             | Regex + grep     | <500ms  | 30 days            | None            |

## Retrieval Strategy (Tiered + Hybrid Search)

### Phase 1: Direct Lookup (ctx only)

```
Query → ctx snapshot (orientation)
  ↓ (if hit) return
  ↓ (if miss) → Phase 2
```

### Phase 2: Parallel BM25 Search (qmd + supermemory + mem0)

```
Query → BM25 index across:
  • qmd (personal notes, high recall)
  • supermemory (conceptual prose, semantic ranking)
  • mem0 (structured TOON, exact term matching)
  ↓ (rank by relevance score)
  ↓ (if high confidence >0.7) return merged results
  ↓ (if low confidence) → Phase 3
```

### Phase 3: Fallback (grep and wikisearch)

```
Query → grep local files (YYYY-MM-DD.md)
  ↓ (session recovery, regex patterns)
  ↓ return results
```

## BM25 Configuration

| Parameter        | Value                                | Rationale                             |
| ---------------- | ------------------------------------ | ------------------------------------- |
| k1               | 1.5                                  | Standard term frequency saturation    |
| b                | 0.75                                 | Length normalization (moderate)       |
| Min term length  | 3 chars                              | Filter noise; exceptions: "AI", "I/O" |
| Field weights    | qmd:1.2 / supermemory:1.1 / mem0:1.0 | Prioritize personal notes slightly    |
| Refresh interval | 5 minutes                            | Balance freshness vs. performance     |
| Stale threshold  | 1 hour                               | Alert if index not updated            |

## Logging Rules

### What to Log & Where

| Event                | Tier        | Format              | BM25 Indexing          |
| -------------------- | ----------- | ------------------- | ---------------------- |
| Task completed       | mem0        | TOON (`[TASK]`)     | Yes (auto-index)       |
| Decision made        | mem0        | TOON (`[DECISION]`) | Yes (auto-index)       |
| Reasoning/concept    | supermemory | Prose narrative     | Yes (semantic tokens)  |
| Personal note/query  | qmd         | Markdown + tags     | Yes (keyword + vector) |
| Error encountered    | grep        | `YYYY-MM-DD.md`     | No (recovery only)     |
| Philosophy/framework | supermemory | Prose essay         | Yes (semantic tokens)  |

### TOON Format Example (mem0)

```
[TASK] User requested memory architecture redesign
→ Analyzed 5 existing tiers
→ Integrated BM25 hybrid search
✓ Delivered unified MEMORY.md with fallback chain
[TAGS] memory, architecture, bm25, optimization
[CONFIDENCE] 0.92
```

### qmd Entry Example

```
# Personal Query: When should I use vector vs BM25?
Tags: #search #optimization #hybrid-search

**Context:** Deciding search strategy for heterogeneous memory.

**Note:** BM25 excels at keyword precision (mem0 TOON logs).
Vector search better for semantic prose (supermemory philosophy).
Hybrid approach: BM25 for filtering, vector for ranking.

[INDEXED] 2024-01-15T10:42Z
```

### supermemory Entry Example

```
# Philosophy: Memory as Layered Cognition

Working memory (ctx) ↔ Recent context (qmd) ↔ Deep concepts (supermemory) ↔ Structured actions (mem0)

Each layer serves a different cognitive function. xs is reactive, qmd is reflective, supermemory is contemplative, mem0 is operational.

[INDEXED] 2024-01-15T10:45Z
[SEMANTIC_TAGS] memory-architecture, consciousness, layers
```

## Eviction & Consistency

**ctx → grep Migration:**

- Triggered: 24 hours elapsed OR xs quota full
- Process: Archive to `memory/YYYY-MM-DD.md`
- BM25: No re-indexing (grep is search-free)

**Conflict Resolution (Same Info, Multiple Tiers):**

1. ctx > qmd > supermemory > mem0 > grep (recency order)
2. BM25 relevance score as secondary tiebreaker
3. Manual merge if confidence <0.6

**Deduplication:**

- Check BM25 index before logging new entry
- Link related entries with `[RELATED_TO]` tags
- Consolidate duplicate concept entries in supermemory quarterly

## Recovery Procedures

| Scenario               | Action                                       | Fallback                   |
| ---------------------- | -------------------------------------------- | -------------------------- |
| BM25 index corrupted   | Rebuild from mem0 + qmd + supermemory (5min) | Use grep regex search      |
| mem0 unavailable       | Route to supermemory; flag for sync          | Query qmd + grep           |
| xs unavailable         | Skip to BM25 Phase 2                         | No performance impact      |
| All indexed tiers down | Use grep local files + xs snapshot           | Batch retry on recovery    |
| BM25 staleness >1h     | Force refresh; log heartbeat alert           | Continue with cached index |

## Quota Management

| Tier        | Limit                  | Alert Threshold   |
| ----------- | ---------------------- | ----------------- |
| ctx         | 10MB                   | 85% (8.5MB)       |
| qmd         | 50MB                   | 85% (42.5MB)      |
| supermemory | 100MB                  | 85% (85MB)        |
| mem0        | Unlimited (indexed)    | Index size >500MB |
| grep        | 100MB (30-day rolling) | 85% (85MB)        |

## Search Examples

### Example 1: Simple Query

```
Query: "What's my preference on async logging?"
→ ctx (miss)
→ BM25 Phase 2:
   • qmd hits: "async logging" tag → score 0.82
   • supermemory hits: "logging philosophy" → score 0.61
→ Return qmd result (highest confidence)
```

### Example 2: Complex Query

```
Query: "Integrate BM25 into memory architecture"
→ ctx (miss)
→ BM25 Phase 2:
   • mem0: "[TASK] BM25 integration..." → score 0.79
   • supermemory: "Layered cognition..." → score 0.68
   • qmd: "#search #optimization" notes → score 0.75
→ Merge top 3 results with relevance ranking
```

### Example 3: Fallback Query

```
Query: "Session from 2024-01-10"
→ ctx (miss)
→ BM25 Phase 2 (low confidence <0.5)
→ Phase 3 grep: "2024-01-10.md" → regex match
→ Return session recovery file
```

---

Wrapper binary for jev: `askjev` (shell wrapper at `~/.local/bin/askjev`, wraps `jev-decide classify --provider typesafe`). Real call returns `jev_called: true`, `transport: typesafe`. User-preferred openrouter model: `inception/mercury-decide:free` (not applied by askjev wrapper — call `jev-decide` directly for openrouter).

Tips for making official skills with wrappers:

1. The wrapper (`askjev`) loads keys from `~/.config/hermes/hermes.env`, exports `OPENROUTER_API_KEY` + `TYPESAFE_API_KEY`, builds a temp criteria JSON, then calls `jev-decide classify --provider typesafe --text "$QUESTION" --criteria`.
2. To make an official skill with a wrapper: define `SKILL.md` with trigger/description; add a `scripts/` wrapper that validates inputs (check `--help` before invoking), loads env, builds evidence files (not strings), and calls the underlying binary with `--dry-run` first.
3. Never invent invocation shapes — read the wrapper source (`cat /path/to/wrapper`) and the underlying binary's `--help` before writing the skill.
4. Log results back: `jev_called`, `transport`, `probability`, `margin`, model used, and whether the user overrode.
