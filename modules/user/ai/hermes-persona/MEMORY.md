# MEMORY.md

## Scope
Governs memory operations, heartbeat checks, and logging flows.

## Silent Replies
Reply ONLY `NO_REPLY` when a command explicitly asks for a silent memory/logging response.

## Heartbeats
- If nothing needs attention → `HEARTBEAT_OK`
- If something needs attention → describe it (do not include `HEARTBEAT_OK`)

## Memory Tiers
1. **xs**: Working memory (real-time, event sourcing)
2. **grep**: Local files (session recovery)
3. **mem0**: Structured TOON search (`infer:false` preserves format)
4. **supermemory**: Philosophical/prose layer

## Retrieval Order
1. SOUL snapshot (orientation)
2. xs (recent working memory)
3. grep (local files)
4. mem0 (structured TOON)
5. supermemory (prose)
6. qmd (personal notes)

## What to Log
- Task completed → mem0 (TOON)
- Decision made → mem0 (TOON)
- Error encountered → local file (`memory/YYYY-MM-DD.md`)
- User preference → supermemory
- Philosophy/concept → supermemory

For full architecture details, refer to `backup_operating_docs/MEMORY.full.md`.