# Control Plane — Site & Dashboard Architecture (redesign)

> **Status:** design proposal (not yet implemented). Supersedes the
> `docs-site/` Python generator.
> **Companion vision:** [`control-plane-vision.md`](./control-plane-vision.md)
> (why the end state is shaped this way — Nix-as-generator, federated
> manifests, and the evaluation-speed wall).
> **End state:** a web dashboard that gives the same control surface as the
> Taskfile *and* serves wiki-like content about the flake and fleet — rendered
> live from the same primitives, including closure graphs.

---

## 1. What this replaces, and why

Today's `docs-site/` is `python3 + python3Packages.markdown` + a hand-written
`nav.json` + `generate.py`. It works, but it is the wrong shape for where this
is going:

- It is a **separate pipeline** from the data it renders (nav is hand-maintained,
  content is copied per-file).
- It cannot serve **dynamic** content — no task controls, no live closure graphs.
- Python is the wrong rendering dependency for something meant to grow into a
  runtime control plane.

The redesign keeps docs as a **first-class artefact** but makes the whole thing
one system: **primitives (Nix + data) → compiled bundle (+ one small Go binary)
→ served as static wiki *and* live control plane.**

## 2. Constraints & principles

| Constraint | Consequence |
| :--- | :--- |
| Content must compile from **Nix and data primitives** | Nix runs the build; every input is a flake input, a `.toml`, or markdown. Nothing is hand-maintained twice. |
| **Not Python** for rendering | Markdown → HTML is done by the Go builder (pure-Go `goldmark`), not a Python package. |
| **Never Node** | Datastar needs **no npm**: its JS bundle is a single file vendored by Nix (`fetchurl`, pinned hash) and served same-origin. No build step in JS. |
| Go is fast but **clunky in a Nix config** | One `buildGoModule` derivation, `vendorHash` pinned; the Datastar Go SDK is a normal `go.mod` dependency, not a separate flake input. |
| Must become a **dynamic control plane** | The same binary that *builds* the static site also *serves* it, plus SSE endpoints that run Taskfile commands. |
| Offline / tailnet fleet | No CDN at runtime; everything vendored. Exposure is `tailscale serve`, not a public port. |

## 3. The primitives (the only sources of truth)

Everything the site shows is derived from these. No secondary copies.

| Primitive | Kind | Feeds |
| :--- | :--- | :--- |
| `inventory.toml` | data | fleet pages, host cards, persona, CI status |
| `modules.toml` | data | control-knob pages / toggles |
| `Taskfile.yml` + `task --list-all --json` | data | the control surface (task list, descriptions, namespaces) |
| `flake.lock` | data | input/version pages |
| closure TOML (`task dev:closure:toml`) | data | closure graphs & size tables |
| `docs/**/*.md`, `README.md`, `AGENTS.md`, `.agents/**/*.md` | markdown | wiki content |
| `docs/site.toml` *(new)* | data | nav/sections/config — replaces hand-written `nav.json` |

Nix is the compiler: a single function `mkSite` in `lib/` takes these and returns
a store path. `docs/site.toml` declares the nav so the manifest is data, not code.

## 4. The pipeline (compile-time)

```
flake.nix
  └─ lib/mk-site.nix        (mkSite { docs, data, extra })            ── Nix
        └─ nixconfig-control build --root $src --out $out           ── Go builder
              • goldmark:      *.md → HTML fragments
              • template:      Go html/template  → full pages
              • TOML → struct: inventory / modules / site manifest
              • graphviz:      DOT → SVG (closure graphs, static)
              • emit:          $out/{index.html, .../, app.css, datastar.js, data/*.json}
```

- **One Go program, two modes.** `nixconfig-control build` (pure function of its
  inputs, so the Nix output is reproducible and cacheable) and
  `nixconfig-control serve` (the runtime). Same code, same embedded assets via
  `go:embed` where static.
- **Nix orchestrates, Go renders.** Nix pins the markdown set and the data; Go
  does the text work fast. No Python phase, no Node phase.
- **Static by default.** Every page that is just content is a pre-rendered HTML
  file in the store — instant, cacheable, works with JS disabled.

## 5. The runtime (dynamic layer)

`nixconfig-control serve` runs as a systemd service, binds `127.0.0.1:<port>`,
and exposes:

