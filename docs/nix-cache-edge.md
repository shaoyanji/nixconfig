# nix-cache-edge — the fleet's public cache on Cloudflare Workers + R2

A Nix binary cache that any host can substitute from, including one with neither
the LAN nor the tailnet. It is a **third tier**, not a replacement: harmonia on
frieren stays the LAN cache, cachix stays the 5 GB WAN cache, and this adds 10 GB
of R2 that CI can fill and anyone can read.

| Tier | Where | Who reads it | Budget |
| :--- | :--- | :--- | :--- |
| harmonia | frieren, `http://192.168.3.25:5000` | LAN hosts, priority 10 | the NAS store |
| cachix | `shaoyanji.cachix.org` | WAN hosts | 5 GB |
| edge | `nix-cache-edge` Worker over R2 | CI, any host, no tailnet | 10 GiB (free tier) |

| Layer | Home |
| :--- | :--- |
| the Worker (GET/HEAD only) | `modules/services/nix-cache-edge/src/worker.ts` |
| path grammar, range and cache-info rules | `modules/services/nix-cache-edge/src/routes.ts` |
| bucket, binding, priority, route | `modules/services/nix-cache-edge/wrangler.toml` |
| deploy / probe / size / keygen / push | `scripts/task/nixcache.sh` |
| the deploy toolchain on the host that deploys | `hosts/delphi/nix-cache-edge.nix` |
| credentials | sops `apikeys.yaml` → `CLOUDFLARE.*` (already there) |
| substituter registration | `lib/cache-registry.nix` (only after `checks:nixcache:probe` passes) |

## Why the design looks like this

**The edge does not sign, and holds no secret.** A narinfo must be signed by
whoever writes it, and that writer is `nix copy`, which signs from
`secret-key-files` on the *pushing* client. A Worker that signed instead would
have to reimplement Nix's fingerprint (`1;<storePath>;<narHash>;<narSize>;<refs>`)
and own narinfo generation — a second implementation of the thing that already
works, plus a private key on a public endpoint. So the Worker has exactly one
binding (`BUCKET`) and reads.

**Uploads go through R2's S3 API, not through the Worker.** `nix copy --to
https://…` cannot authenticate a write: the HTTP binary-cache store has no
bearer-token support (`nix copy --help` exposes no `--header`), so a
`CACHE_AUTH_TOKEN` secret on a PUT route would be a lock no client can open. R2
speaks S3, `nix copy --to 's3://nix-cache?endpoint=…&region=auto'` writes the
bucket layout the Worker already serves, and the public route stays GET-only.

**The credentials were already in sops.** `CLOUDFLARE.ACCOUNT.ID`,
`CLOUDFLARE.API.TOKEN` and the R2 S3 pair (`ACCESS.KEY.ID`,
`SECRET.ACCESS.KEY`) plus `S3.API.ENDPOINT` existed for the Pages deploys; this
reads them at run time with the user's age key, so nothing is declared in Nix and
no rebuild is involved (`scripts/task/wrangler.sh` made the same argument).

**No KV metrics namespace.** A counter write per GET would add a billable,
latency-bearing side channel to the read path for numbers Workers analytics
already report. Nothing reads those counters, so they are not written.

**`nix-cache-info` carries `Priority: 30`.** Lower wins in nix. harmonia advertises
10 and is LAN-only, so a LAN build never leaves the house; the ordering across
WAN tiers is `lib/cache-registry.nix`'s `evalOrder`, not this file's.

## First deploy

```bash
task dev:nixcache:check                       # offline: 17 tests + a real wrangler bundle
task dev:nixcache:deploy                      # bucket if absent, then the Worker
task dev:nixcache:keygen KEY_NAME=delphi.cache-1
task checks:nixcache:probe URL=<the workers.dev URL wrangler prints>
```

**R2 must be enabled on the account first, and only the dashboard can do it.**
`wrangler r2 bucket create` answers `Please enable R2 through the Cloudflare
Dashboard [code: 10042]` on an account that has never activated R2, and the
Worker deploy then fails with `R2 bucket 'nix-cache' not found` (measured
2026-11-02). The token itself was fine — the same call authenticated and listed
the account; enabling R2 is a one-time click, after which `dev:nixcache:deploy`
re-runs unchanged.

