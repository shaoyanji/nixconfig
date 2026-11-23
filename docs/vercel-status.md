# Vercel status outlet

The Vercel project attached to this repo serves `vercel/` as a two-zone fleet
status surface — the thing the tailnet cannot give you: a fleet check from
anywhere, and a sentinel mirror that does not require being on the tailnet.

## Zones

| Path | What | Gate |
| :--- | :--- | :--- |
| `/` | Cards for every public surface (CV, mockup, gallery, docs, dragoncourt, neocities, envs), each probed live by `/api/check` | none — public surfaces only |
| `/api/check` | Serverless probe, allowlist only (`vercel/api/check.js` `TARGETS`); unknown `?name=` dies at 400, so it is never an open proxy | allowlist |
| `/ops` | Page shell — renders `status:<host>` snapshots like the sentinel dashboard | public shell, **carries no data** |
| `/api/ops` | Reads the Edge Config items `status:*` | `Authorization: Basic` vs `OPS_BASIC_AUTH`; 401 + challenge, 503 unconfigured — fails closed |

Private telemetry (disk, PSI, failed units, job results) crosses exactly one
function, `/api/ops`, behind basic auth. The Edge Config store has no public
URL of its own; reads need the connection string Vercel injects as
`EDGE_CONFIG` when a store is linked to the project.

## Data path

`fleet-sentinel` on frieren writes `/var/lib/fleet-sentinel/www/status.json`
every collection tick (unchanged — tailnet stays the source of truth).
`task ops:status:publish` (`scripts/task/vercel-publish.sh`) PATCHes that
snapshot into the Edge Config as `status:<host>`. Any host that runs the
publish task with the env set appears on `/ops` — one store, one item per
host.

## Operator setup (one time, dashboard)

1. Project → Settings → General → **Root Directory** = `vercel`. The empty
   deployment becomes this site on next push.
2. Project → Settings → Environment Variables → `OPS_BASIC_AUTH` = `user:pass`.
3. Storage → Edge Configs → create one, link to the project (injects
   `EDGE_CONFIG`), note its `ecfg_…` id.
4. vercel.com/account/tokens → scoped token → into sops, and set
   `VERCEL_TOKEN` + `VERCEL_EDGE_CONFIG_ID` where the publish task runs.
5. `task ops:status:publish` on frieren; a systemd timer can call it on the
   sentinel cadence once the env exists (sops env file — do not commit it).

## Fixture

`checks:vercel:test` (`tests/vercel-status/run.sh`) runs `smoke.mjs` over the
two API functions in `checks:quick`: probe allowlist refusal, and every rung
of the ops gate failing closed.
