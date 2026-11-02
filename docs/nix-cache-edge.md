# nix-cache-edge — the fleet's public cache on Cloudflare Workers + R2

A Nix binary cache that any host can substitute from, including one with neither
the LAN nor the tailnet. It is a **third tier**, not a replacement: harmonia on
frieren stays the LAN cache, cachix stays the 5 GB WAN cache, and this adds 10 GB
of R2 that CI can fill and anyone can read.

| Tier | Where | Who reads it | Budget |
| :--- | :--- | :--- | :--- |
| harmonia | frieren, `http://192.168.3.25:5000` | LAN hosts, priority 10 | the NAS store |
| cachix | `shaoyanji.cachix.org` | WAN hosts | 5 GB |
| edge | `https://nix-cache-edge.jisifu.workers.dev`, Worker over R2 | CI, any host, no tailnet | 10 GiB (free tier), hard |

It is a **buffer, not a mirror**: only paths that neither cachix nor
cache.nixos.org already serves are uploaded, so the 10 GiB holds fleet build
output rather than a second copy of nixpkgs. `dev:nixcache:push` refuses the whole
upload if it would cross the budget — the gate is the refusal, not a warning.

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

Deployed 2026-11-02 at `https://nix-cache-edge.jisifu.workers.dev`, key
`delphi.edge-1`. R2 had to be enabled in the dashboard first: an account that has
never activated it answers `wrangler r2 bucket create` with `Please enable R2
through the Cloudflare Dashboard [code: 10042]`, and the deploy then fails with
`R2 bucket 'nix-cache' not found`. `dev:nixcache:deploy` is unchanged either way.

`keygen` prints the public key and refuses to run twice: the key name is the
prefix of every signature, so rotating it means republishing the cache. The
secret lands in sops at `NIXCACHE.SIGNING.KEY`; the public half is what belongs in
`lib/cache-registry.nix` and every client's `trusted-public-keys`.

## Pushing: cachix first, then the budget

```bash
task dev:nixcache:push -- /nix/store/<hash>-<name>   # or .#<flake-attr>
task dev:nixcache:size                              # exits 1 at the limit
```

Four rules, in this order:

1. **Dedupe.** Every path in the closure gets one HEAD against cachix, then
   cache.nixos.org, then this bucket. Anything present anywhere is dropped before
   `nix copy` sees it. A run over `hello.drv`'s 342-path closure reported
   `2/342 path(s) are unique` and uploaded 2.
2. **Budget.** The nar sizes of the survivors plus the bucket's measured bytes are
   compared against `BUDGET_GIB` (10). Over the line it exits before writing:
   `refusing the push — it would take the bucket … over the 10 GiB limit by …`.
3. **Sign into a staging cache.** `nix copy --to file://stage` with
   `secret-key=` writes the signed narinfo locally. Two traps live here:
   `nix copy` is recursive by default (a two-path push uploaded 342 objects), and
   `--no-recursive` alone fails with `the reference … is not valid`, because a
   binary cache will not accept a narinfo whose references it lacks. The script
   seeds narinfo **stubs** for references and never uploads them, so each unique
   path goes up with its real narinfo and its own nar, and nothing else.
4. **Upload with rclone.** `nix copy --to s3://…` against a freshly recreated
   bucket exited 0 having written nothing at all — silent, which is the worst
   failure for a cache. rclone reports what it moved.

CI runs the same script per built attribute with repository secrets
(`NIXCACHE_SIGNING_KEY`, `NIXCACHE_R2_ACCESS_KEY_ID`, `NIXCACHE_R2_SECRET_ACCESS_KEY`,
`NIXCACHE_R2_ENDPOINT`) and `continue-on-error`, so a full bucket never fails a
build that succeeded, and a run where cachix took everything uploads nothing.

## Substituter order

Registered in `lib/cache-registry.nix` as `edge`, immediately **after `cachix`** in
`evalOrder`, `lanOrder` and `wanOrder`; `flake.nix`'s `nixConfig` mirrors it and
`checks:flake:cache` fails on any drift between the two. Being after cachix is not
just a preference: `dev:nixcache:push` never uploads what cachix already has, so
the overlap is empty by construction.

```nix
edge = {
  url = "https://nix-cache-edge.jisifu.workers.dev";
  key = "delphi.edge-1:SAQXl68hP2k5mhlWOIXCyQXFD1rVelBB22oTKQkFzwk=";
  role = "wan";
};
```

## Verify

```bash
task dev:nixcache:check                                               # offline gate
task checks:nixcache:probe -- https://nix-cache-edge.jisifu.workers.dev <hash>  # live, with a narinfo
curl -s https://nix-cache-edge.jisifu.workers.dev/nix-cache-info       # three fields
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

A client that asked about a path **before** it was pushed keeps answering "not a
valid path" afterwards, because nix caches the miss in
`/nix/var/nix/binary-cache-v*.sqlite`. `nix path-info --refresh --store <url>
<path>` bypasses it (measured 2026-11-02), as does deleting that file. The cache is
fine; the client's memory is stale.

That last command is the honest end-to-end check: `nix` fetched the narinfo from
the Worker, followed its `URL:` to `/nar/…`, verified the signature against a
trusted key and wrote the path into another cache (2026-11-02, one reference-free
`.patch`). A narinfo that is served but rejected by a client (`ignoring
substitute … not signed by a trusted key`) means the public key in the registry is
not the one the pusher signed with — check `NIXCACHE.SIGNING.KEY` in sops before
suspecting the Worker.

## Not done here

- **No garbage collection.** R2 has no lifecycle rule for "what a closure
  references"; the budget refusal is the only limit, so a full bucket must be
  emptied by hand — `rclone delete r2:nix-cache` (objects) and **not**
  `rclone purge`, which deletes the bucket itself and leaves `nix copy` failing
  silently (measured 2026-11-02; `dev:nixcache:deploy` recreates it).
- **CI secrets are not set.** The workflow's buffer step is inert until
  `NIXCACHE_SIGNING_KEY` and the three `NIXCACHE_R2_*` values exist as repository
  secrets; `dev:nixcache:keygen` prints the `gh secret set` line for the key.
- **No custom domain yet.** `workers_dev = true` in `wrangler.toml`; a `[[routes]]`
  block with `custom_domain` replaces it when the cache has a name.
- **CI does not read it yet.** The workflow pushes and still substitutes from
  cachix/nixpkgs; pointing it at the edge is a second step, after the registry has
  the entry and the probe is green from a runner.
