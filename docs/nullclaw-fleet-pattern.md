# Nullclaw Fleet Pattern

## Scope
This pattern standardizes nullclaw deployment across hosts while keeping host-specific logic explicit.

Shared module:
- `modules/services/nullclaw-deployment.nix`

Machine-readable operator manifest:
- `taskfiles/ai-host-manifest.json`

Operator waiver file (optional warning waivers only):
- `taskfiles/ai-host-waivers.json`

Current hosts and classes:
- `hosts/garnixMachine.nix`
  - `hostClass = wrapper`, `promotionGroup = canary`
- `hosts/mtfuji/configuration.nix`
  - `hostClass = wrapper`, `promotionGroup = stable`
- `hosts/thinsandy/configuration.nix`
  - `hostClass = direct`, `promotionGroup = stable`

## What the Shared Module Does
`aiServices.nullclawDeployment` wraps `aiServices.nullclaw` and provides:
- explicit host input surface for bind/port/workspace + secret/config mode
- optional staging of a runtime `config.json` into `workspaceRoot/.nullclaw`
- a single place for fleet-safe nullclaw host wiring

It does not manage:
- SOPS key material and encrypted payloads
- host networking/reverse-proxy policy
- host persistence/bind mounts

## Required Host Inputs
When `aiServices.nullclawDeployment.enable = true`, set:
- `mode` (`none` | `env-file` | `config-json`)
- `listenHost`
- `listenPort`
- `workspaceRoot`

Optional:
- `environmentFile` (required only for `mode = "env-file"`)
- `configJsonSource` (required only for `mode = "config-json"`)

## Add a New Machine
1. Import the module in the host file:
   - `../../modules/services/nullclaw-deployment.nix` (or equivalent relative path)
2. Enable profile/module as needed:
   - keep `profiles.aiHost.nullclaw.enable = true` if using the AI host profile
3. Set host-local values:
   - listen host/port
   - workspace root
   - secret source path(s)
4. Keep host-only concerns in the host:
   - SOPS secret declarations
   - firewall/proxy rules
   - bind mounts/persistence layout

Minimal host snippet:

```nix
aiServices.nullclawDeployment = {
  enable = true;
  mode = "env-file";
  listenHost = "127.0.0.1";
  listenPort = 3001;
  workspaceRoot = "/var/lib/nullclaw";
  environmentFile = config.sops.secrets.nullclaw.path;
  # or:
  # configJsonSource = config.sops.secrets.nullclaw-config.path;
};
```

## Fleet Replication Checklist
1. Keep nullclaw service logic in `modules/services/nullclaw.nix` and host rollout logic in `modules/services/nullclaw-deployment.nix`.
2. Keep host files data-oriented: only set deployment inputs, secrets, proxy/firewall, and persistence.
3. Keep secret handling explicit per host (`environmentFile` or `configJsonSource`), never both unless intentionally required.
4. Keep bind/port explicit per host (`listenHost`, `listenPort`) and verify with smoke checks.
5. Run `task checks:quick` before deployment changes.

## Deploy vs Promote
- Deploy path (plan/apply/validate) does not imply promotion complete.
- Promotion requires:
  1. `task checks:fleet`
  2. host validation success
  3. drift audit success
  4. freshness policy satisfied (validation/drift evidence age within manifest policy)
  5. no blocking findings in latest validation/drift evidence
  6. promotion receipt write
  7. baseline pointer update

## New-Machine Onboarding Checklist
1. Import `modules/services/nullclaw-deployment.nix` in the host module.
2. Enable nullclaw composition (`profiles.aiHost.nullclaw.enable = true` if using `profiles.aiHost`).
3. Set `aiServices.nullclawDeployment` inputs: `enable`, `listenHost`, `listenPort`, `workspaceRoot`.
4. Set host secret wiring:
   - env-file pattern: set `mode = "env-file"` + `environmentFile` and declare matching SOPS secret.
   - config-file pattern: set `mode = "config-json"` + `configJsonSource` and declare matching SOPS secret.
