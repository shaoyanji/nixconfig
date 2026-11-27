---
name: jev-email-cleansing
category: agents-sync
description: Email archive triage via jev-decide; smoke-test; tags only.
---

# Email cleansing with jev-decide

Class: aggressive archive judgment via `jev-decide`. Archive = review table only; never mailbox mutation. Smoke-test pilot before bulk (>10). Frozen sample fallback when himalaya fails.

Always-on rules: pick provider via `jev-decide setup`. Criteria JSON uses `typesafe/jev-1.13` model string. Confirm aggressive/conservative first.

Procedure: 1. Keys/setup. 2. Confirm intent. 3. Sample (live or frozen `.json`). 4. Criteria file (`archive`/`keep`). 5. `--dry-run`. 6. Pilot 5 records; log exit/probability/model. Stop on exit!=0. 7. Report review table. 8. Full batch only with authorization; preserve IDs; bounded concurrency.

Pitfalls: missing `model` string = exit 1; export `TYPESAFE_API_KEY` into subprocess env; never embed mailbox mutation in criteria. Before any mailbox archive/delete, confirm scope explicitly: archive vs delete, final vs proposal file, which message IDs. Never invent a `delete` judgment — the criteria only define `archive`/`keep`; deletion requires a separate explicit authorization and judgment. The CLI binary is `agy` (not `antigravity`). See `jev-triage` for smoke-test agreement rules. See `references/mailbox-mutation-gate.md`.

Truth: `scripts/task/email-sweep.py` — the mailbox read path; this page is the judgment procedure.
