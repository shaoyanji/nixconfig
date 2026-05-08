# TODO / Handoff

## Current Open Work
1. Documentation alignment completed (April 30, 2026) - All documentation now reflects simplified task control plane and current AI services state. See [AUDIT.md](AUDIT.md) for full details.

## TestVM Follow-Up
1. Inventory every host that embeds or plans to embed `testvm`-style microVM wiring.
2. Extend the shared guest baseline only when host-local bridge/share differences stay small.
3. Keep host-local bridge/NAT, bind mounts, persistence, and external interface choices in the host files.
4. Decide whether the standalone `testvm` output should eventually move into `modules/profiles/*` or stay under `hosts/microvms/*`.

## Things To Avoid
- Do not do a broad host rewrite in one pass.
- Do not move secrets or encrypted data.
- Do not silently widen system support.
- Do not assume Garnix persistence.
- Do not merge host-local storage layout into shared modules unless the reuse is clearly real.

## Immediate Next Reasonable Tasks
1. Watch `hosts/common` for new wrapper-only detours and prefer canonical modules or shared profiles when possible.
2. Review `disko` as the remaining architecture exception (documented with design comment).
3. Extend the shared `testvm` baseline only if another host genuinely needs it.