5. Keep host-only networking/storage explicit:
   - firewall/proxy rules
   - bind mounts/persistence paths
6. Validate and deploy:
   - `task checks:quick`
   - `task infra:plan:host:<host>`
   - `task infra:apply:host:<host>`
   - `task services:validate:host:<host>`
   - or one-shot: `task infra:deploy:host:<host>`
7. Promote (gated):
   - `task services:promote:host:<host>`
8. Optional git recording:
   - `task services:record:host:<host>`

## Evidence Flow
Evidence root:
- `evidence/ai-hosts/<host>/<timestamp>-<event>/`

Evidence files:
- `summary.json` (normalized: `host`, `timestamp`, `event`, `result`, class/group, counts, key findings)
- `findings.json` (normalized findings list with severity/category/check/status/expected/actual/message)
- `details.txt` (service status, socket checks, path readability checks, journal excerpt, nginx proxy expectation check when declared)

Operator tasks:
- Validate + evidence:
  - `task services:evidence:validate:host:<host>`
- Evidence only (no validation run):
  - `task services:evidence:capture:host:<host> EVENT=<event> VALIDATION_RESULT=<pass|fail>`

## Drift Audit Flow
Drift evidence root:
- `evidence/drift/<host>/<timestamp>-drift/`

Drift evidence files:
- `summary.json` (normalized: `host`, `timestamp`, `event=drift`, `result`, class/group, counts, key findings)
- `findings.json` (categorized findings with severity and expected vs actual)
- `details.txt` (human-readable findings + status/journal excerpts)

Operator tasks:
- Single host drift audit:
  - `task services:drift:audit:host:<host>`
- Canary drift audit:
  - `task services:drift:audit:canary`
- Class drift audit:
  - `task services:drift:audit:class:<wrapper|direct>`

Drift checks currently include:
- manifest-declared service active state
- manifest bind/port listener check
- workspace path existence
- manifest readable-path checks
- nginx upstream expectation when declared
- deployment-style inference from `systemctl cat nullclaw`

## Promotion Receipts and Baseline
Promotion receipt root:
- `evidence/promotions/<host>/<timestamp>-promotion/`

Promotion receipt files:
- `receipt.json`
- `details.txt`

Promotion attempts always run finalize and emit a receipt. Failed promotions emit `result=fail` with `readiness_reason`.

Per-host baseline pointer:
- `evidence/promotions/<host>/baseline.json`

`baseline.json` marks the promoted known-good evidence set for future comparisons.

## Fleet Status Synthesis
Status tasks (manifest + evidence only):
- Fleet status:
  - `task services:status:ai-hosts`
- Single-host status:
  - `task services:status:host:<host>`
- Promotion-readiness view:
  - `task services:status:promotion-readiness`
- Delta view (latest good validation vs latest drift):
  - `task services:status:delta:host:<host>`

Status output now includes baseline presence (`BASELN`) and baseline update timestamp.
Status output also includes baseline age in seconds (`B_AGE`).

Promotion-readiness is currently:
1. latest validation evidence exists and `result=pass`
2. latest drift evidence exists and `result=pass`
3. latest drift timestamp is not older than latest validation timestamp
4. latest validation evidence age <= host policy `maxValidationAgeSeconds`
5. latest drift evidence age <= host policy `maxDriftAgeSeconds`
6. latest validation/drift evidence has zero blocking failures (severity `blocking`, with legacy `critical` treated as `blocking`)

If only warning findings remain, host status is reported as `ready:with-warnings`.
Warning waivers (if configured) are applied only to warning findings and never to blocking findings.

Policy source:
- `taskfiles/ai-host-manifest.json`
  - top-level defaults: `policyDefaults.maxValidationAgeSeconds`, `policyDefaults.maxDriftAgeSeconds`
  - optional host override: `.hosts.<host>.policy.maxValidationAgeSeconds`, `.hosts.<host>.policy.maxDriftAgeSeconds`

