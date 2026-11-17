# Control plane — vision (Nix as generator)

Status: vision, not a committed design. The buildable version is
[`control-plane-architecture.md`](./control-plane-architecture.md). This page
records why the end state has this shape and which parts are still open ground.

## 1. Thesis

Build a site about Nix, in Nix. The repository already holds a graph of Nix
values and data: `flake.lock`, `inventory.toml`, `modules.toml`, `flake/*`,
`modules/*`. The evaluator that understands that graph should also render it,
rather than a second tool re-deriving it (Python today, Go tomorrow).

Most "Nix can build a static site" projects stop at templating. Here Nix is the
generator and the site is a projection of the flake graph into HTML and SVG.

## 2. Federation — the manifest can live elsewhere

The nav/content manifest (`docs/site.toml` in the architecture doc) does not have
to live in this repository. It can be:

- a flake input (`github:shaoyanji/nixconfig-docs`), locked in `flake.lock`;
- a data file fetched by Nix from GitHub, hashed and pinned like any other input.

Nix's input model already is the federation mechanism. Site sections, docs from
sibling repositories, or a separate docs repository compose as pinned inputs, and
the lock makes the composition reproducible. The site then reflects a federation
of primitives, not one repository.

The same machinery can render docs for other flakes (a project's own `docs/`
plus a shared manifest input), which is what "build a site about Nix, in Nix"
generalises to.

## 3. The wall: evaluation speed

Nix static site generators exist; Nix dynamic ones do not. Static evaluates once
and writes files, so the cost is paid at build. Dynamic serves a request by
evaluating Nix, paying evaluator cost per request, which no interactive latency
budget survives.

That constraint pushes the runtime off Nix (Go + Datastar) while keeping
generation on Nix. The same wall is already visible in this repository: whole
config `nix eval` is slow enough that `checks:quick` stopped being quick, and
flake evaluation re-scopes the source tree on every dirty change.

At this scale one evaluation per build, cached in the store, would be affordable.
It still caps how dynamic the Nix half can be.

### A gate's cost is its chain (measured 2026-11-08)

`nix flake check` is slow because each configuration pays its own chain, not
because the fleet is large. A stub host with assertions forced, each chain
addition evaluated on top of the last:

| Chain | Peak RSS |
| :--- | ---: |
| base | 466 MiB |
| + `nixos` | 654 MiB |
| + `roles.minimal` | 766 MiB |
| + the full user role | 1 246 MiB |

Per feature, against the baseline: DMS +10 MiB, nixvim +75, nix-index +0,
shell/dev/ai +25 together, browser +36, media +32, desktop suite +22. The role was
never the cost. `systemd-policy` alone is +356 MiB, because its assertion reads
every user unit and `osConfig.systemd.services`, a full-config force inside every
host gate; every feature except that one evaluates at 897 MiB.

So the role became a feature list (`fleet.hmUserFeatures`): an import that is not
taken is not evaluated, and the default set is unchanged, proved by
`task checks:drv-equality` on a desktop, a container and darwin. Open: the
desktop gate goes under 1 GiB when the classification gate moves out of the host
eval, beside `task checks:units`, one force and two verdicts. That is a safety
decision, not a refactor.

## 4. The enabling path: faster evaluation (lazy trees)

Lazy trees are the relevant lever for this repository:

- Determinate Nix shipped lazy trees (3.5.2 → 3.6.7; broadly rolled out by 3.8.0,
  which is based on Nix 2.30). They speed evaluation and cut its memory use for
  flake usage by scoping the source tree: Nix stops copying the whole tree into
  the store and pulls only what it needs.
- Lix does not include lazy trees and does not plan to use the upstream
  implementation.

This repository sits on that axis: a large tree with ~25 hosts and hundreds of
modules, where a dirty tree reshuffles the source hash and full-config evaluation
is the slow path. Cheaper source scoping and eval would let more of the site move
into Nix evaluation:

- HTML generation from data (inventory/modules → pages) as a pure eval;
- closure-tree traversal, a Nix function walking the derivation graph instead of
  shelling out to `nix path-info`.

### Caveats

- Lazy trees scope flake sources; they are not a blanket "eval is now fast".
  Measure against this tree before betting on them.
- Adopting Determinate Nix changes the Nix binary for the whole fleet (upgrade
  path, channel compatibility, how modules interact). It is a milestone, not a
  drop-in.
