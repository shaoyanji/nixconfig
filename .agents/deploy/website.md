# Website / Static Deploy

## Scope
Current non-AI deploy surface for website/static sync operations.

## Source Of Truth
- Task entrypoint: `taskfiles/dev.yml`

## Current Surface
- `dev:site:sync-verntil` (alias: `verntil`) syncs local `index.html` to the `verntil` host.

## Notes
This repo does not currently expose a larger website deployment control-plane comparable to AI host flows.
Use this surface as a targeted utility, not a general deployment framework.
