# MEMORY.md (Optimized)

## Scope
Governs memory operations, heartbeat checks, and logging flows.

## Silent Replies
Reply ONLY `NO_REPLY` when a command explicitly asks for a silent memory/logging response.

## Heartbeats
**Trigger Conditions** (if ANY met → describe the issue):
- Error rate >5% in last 10 operations
- Response latency >2s from any tier
- Failed retrieval from primary tier (xs)
- Quota usage >85%

**Default Response** (if none above):
- `HEARTBEAT_OK`

## Memory Tiers
| Tier | Purpose | Latency | Retention |
|------|---------|---------|-----------|
| **xs** | Working memory (real-time, event sourcing) | <10ms | 24 hours (auto-archive) |
| **grep** | Local files (session recovery) | <50ms | 30 days |
| **mem0** | Structured TOON format (`infer:false` preserves format) | <200ms | Permanent |
| **supermemory** | Philosophical/prose layer | <500ms | Permanent |
| **qmd** | Personal notes (query-on-demand) | <1s | Permanent |

## Retrieval Order (Priority)
1. SOUL snapshot (orientation)
2. xs (recent working memory) → *if unavailable, skip to grep*
3. grep (local files) → *if unavailable, skip to mem0*
4. mem0 (structured TOON)
5. supermemory (prose)
6. qmd (personal notes)

## Logging Rules

### What to Log & Where
| Event | Tier | Format | Example |
|-------|------|--------|---------|
| Task completed | mem0 | TOON | `[TASK] user_request → action → result` |
| Decision made | mem0 | TOON | `[DECISION] context → choice → rationale` |
| Error encountered | grep | Markdown | `YYYY-MM-DD.md: [ERROR] what failed, why` |
| User preference | supermemory | Prose | narrative about preference |
| Concept/philosophy | supermemory | Prose | deep concepts & frameworks |

### TOON Format Example
```
[TASK] User asked for memory optimization
→ Analyzed MEMORY.md structure
→ Generated 9 recommendations
✓ Delivered formatted output
```

## Eviction & Consistency

**xs → grep Migration:**
- Triggered: 24 hours elapsed OR xs quota full
- Process: Archive to `memory/YYYY-MM-DD.md`

**Conflict Resolution (Same Info, Multiple Tiers):**
- xs > grep > mem0 > supermemory (use most recent)

**Deduplication:**
- Check grep + mem0 before logging new entry
- Link related entries with timestamps

## Recovery Procedures
| Scenario | Action |
|----------|--------|
| mem0 unavailable | Route to supermemory; flag for sync |
| xs unavailable | Skip to grep immediately |
| All tiers down | Use local buffer + retry on recovery |

## Quota Management
- xs: 10MB (hard limit)
- grep: 100MB (soft limit)
- mem0: Unlimited (indexed)
- **Alert threshold:** 85% capacity on any tier

---

**Refer to** `backup_operating_docs/MEMORY.full.md` for advanced config, safety limits, and deprecation notices.
