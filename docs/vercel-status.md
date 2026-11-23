# Vercel status outlet

The Vercel project attached to this repo serves `vercel/` as a public fleet
status page — the thing the tailnet cannot give you: a check on every public
surface from anywhere. No secrets, no tokens, no storage — it deploys from the
git integration alone.

## Surface

| Path | What | Gate |
| :--- | :--- | :--- |
| `/` | Cards for every public surface (CV, mockup, gallery, docs, dragoncourt, neocities, envs), each probed live by `/api/check` | none — public surfaces only |
| `/api/check` | Serverless probe, allowlist only (`vercel/api/check.js` `TARGETS`); unknown `?name=` dies at 400, so it is never an open proxy | allowlist |

**Private telemetry is not published at all.** Sentinel data (disk, PSI,
failed units, job results) stays on the tailnet at `sentinel.frieren.lan` —
the deliberate alternative to gating it behind a Vercel credential, which
would need a `VERCEL_TOKEN` + Edge Config store + a push path on frieren.
If an off-tailnet ops mirror is ever wanted, that push design is the way to
re-add it.

## Operator setup (one time, dashboard)

Project → Settings → General → **Root Directory** = `vercel`. The empty
deployment then serves this site on the next push. No env vars, no secrets,
no build command — `api/*.js` are zero-config serverless functions.

## Fixture

`checks:vercel:test` (`tests/vercel-status/run.sh`) runs `smoke.mjs` over the
API function in `checks:quick` and asserts no gated-store/token machinery is
reintroduced into the deployment.