| Route | Method | Purpose |
| :--- | :--- | :--- |
| `/` and `/<slug>/` | GET | the compiled static wiki (from the store path) |
| `/events` | GET (SSE) | Datastar stream: patches for live regions |
| `/control/tasks` | GET | the task surface from `task --list-all --json` |
| `/control/run/{task}` | POST (SSE) | run a task, stream stdout/stderr as patch events |
| `/control/closure/{host}` | GET (SVG) | live closure graph for a host |
| `/data/{name}.json` | GET | normalized primitives as JSON |

The UI is a thin HTML shell using Datastar attributes — the server drives it:

```html
<!-- one control-plane button; the handler streams output back over SSE -->
<button data-on:click="@post('/control/run/dev:closure:graph?host=frieren')">
  Closure graph · frieren
</button>
<pre id="output"></pre>
```

```go
// /control/run/{task}: every byte the task emits becomes a PatchElements event
sse := datastar.NewSSE(w, r)
cmd := exec.CommandContext(ctx, "task", task, "--", args...)
stdout, _ := cmd.StdoutPipe(); cmd.Stderr = cmd.Stdout
cmd.Start()
sc := bufio.NewScanner(stdout)
for sc.Scan() {
    sse.PatchElements(fmt.Sprintf(`<pre id="output">%s</pre>`, html.EscapeString(sc.Text())))
}
```

This is the property that matters: **the Taskfile *is* the API.** The dashboard
never re-implements task logic — it lists tasks and runs them, so the CLI, the
TUI (`task menu`), and the web UI all stay one control plane.

### Closure graphs

- **Static pages:** `dot -Tsvg` at build time for a committed/host snapshot.
- **Live dashboard:** `/control/closure/{host}` runs `closure-analysis.sh` →
  DOT → `dot -Tsvg` → inline SVG (or the DOT for client-side pan/zoom). Because
  the analysis is store-DB only (no `nix eval`), the request is cheap and safe.

## 6. Repo layout

```
control-plane/                 ← new; the Go program
  go.mod                       (goldmark, BurntSushi/toml, starfederation/datastar-go)
  main.go                      (build | serve)
  internal/{render,data,control,graph}
lib/mk-site.nix                ← mkSite { docs, data }  (Nix compiler)
docs/site.toml                 ← nav + sections manifest (data, replaces nav.json)
docs-site/                     ← deleted once parity is reached
modules/services/control-plane.nix  ← NixOS module: service + tailscale serve
```

## 7. Deployment (fleet-consistent)

`modules/services/control-plane.nix` follows the existing service pattern
(compare `modules/services/qwen-tts.nix`): dedicated system user, hardened
systemd unit (`ProtectSystem=strict`, `ReadWritePaths` for state), the binary
from the Nix store, `graphviz`/`task` on PATH, and exposure via
`tailscale serve --bg --https=<port> http://127.0.0.1:<port>` →
`https://control.<tailnet>.ts.net` (or a per-host name). The port is **loopback
only**, never in `allowedTCPPorts`.

## 8. Auth & safety

Running tasks from the web is powerful, so it is treated as such:

- Trust boundary is the **tailnet** (no public Funnel), same as the LLM/TTS
  endpoints. Optional bearer token (`apiKeyFile`) mirroring the TTS module.
- A **task allowlist** in `docs/site.toml` (data) decides what is runnable from
  the UI; destructive tasks require an explicit confirmation patch.
- No arbitrary command execution endpoint — only `task <allowlisted-name> [args]`.

## 9. Migration path (incremental, verifiable at each step)

1. **Parity:** build the Go builder to regenerate exactly today's page set from
   `docs/site.toml`; diff against the Python output; only then delete
   `docs-site/`.
2. **Data pages:** add the inventory/modules/closure pages generated from data.
3. **Control surface:** add `/control/tasks` + `/control/run` behind the allowlist.
4. **Dashboard:** promote the control surface to the index; embed live closure
   graphs.
5. **Retire** `generate.py`, `nav.json`, and the Python derivation.

At every step the static site keeps working (it is just files in the store), so
this is safe to land piecewise.

## 10. Open decisions

- **Nav source:** `docs/site.toml` manifest vs. YAML front-matter per doc.
  (Recommendation: manifest — one place, machine-readable, matches `modules.toml`.)
- **Live vs baked closure graphs:** bake for the wiki, stream for the dashboard
  (recommended), or make both live.
- **Hosting scope:** one control-plane instance on `frieren` for the whole fleet,
  or per-host. (Recommendation: one on `frieren`, reached over the tailnet.)
- **Task allowlist:** start read-only (checks/analyses) and widen deliberately.
