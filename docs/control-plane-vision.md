# Control Plane — Vision (Nix-as-generator)

> **Status:** vision / north-star document. Aspirational, not a committed design.
> Companion to [`control-plane-architecture.md`](./control-plane-architecture.md),
> which is the nearer-term, buildable design. This document records *why* the
> end state is shaped the way it is, and where the interesting new ground is.

---

## 1. Thesis

**Build a site about Nix, in Nix.** The repository's content is already a graph
of Nix and data primitives — `flake.lock`, `inventory.toml`, `modules.toml`,
`flake/*`, `modules/*`. A site that renders *that* graph should be produced by
the same evaluator that already understands it, rather than re-derived by an
outside tool (Python today, Go tomorrow).

This is different from the usual "Nix can build a static site" pattern. The
claim here is stronger: **Nix is the generator**, and the site is a projection
of the flake graph into HTML/SVG.

## 2. Federation — the manifest can live elsewhere

The nav/content manifest (`docs/site.toml` in the architecture doc) does **not**
have to live in this repo. It can be:

- a **flake input** (`github:shaoyanji/nixconfig-docs`), locked in `flake.lock`;
- a data file fetched by Nix from GitHub, hashed and pinned like any other input.

That is the elegant part: **Nix's input model already *is* the federation
mechanism.** Site sections, docs from sibling repos, or a separate "docs" repo
can be composed as pinned inputs, and the lock makes the composition
reproducible. The site then reflects a *federation of primitives*, not one repo.

Consequence: the same machinery can render docs for other flakes (a project's
own `docs/` + a shared manifest input), which is exactly what "build a site
about Nix, in Nix" should generalise to.

## 3. The wall: evaluation speed

Why are there Nix *static* site generators but no Nix *dynamic* ones?

- **Static** is fine: evaluate once, emit files, done. The cost is paid at build.
- **Dynamic** is not: serving a request by evaluating Nix means paying the
  evaluator's cost *per request*. The Nix binary is not fast at evaluation, so
  per-request eval is out of the question at interactive latency.

This is the honest constraint that pushes the runtime off Nix (→ Go + Datastar)
while keeping generation *on* Nix. It also explains a pain already felt in this
repo: whole-config `nix eval` is slow enough that `checks:quick` stopped being
quick, and flake evaluation re-scopes the source tree on every dirty change.

For our scale it "might not be a big deal" — one evaluation per build, cached in
the store — but it caps how dynamic the *Nix* half can be.

## 4. The enabling path: faster evaluation (lazy trees)

The evaluator bottleneck is being attacked, and the relevant lever for this repo
is **lazy trees**:

- Determinate Nix shipped lazy trees (3.5.2 → 3.6.7; rolled out broadly by
  3.8.0, which is based on Nix 2.30). Lazy trees make evaluation **faster and
  less resource-intensive** for flake usage by **scoping the source tree** —
  Nix stops copying the whole tree into the store and only pulls what is needed.
- Lix, by contrast, does **not** include lazy trees and does not plan to use the
  upstream implementation.

That is precisely the axis this repository is exposed on: a large tree with ~25
hosts and hundreds of modules, where a dirty tree reshuffles the source hash and
where full-config evaluation is the slow path. If source-scoping and eval cost
drop, more of the site can move *into* Nix evaluation, including:

- **HTML generation from data** (inventory/modules → pages) as a pure eval,
- **closure-tree traversal** — a Nix function walking the derivation graph to
  produce the closure view, instead of shelling out to `nix path-info`.

### Caveats (to validate, not assumed)

- Lazy-trees benefit is **flake source scoping**; it is not a blanket "eval is
  now fast". Measure against *our* tree before betting on it.
- Adopting Determinate Nix is a **fleet-wide change** to the Nix binary
  (upgrade path, channel/compat, NixOS module interplay) — a milestone, not a
  drop-in.
- Upstream and Lix may converge on equivalent mechanisms later; the vision
  should depend on the *capability* (cheap eval over a big tree), not a vendor.

## 5. Where the two layers meet

The architecture doc's split is not a compromise — it is the correct seam given
§3–§4:

| Layer | Tool | Runs | Why |
| :--- | :--- | :--- | :--- |
| Generation | **Nix** | once, cached in the store | reproducibility, cero re-derivation, native understanding of flakes/data |
| Closure computation | **Nix** (goal) / store-DB now | build or request | it is a traversal of the derivation graph |
| Serving & interaction | **Go + Datastar** | per request | must be fast; SSE for live control |

So: **Nix compiles the world's facts; Go serves them and lets you act on them.**
The "dynamic site" is Go; the "site about Nix" is Nix.

## 6. Closure traversal as a Nix primitive

Today closure analysis is a shell tool reading the store DB (`closure-analysis.sh`)
because it is cheap and needs no eval. The vision closes that loop: a Nix
function over the system derivation that walks the tree and emits the graph —
same data, expressed natively, cacheable, and diffable between generations. With
faster eval, that becomes a *build-time* artefact for the wiki and a
*request-time* artefact for the dashboard — the two closure graphs in §5 of the
architecture doc, both Nix-native.

### Prototype result (2026-10-10)

Done, and it does **not** need faster eval to be correct — only to be cheap.

`lib/closure-graph.nix` + `scripts/task/closure-graph.sh` traverse the graph with
`pkgs.closureInfo` (i.e. Nix's own `exportReferencesGraph`) instead of
`nix path-info`. `scripts/task/closure-graph-diff.sh` is the comparison gate; on
frieren all five views (`size`, `subsystems`, `top`, `dot`, `toml`) are
**byte-identical**, and the path set and Σ narSize match exactly, across a
3949-path system closure, an older generation, and a 141-path package closure.

Findings worth keeping:

- **The primitives are exactly equivalent.** `closureInfo`'s `store-paths` and
  `nix path-info --recursive` return the identical path set, and
  `total-nar-size` equals the shell tool's summed narSize to the byte. The store
  DB and the derivation graph agree; the choice is about *shape*, not accuracy.
- **The output is a store path.** The traversal is cached and content-addressed,
  so it is diffable between generations and reusable as a build input — the
  wiki/dashboard property §5 wants. The shell tool recomputes.
- **Cost is eval-shaped, as §3 predicted.** A cold call is dominated by the
  nixpkgs import (the earlier build took ~15 s); a warm call — derivation already
  in the store — was ~1 s for all five views, against ~9–16 s for the shell tool
  reading the store DB per view. So the wall in §3 is real but *not* the binding
  constraint for a build-time artefact; it stays the constraint for per-request use.
- **It is local-only.** `closureInfo` builds locally, so the native path cannot
  analyse a remote host the way `--host <name>` can. Reaching the fleet means
  building each host's closure here, or copying the `closure-info` derivation out.
- **Fidelity is in the details.** Byte-parity required reproducing `numfmt`'s
  `--round=up` sizing (not round-to-nearest) and GNU `sort`'s two different
  tie-break orders. Numbers matching is the easy half.

The remaining gap to a true *primitive* is the one §4 describes: passing
`config.system.build.toplevel` straight in, so no store path is named by hand and
no nixpkgs import is paid outside the flake's own evaluation.


## 7. Milestones (each independently useful)

1. **Nix renders static pages from data** — one derivation, `inventory.toml` +
   markdown → HTML. (Go builder is the pragmatic first cut; Nix-native is the goal.)
2. **External manifest input** — move `site.toml` to its own repo, consume as a
   locked flake input; prove federation with a second consumer.
3. **Eval budget** — measure full-tree eval; trial lazy trees (Determinate Nix)
   and record the delta before committing to the upgrade.
4. **Nix-native closure graph** — replace the shell traversal with a Nix
   function; compare output to `closure-analysis.sh`.
5. **Dynamic dashboard** — the Go + Datastar control plane over the compiled,
   Nix-generated content.

## 8. Non-goals / guardrails

- No per-request evaluation of the flake — that is the wall this vision respects.
- No vendored web build chain (no Node/npm); Datastar is one fetched file.
- No hand-maintained second source of truth — everything is a primitive.
- Don't couple the vision to one Nix distribution; target the *capability*.