- Upstream and Lix may converge on equivalent mechanisms later, so the vision
  should depend on the capability (cheap eval over a big tree), not a vendor.

## 5. Where the two layers meet

The architecture doc's split is the right seam given §3–§4:

| Layer | Tool | Runs | Why |
| :--- | :--- | :--- | :--- |
| Generation | Nix | once, cached in the store | reproducible, no re-derivation, native understanding of flakes and data |
| Closure computation | Nix (goal) / store DB now | build or request | it is a traversal of the derivation graph |
| Serving and interaction | Go + Datastar | per request | must be fast; SSE for live control |

Nix compiles the facts; Go serves them and applies actions. The dynamic site is
Go, the site about Nix is Nix.

## 6. Closure traversal as a Nix function

Closure analysis is a shell tool reading the store DB (`closure-analysis.sh`)
because that is cheap and needs no eval. The vision closes the loop with a Nix
function over the system derivation that walks the tree and emits the graph: same
data, expressed natively, cacheable, diffable between generations. With cheaper
eval it becomes a build-time artefact for the wiki and a request-time artefact for
the dashboard — the two closure graphs in §5 of the architecture doc, both
Nix-native.

### Prototype result (2026-10-10)

`lib/closure-graph.nix` and `scripts/task/closure-graph.sh` traverse the graph
with `pkgs.closureInfo` (Nix's own `exportReferencesGraph`) instead of
`nix path-info`. `scripts/task/closure-graph-diff.sh` is the comparison gate. On
frieren all five views (`size`, `subsystems`, `top`, `dot`, `toml`) are
byte-identical, and the path set and Σ narSize match exactly, across a 3949-path
system closure, an older generation and a 141-path package closure.

Findings:

- The primitives are equivalent. `closureInfo`'s `store-paths` and
  `nix path-info --recursive` return the same path set, and `total-nar-size`
  equals the shell tool's summed narSize to the byte. The store DB and the
  derivation graph agree; the choice is about shape, not accuracy.
- The output is a store path, so the traversal is cached, content-addressed,
  diffable between generations and reusable as a build input. The shell tool
  recomputes.
- Cost is eval-shaped, as §3 predicted. A cold call is dominated by the nixpkgs
  import (the earlier build took ~15 s); a warm call was ~1 s for all five views,
  against ~9–16 s for the shell tool reading the store DB per view. The wall in §3
  is real but not binding for a build-time artefact; it stays binding for
  per-request use.
- It is local-only. `closureInfo` builds locally, so the native path cannot
  analyse a remote host the way `--host <name>` can. Reaching the fleet means
  building each host's closure here or copying the `closure-info` derivation out.
- Fidelity is in the details. Byte parity required reproducing `numfmt`'s
  `--round=up` sizing rather than round-to-nearest, and GNU `sort`'s two distinct
  tie-break orders.

The remaining gap is the one §4 describes: passing `config.system.build.toplevel`
straight in, so no store path is named by hand and no nixpkgs import is paid
outside the flake's own evaluation.

## 7. A static SPA from aki (~270 B)

Rebuilding a host, restarting a unit and streaming SSE telemetry need a runtime
server (Go + Datastar in §5). Browsing, closure exploration, subsystem filtering
and doc traversal are read-only and do not.

[`vilgacx/aki`](https://github.com/vilgacx/aki) is 270 bytes minified and needs
no runtime server or client framework:

```javascript
window.onload = () => {
  document.querySelectorAll('[url][fn]').forEach((element) => {
    const attr = element.attributes;
    element[attr.fn.value] = () => {
      fetch(attr.url.value)
        .then((response) => response.json())
        .then((data) => {
          Object.entries(data).forEach((ele) => {
            Object.entries(ele[1]).forEach((chan) => {
              document.querySelector(ele[0])[chan[0]] = chan[1];
            });
          });
        });
    };
  });
};
```

Nix generates the payloads, and aki applies a declarative JSON payload to CSS
selectors:

```json
{
  "#content-pane": {
    "innerHTML": "<h2>speech-dispatcher (644.7 MiB)</h2><p>Referrers: zen-beta, electron</p>"
  },
  "#badge-tier": {
    "className": "badge badge-prunable",
    "textContent": "Tier 1: Prunable"
  }
}
```

A pure derivation emits `index.html`, `aki.min.js` and the static `data/` slices:

```nix
# Pure derivation emits index.html, aki.min.js, and static data/ slice files
pkgs.writeTextDir "site/data/closure/speech-dispatcher.json" (builtins.toJSON {
  "#detail-view" = {
    innerHTML = renderPackageDetail pkg;
  };
  "#active-breadcrumb" = {
    textContent = pkg.pname;
  };
})
```

Every node in the closure tree and every host in the inventory renders as a
button carrying the payload URL:

```html
<button url="data/closure/${node.hash}.json" fn="onclick">${node.name}</button>
```

A click fetches the pre-compiled JSON slice and updates the DOM in place, so one
static `index.html` traverses a 3,900-node NixOS closure and switches host
inventories and subsystem views with no daemon, no Node/Vite build and no client
hydration. It serves from Nginx on frieren (`docs.frieren.lan`), GitHub Pages, or
a local file.

## 8. Moving services into resource-capped MicroVMs (Model B)

Background daemons on frieren (watchdogs, audits, scrapers, vector indexers)
compete for 11.5 GB of RAM and the same disk. Preventing host starvation used to
mean System 0/1/2 polling daemons and memory governors. Model B moves services off
bare metal into dedicated, resource-capped MicroVMs (`cloud-hypervisor` via
`microvm.nix` and `virtiofs`).

Resource capping happens in the kernel: every service or cluster runs inside an
isolated microVM with strict vCPU and memory ceilings (for example 2 vCPUs,
2048 MB RAM). The hypervisor cap stops CPU contention and memory pressure at that
boundary, so a runaway workload cannot starve NAS storage (`btrfs`), video
streaming (`jellyfin`) or host networking, and daemons no longer need polling
loops to watch memory pressure.

Guests share the host's `/nix/store` read-only over `virtiofs` (`ro-store`) with a
minimal copy-on-write overlay (`/nix/.rw-store`). The overlay costs under 10 MB
per instance, where a full-system VM or a duplicated Docker image would copy the
disk. Boot takes under 4 seconds, and teardown does not block on unmount
(`DefaultDependencies = false`).

Services inside the microVM bind internal virtual interfaces on the host bridge
(`brlan` on `192.168.83.1/24`). The host's Nginx is the only ingress, mapping
virtual hosts and paths (`service.frieren.lan` or `/service/`) to guest IPs.
Remote clients reach those services over Tailscale (`100.97.61.65` or MagicDNS)
without subnet route advertising. If a microVM stops or rebuilds, Nginx returns
`504 Gateway Time-out`; when it boots again, connections restore with no reload
and no route flap.

Phases:

- Phase 1 (canary sandbox, complete): EXP-102 proved it with `frieren-canary` —
  automated boot, persistent SSH key recognition and dummy-service Tailscale
  verification.
- Phase 2 (auxiliary, stateless services): Kiwix, Gatus, the Paperless worker
  queues and isolated HTTP bridges.
- Phase 3 (fleet workloads): heavy, memory-bursting workloads such as Immich ML
  inference and local AI helpers, with primary datasets left on the host Btrfs
  pools.

## 9. Milestones (each independently useful)

1. Nix renders static pages from data: one derivation, `inventory.toml` +
   markdown → HTML. The Go builder is the pragmatic first cut; Nix-native is the
   goal.
2. Aki-powered static closure explorer: build-time Nix compilation of
   `pkgs.closureInfo` into a single-page tree browser over static JSON.
3. MicroVM service sandbox (Model B dogfood): verified in EXP-102 — zero-copy
   virtiofs store, persistent SSH host key recognition, Nginx reverse-proxy
   ingress over Tailscale.
4. External manifest input: move `site.toml` to its own repository, consume it as
   a locked flake input, and prove federation with a second consumer.
5. Eval budget: done for the chain ("A gate's cost is its chain" above). The
   per-configuration floor is measured and the user role is a feature list. The
   remaining half is lazy trees (Determinate Nix): trial them and record the delta
   before committing to the upgrade.
6. Nix-native closure graph: replace the shell traversal with a Nix function and
   compare output to `closure-analysis.sh`.
7. Dynamic dashboard: the Go + Datastar control plane over the compiled,
   Nix-generated content, for live execution and toggles.

## 10. Non-goals / guardrails

- No per-request evaluation of the flake; that is the wall this vision respects.
- No vendored web build chain (no Node/npm). `aki.js` is 270 bytes and Datastar is
  one fetched file.
- No hand-maintained second source of truth; every page comes from the compiled
  data.
- Do not couple the vision to one Nix distribution; target the capability.
