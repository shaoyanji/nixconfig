# Mailbox mutation gate

Before any archive or delete action against the real mailbox:

1. Confirm scope explicitly with the user: archive only? delete? which file (final `live_batch_results_final.json` vs proposal `live_batch_stricter.json`)?
2. Confirm message IDs: the 208 archive labels from final file? Or a subset?
3. Confirm authorization is explicit (not inferred) — skill `jev-triage`: selection is not permission.
4. Never invent a `delete` judgment. Criteria define `archive`/`keep`; deletion requires a separate judgment.
5. Execute `himalaya` archive/delete commands only after 1-4.
