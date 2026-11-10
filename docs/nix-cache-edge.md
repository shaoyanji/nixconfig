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

It is a **buffer, not a mirror**: only paths that no other substituter already
serves are uploaded, so the 10 GiB holds fleet build output rather than a second
copy of nixpkgs. `dev:nixcache:push` refuses the upload if it would cross the
budget — the gate is the refusal, not a warning.

**It does not hold a system closure, and it is not supposed to.** See
[Why a system closure fits](#why-a-system-closure-fits) for the measurement: an
18 GiB NixOS closure contributes well under 1 GiB here, because a cache that
stores the delta and leaves the rest to nixpkgs is the only kind that fits in a
bucket. A cache that stored whole closures would need ~100 GiB for this fleet —
that is a cost decision, not a technical one, and it is the wrong one.

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

## Pushing: every substituter first, then the budget

```bash
task dev:nixcache:push -- /nix/store/<hash>-<name>   # or .#<flake-attr>
task dev:nixcache:size                              # exits 1 at the limit
```

Four rules, in this order:

1. **Dedupe against the whole registry.** Every path in the closure gets one HEAD
   per cache in `lib/cache-registry.nix` that is not `role = "lan"`: cachix, this
   bucket, cache.nixos.org, numtide, nix-community, nix-gaming, determinate.
   Anything found anywhere is dropped before `nix copy` sees it, and the run
   prints which substituter absorbed how many paths. Two runs, for scale: a
   `hello.drv` closure reported `2/342 path(s) are unique`; delphi's 2728-path
   system closure reported `365/2728` (table below).
2. **Budget.** The nar sizes of the survivors plus the bucket's measured bytes are
   compared against `BUDGET_GIB` (10). The run prints the five largest survivors,
   because in practice a handful of paths decide the total, and over the line it
   exits before writing: `refusing the push — it would take the bucket … over the
   10 GiB limit by …`. A single path larger than the whole budget says so by name
   instead, since gc cannot make room for it.
3. **Sign into a staging cache.** `nix copy --to file://stage` with
   `secret-key=` writes the signed narinfo locally. Two traps live here:
   `nix copy` is recursive by default (a two-path push uploaded 342 objects), and
   `--no-recursive` alone fails with `the reference … is not valid`, because a
   binary cache will not accept a narinfo whose references it lacks. The script
   seeds narinfo **stubs** for references and never uploads them, so each unique
   path goes up with its real narinfo and its own nar, and nothing else.
4. **Upload with rclone.** `nix copy --to s3://…` against a freshly recreated
   bucket exited 0 having written nothing at all — silent, which is the worst
   failure for a cache. rclone reports what it moved, and the script then HEADs
   the first object through the public edge: a push nobody can read is not a
   push.

CI runs the same script per built attribute with repository secrets
(`NIXCACHE_SIGNING_KEY`, `NIXCACHE_R2_ACCESS_KEY_ID`, `NIXCACHE_R2_SECRET_ACCESS_KEY`,
`NIXCACHE_R2_ENDPOINT`) and `continue-on-error`, so a full bucket never fails a
build that succeeded, and a run where cachix took everything uploads nothing.

## Why a system closure fits

This is the question the 10 GiB budget raises first, so here is the measurement
rather than the reassurance. Delphi's live system closure, 2026-11-02:

```bash
nix path-info --recursive --json /run/current-system   # 2728 paths, 18.48 GiB nar
```

One HEAD per path per cache, in registry order, sorted the paths into four groups:

| Where the path already lives | Paths | nar |
| :--- | ---: | ---: |
| cache.nixos.org | 2158 | 16.09 GiB |
| `shaoyanji.cachix.org` | 167 | 142 MiB |
| `cache.numtide.com` | 27 | **1.40 GiB** |
| `nix-community.cachix.org` | 11 | 135 MiB |
| nowhere (uploaded here) | 365 | **771 MiB** |

The numtide row is the one that matters most and is easy to miss: the fleet's own
agent CLIs — `dsh` at 685 MiB, `antigravity-cli` at 256 MiB, `hermes-agent` at
193 MiB, `freebuff` at 130 MiB — are built from `llm-agents.nix` and published to
numtide's cache. They are the fleet's packages but not the fleet's *unique*
output, so uploading them here would spend 1.4 GiB of a 10 GiB bucket on bytes
any host already has (and 18 % of the whole closure's unique set). The dedupe
only worked that out once it asked every substituter, not three of them: with the
old hardcoded triple the same push would have uploaded 2.39 GiB.

What is left is real: `stirling-pdf` 334 MiB, `atuin` 76 MiB, `llama-index-core`
46 MiB, `npgsqlrest` 36 MiB, plus a long tail of wrappers and config files. At
771 MiB per system, 10 GiB holds **about thirteen full systems** — or more once
consecutive generations share paths, which they do for everything except the
toplevel and the packages that changed.

The budget is also counted high on purpose: `BUDGET_GIB` compares against
**uncompressed** nar sizes while the bucket stores compressed nars. The first real
sync of delphi's system put **342 paths / 693 MiB of nar** in the bucket as
**0.44 GiB / 694 objects** — a ~35 % margin in the refusal's favour, so a bucket
that reports under budget is under budget.

So the answer to "a NixOS closure is 18 GiB, how does this fit" is that a
closure is never stored; a *delta* is. A client substitutes the toplevel from the
edge and its references from whichever cache has them, which is what every
substituter list in `lib/cache-registry.nix` exists for. The consequence to
respect: **the edge is not self-contained.** A host that lists only the edge
cannot fetch a system from it. A host that lists the registry can.

## Monthly sync: who builds what

```bash
task dev:nixcache:sync -- --hosts delphi,minyx      # build + push, on the right machine
task dev:nixcache:sync -- --dry-run                # the plan, nothing built
```

`sync` is routing; `push` keeps the three rules. For each host it evaluates the
system, builds it **where its arch belongs**, then hands the path to `push`:

| Hosts | Arch | Builder | Why |
| :--- | :--- | :--- | :--- |
| delphi, minyx | aarch64 | **delphi, native** | delphi already owns the bucket, the key and the gc, and it is the arch the official aarch64 caches were built from — so the inputs are local and only the delta this bucket exists for is compiled |
| the x86_64 hosts | x86_64 | CI runner, or a host with `/etc/nix/machines` | a 2-OCPU ARM box cannot compile that closure; `--max-jobs 0` means "offload or fail" and a box with no machines file is reported **SKIPPED**, never compiled locally |

Two rules the schedule depends on:

**Only `status = "active"` hosts are targets.** `inventory.toml` has active,
legacy and preserved; a dormant host's closure is not worth a build-second, and a
preserved one is not even guaranteed to evaluate. Every loop filters on active,
so reviving a host is the deliberate act that puts it back in scope.

**The timer collects before it pushes.** A refused push is the budget gate doing
its job, so the monthly unit runs `dev:nixcache:gc -- --delete` first and
`--hosts delphi,minyx` second — delphi's own aarch64 half. x86_64 is CI's half:
it has a runner per arch and maps host→runner from the same inventory.

On delphi the schedule is a **user** unit (`hosts/delphi/nix-cache-edge.nix`),
because the R2 keys and the signing key are decrypted with the operator's age
key: `nixcache-sync.timer`, monthly, `Persistent=true`, 3 h start timeout.

```bash
systemctl --user list-timers nixcache-sync.timer
journalctl --user -u nixcache-sync --since -1month
```

## A microfix that rebuilds the fleet

The complaint this answers: an agent edits one module, every host's toplevel
becomes a different derivation, and the next switch stops being a substitution.
The edit was small; the bill was a closure.

```bash
task checks:invalidation                        # against origin/main
task checks:invalidation -- HEAD~1 --hosts delphi --max-builds 0
```

It scopes the diff to the hosts it can reach — a `hosts/<h>/` edit is that host,
anything else in the module tree is chain-wide and is **sampled** (`--full` for
all) — then asks Nix how many derivations would be built:

```
nix build --dry-run --json --builders "" .#nixosConfigurations.<host>.config.system.build.toplevel
```

`--dry-run` builds nothing and `--builders ""` means the question cannot reach
nixbuild.net and spend the month's budget. The count is the chore: 1–3 is a
microfix, hundreds is a new stdenv or an overlay change. Over `MAX_BUILDS` (5)
the check fails and **names the derivations**, which is what tells an agent which
layer the edit reached.

## Who does not push

Delphi runs no `profiles.cachePush`. A post-build-hook fires for every locally
built output as nix-daemon, so a switch that builds anything on this 2-vCPU
guest turns into a NAR re-compress and upload per derivation, with the copies
outliving the rebuild. What delphi needs is the read direction: `cachix` already
sits in the WAN tier of `fleet.inventory.cache.delphi`, so CI-built artifacts
are substituted with no token and no hook.

## Retention and collection

Two mechanisms, because they answer different questions.

**The lifecycle rule is the backstop** (`expire-buffer`, applied by
`dev:nixcache:deploy`, so it is a property of the bucket and not of a dashboard
visit): objects expire **365 days after upload**, bucket-wide. One rule for both
prefixes on purpose — a narinfo and its nar are written in the same second and
must expire in the same second. A narinfo whose nar is gone is a hard client
failure; a missing narinfo is only a cache miss. Cloudflare's own
`Default Multipart Abort Rule` (7 days) stays alongside it.

A year, and not cachix's 90 days, because here the lifecycle is not the
collector. Cachix expires on **90 days without a request**, which it can see
because it serves every fetch; this Worker cannot (below). Age-on-upload is the
proxy, and a proxy that fires early deletes by calendar rather than by need — so
it is set where the claim "nobody re-pushed this" becomes true of the path, and
`gc` is what actually reclaims space.

**The gc task is cachix's shape** (`dev:nixcache:gc`, dry run unless
`-- --delete`): sort by age, delete the oldest until the bucket is back under 75%
of 10 GiB, at most 50 paths per run, always a narinfo with its nar.

```bash
task dev:nixcache:gc                  # what would go, oldest first, with sizes
task dev:nixcache:gc -- --delete      # actually collect
```

One difference from cachix is deliberate and worth stating: cachix sorts by
**last access** because it sees every request. This Worker cannot — narinfo is
served `Cache-Control: immutable`, so Cloudflare answers the repeats and the
origin only ever observes misses, which would make a recorded "last access" a
measurement of cache misses rather than of use. **Upload age is the honest stand-in**,
and it self-corrects: a path a build still needs gets re-pushed, which refreshes
it. The two mechanisms also compose with the push gate — when `push` refuses
because the bucket is at 10 GiB, `gc -- --delete` is what makes room.

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
task checks:nixcache:fleet                                           # every active host asks it, and it answers
task checks:nixcache:probe -- https://nix-cache-edge.jisifu.workers.dev <hash>  # live, with a narinfo
curl -s https://nix-cache-edge.jisifu.workers.dev/nix-cache-info       # three fields
```

`checks:nixcache:fleet` is the enablement gate: the compiled policy must carry
the edge — **after cachix** — in every active host's `substituters` and its key in
`trustedKeys` (0.2 s, no host eval), one host's evaluated
`config.nix.settings.substituters` must carry it too (the policy is only real if
it reaches the setting), and the live URL must answer `nix-cache-info` with 200.

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

**This preview is for editing the Worker; the deployed edge needs none of it.**
Run it in tmux — a tool shell owns its process group, so `&`/`nohup` orphan the
server rather than keep it (a detached one ran 4 h 42 m unnoticed on delphi,
2026-11-02):

```bash
tmux new-session -d -s agent-wrangler -c modules/services/nix-cache-edge -- \
  bash -lc 'exec wrangler dev --local --port 8787'
tmux attach -t agent-wrangler
tmux kill-session -t agent-wrangler        # teardown — do it when the editing stops
```

Idle `wrangler dev` burns a real core: **~42 %** on delphi, 206-213 ticks per 5 s,
1 h 52 m of CPU accrued over 4 h 42 m wall. The cost is esbuild, not this Worker —
its watch mode polls the filesystem instead of using inotify
([workers-sdk#11469](https://github.com/cloudflare/workers-sdk/issues/11469), still
open 2026-07). A freshly started process spins identically, so restarting does not
help; `--no-bundle` cannot skip it (workerd rejects the TypeScript entry:
`Uncaught SyntaxError: Unexpected strict mode reserved word at worker.ts:13`); and
esbuild holds a dirfd on `/nix/store`, which is why this host sits at the top of
the 28-41 % range other reporters see. Start it to edit, stop it after.

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

- **`gc` is not scheduled.** Nothing runs it; the trigger is a `push` refusal or
  a look at `dev:nixcache:size`. A weekly job on delphi would close that loop, and
  it is not wired yet.
- **Emptying by hand is a footgun.** `rclone delete r2:nix-cache` removes objects;
  **not** `rclone purge`, which deletes the bucket itself and leaves `nix copy`
  failing silently (measured 2026-11-02; `dev:nixcache:deploy` recreates it).
- **A bigger budget is a cost knob, not a code change.** 10 GiB is the R2 free
  tier; past it R2 bills $0.015/GiB-month, so a 50 GiB bucket is about $0.60 a
  month and would hold ~65 systems at the measured 771 MiB each. Raise
  `BUDGET_GIB` when the refusal starts costing more in rebuild time than the
  storage does.
- **CI secrets are not set.** The workflow's buffer step is inert until
  `NIXCACHE_SIGNING_KEY` and the three `NIXCACHE_R2_*` values exist as repository
  secrets; `dev:nixcache:keygen` prints the `gh secret set` line for the key.
- **No custom domain yet.** `workers_dev = true` in `wrangler.toml`; a `[[routes]]`
  block with `custom_domain` replaces it when the cache has a name.
- **CI does not read it yet.** The workflow pushes and still substitutes from
  cachix/nixpkgs; pointing it at the edge is a second step, after the registry has
  the entry and the probe is green from a runner.
