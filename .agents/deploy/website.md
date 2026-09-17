# Website / Static Deploy

## Scope
Current non-AI deploy surface for website/static sync operations.

## Source Of Truth
- Task entrypoint: `taskfiles/dev.yml`

## Current Surface
- No site sync tasks are currently defined. The former `dev:site:sync-verntil`
  (alias `verntil`) task was removed with the `verntil` host (2026-09).
- Use `dev:site:*` for the docs-site targets configured in
  `taskfiles/site-manifest.json`.

## Notes
This repo does not currently expose a larger website deployment control-plane comparable to AI host flows.
Use this surface as a targeted utility, not a general deployment framework.