## Failure Rehearsal Flow
Supported safe rehearsal fingerprints:
- `missing-readable-path`
- `missing-listener`
- `nullclaw-inactive`
- `nginx-upstream-mismatch`

Rehearsal command:
- `task services:rehearse:nullclaw:host:<host> FINGERPRINT=<name>`

Rehearsal behavior:
1. capture baseline validation evidence
2. run simulated drift audit for the fingerprint (expected to fail)
3. capture post-recovery validation evidence
4. run normal drift audit to confirm steady state

These rehearsals are simulation-based checks against expectations; they do not mutate host config or stop services.

## Promotion Gates
- Single host:
  - `task services:promote:host:<host>`
- Canary group:
  - `task services:promote:canary`
- Host class:
  - `task services:promote:class:<wrapper|direct>`

All promotion tasks require:
- fleet check (`checks:fleet`)
- successful host validation
- successful drift audit
- successful promotion finalize step (`services:promote:finalize:host:*`)
  - validation evidence exists and passes
  - drift evidence exists and passes
  - drift evidence is not older than validation evidence
  - validation/drift evidence is fresh per manifest policy
  - validation/drift evidence has zero blocking failures
  - writes promotion receipt
  - updates baseline pointer
- promotion tasks remain separate from drift audits and rehearsals

Promotion finalize writes a receipt even for failed attempts (`result=fail`) with a concrete `readiness_reason` (for example `validation-stale`, `drift-stale`, `validation-blocking-findings`).

## Severity and Waivers
Normalized severities:
- `info`
- `warning`
- `blocking`

Backward compatibility:
- older evidence using `critical` is treated as `blocking` during readiness/promotion evaluation.

Waivers are file-based and optional:
- file: `taskfiles/ai-host-waivers.json`
- scope: per-host warning findings only
- matching keys: `category`, `check`, optional `expected`
- optional fields: `reason`, `expiresAt`, `severity` (`warning` only)
- waivers never override blocking findings

## Rollback Checklist
1. Roll back target host generation:
   - `task services:rollback:apply:host:<host>`
2. Validate and capture rollback evidence:
   - `task services:evidence:rollback:host:<host>`
3. One-shot rollback flow:
   - `task services:rollback:host:<host>`
4. Optional git recording remains manual:
   - `task services:record:host:<host>`

## Top Failure Fingerprints
1. `systemctl status nullclaw` shows restart loop.
   - Common cause: unreadable/invalid staged config file from `configJsonSource`.
2. Service is active but `127.0.0.1:3001` listener is missing (or wrong bind/port).
   - Common cause: wrong `listenHost` or `listenPort`.
3. `/run/secrets/...` path missing or unreadable at runtime.
   - Common cause: host SOPS secret declaration/key setup mismatch.
4. Required workspace paths missing (`${workspaceRoot}`, `.nullclaw`, `workspace`).
   - Common cause: host persistence/filesystem assumptions not met.
5. Reverse proxy works but points to wrong backend port/service.
   - Common cause: host nginx/firewall rules not updated consistently with intended exposure.

## Known Limitations / Deferred Items
- No synthetic integration test spins up a VM; checks are eval-time plus host smoke checks.
- Health endpoint path is host/service-version dependent, so smoke task keeps it optional.
- The shared module assumes the service identity from `modules/services/nullclaw.nix` (`systemd.services.nullclaw`, user/group `nullclaw`).
- Evidence capture requires local `jq` and remote host access for `ssh`, `systemctl`, `ss`, and `journalctl`.
- Drift rehearsal fingerprints are expectation simulations, not destructive host fault injection.
- Fleet status synthesis is evidence-driven; hosts without recent evidence are reported as not-ready/missing evidence.
- Baseline-aware delta prefers promoted baseline when present; if missing, it falls back to latest good validation evidence.