`keygen` prints the public key and refuses to run twice: the key name is the
prefix of every signature, so rotating it means republishing the cache. The
secret lands in sops at `NIXCACHE.SIGNING.KEY`; the public half is what belongs in
`lib/cache-registry.nix` and every client's `trusted-public-keys`.

## Pushing

```bash
# one path, the same write path CI uses (signed locally, key never in argv)
task dev:nixcache:push STORE_PATH=/nix/store/<hash>-<name>

# budget before and after: R2 has no per-bucket quota, so it is measured
task dev:nixcache:size                        # exits 1 at 10 GiB, warns at 90%
```

CI runs the same `nix copy --to s3://…` with `NIXCACHE_*` repository secrets, and
only for hosts whose closure fits the budget. The `s3://` store writes
`nix-cache-info`, `<hash>.narinfo` and `nar/<file>` — exactly the three paths the
Worker serves.

## Registering it as a substituter

Only after `checks:nixcache:probe` passes: an unreachable substituter costs a
connect timeout on every path of every build, which is why the entry is a
deliberate step rather than part of the deploy.

```nix
# lib/cache-registry.nix
edge = {
  url = "https://<the workers.dev URL or custom domain>";
  key = "<public key from dev:nixcache:keygen>";
  role = "wan";
};
```

Then add `"edge"` to `evalOrder` after `harmonia` and before `cachix` — and run
`task checks:flake:cache` (the parity check that compares `flake.nix`'s
`nixConfig` with this registry) before trusting the result.

## Verify

```bash
task dev:nixcache:check                                        # offline gate
task checks:nixcache:probe URL=<url> STORE_HASH=<hash>         # signed narinfo over the wire
curl -s <url>/nix-cache-info                                   # three fields
```

The whole read path can be proved without a Cloudflare account, which is what
`wrangler dev --local` is for — Miniflare serves the real Worker against a local
R2, and a real `nix` client then substitutes through it:

```bash
cd modules/services/nix-cache-edge && wrangler dev --local --port 8787
# in another shell, seed one path the way a pusher would
nix key generate-secret --key-name probe-1 > /tmp/sk
nix copy --to "file:///tmp/lc?secret-key=/tmp/sk" /nix/store/<a-path-with-no-refs>
wrangler r2 object put nix-cache/<hash>.narinfo --file /tmp/lc/<hash>.narinfo --local
wrangler r2 object put "nix-cache/$(grep -m1 '^URL: ' /tmp/lc/<hash>.narinfo | cut -d' ' -f2)" \
  --file "/tmp/lc/$(grep -m1 '^URL: ' /tmp/lc/<hash>.narinfo | cut -d' ' -f2)" --local
# and read it back through the edge
nix key convert-secret-to-public < /tmp/sk
NIX_CONFIG="trusted-public-keys = probe-1:<public>" \
  nix copy --from http://127.0.0.1:8787 --to file:///tmp/verify /nix/store/<that-path>
```

That last command is the honest end-to-end check: `nix` fetched the narinfo from
the Worker, followed its `URL:` to `/nar/…`, verified the signature against a
trusted key and wrote the path into another cache (2026-11-02, one reference-free
`.patch`). A narinfo that is served but rejected by a client (`ignoring
substitute … not signed by a trusted key`) means the public key in the registry is
not the one the pusher signed with — check `NIXCACHE.SIGNING.KEY` in sops before
suspecting the Worker.

## Not done here

- **Not deployed yet.** R2 is not enabled on the account, so the bucket does not
  exist and no public URL has been issued; the code, the offline gate and the
  local end-to-end substitution are done, the deploy is one dashboard click away.
- **No garbage collection.** R2 has no lifecycle rule for "what a closure
  references"; the budget gate is the only limit, so the bucket must be emptied by
  hand (`rclone purge r2:nix-cache`) when a push is refused for space.
- **No custom domain yet.** `workers_dev = true` in `wrangler.toml`; a `[[routes]]`
  block with `custom_domain` replaces it when the cache has a name.
- **CI does not read it yet.** The workflow pushes and still substitutes from
  cachix/nixpkgs; pointing it at the edge is a second step, after the registry has
  the entry and the probe is green from a runner.
