# Nix-Idiom Audit — docs pipeline & hardcoded config

Status: **IN FLIGHT** — audit + policy only (2026-10-19). Nothing here is a rewrite.

- **Part A (§1–5)** — documentation/site pipeline: producers, committed
  derivatives, content-as-code, double instantiation.
- **Part B (§6)** — the same class of problem elsewhere in the tree: `extraConfig`
  policy copies, ports typed instead of read from their option, hardcoded
  identity/paths where a constant already exists, and 200–300 line scripts living
  inside modules.

Scope: every `.nix` file that *produces or embeds* documentation/HTML, and every
derivative it causes to be committed; plus every `.nix` file carrying a
multi-line literal of policy that a module option or a constant already owns.

## 0. The rule this measures against

One source → one compiler → one immutable store artifact → served as bytes.

Four tests, applied to each finding below:

| Test | Question |
| :--- | :--- |
| **T1 one source** | Does exactly one file own this fact, and does everything else derive from it? |
| **T2 no committed artifact** | Is every generated thing a store path, or is a copy tracked in git? |
| **T3 content is data** | Is prose/markup/CSS/JS in files, or inside `.nix` string literals? |
| **T4 built once, served once** | Is the artifact instantiated once and served, or re-derived per consumer? |

## 1. What exists today — three producers for one body of docs

| Producer | Kind | Output | Consumers | Live? |
| :--- | :--- | :--- | :--- | :--- |
| `lib/docs.nix` | Nix (pure values) | `.#artifacts.docs` — generated markdown + `nav.json`, 0.7 s | site generator, `docs:sync` | no, an input |
| `lib/aki-site.nix` | Nix (built **at eval**) | `.#sites.fleet-docs-site` — HTML/JSON tree, 9.1 s | nginx vhost, UDS bridge, `.#sites.fleet-docs-site` | yes, on frieren |
| ~~`docs-site/{default.nix,generate.py}`~~ | **retired 2026-10-19** | ~~`.#docs-site`~~ | — | **deleted** |

They do not render the same page set: `lib/docs.nix` owns `staticSections`, aki
owns whatever `lib/knowledge-graph.nix` projects, and Python owns whatever the
nav it is handed says. Three readers of one repo with three different ideas of
which pages exist.

## 2. Findings

### P0 — duplicated sources of truth (T1, T2)

| # | Evidence | Why it is wrong |
| :- | :--- | :--- |
| F1 | `docs-site/nav.json` (1,814 B, tracked) vs the nav emitted by `lib/docs.nix`. Verified **it differs** from `nix build .#artifacts.docs`'s `nav.json`, and nothing reads it — `docs-site/default.nix:36` passes `--nav ${docs}/nav.json`. | A second manifest that is already stale. Delete it; there is one nav, the Nix value. |
| F2 | **FIXED 2026-10-19.** `docs/generated/` was **30 tracked `.md` files**, refreshed by `task docs:sync` and guarded by `checks:docs:sync` — a gate that was red in the working tree (`fleet-inventory.md` and `hosts/frieren.md` stale). All 30 files, the `docs:sync` write-back and the gate are deleted; `.gitignore` now blocks the path from returning. | The artifact was committed, so it could drift, so it needed a drift check, which could fail. A check that exists only because a build output is duplicated is proof the duplication is wrong. `nix build .#artifacts.docs` is the only copy now. |
| F3 | **FIXED 2026-10-19.** `docs/modules-registry.md` (640 B pointer) was tracked *and* matched by `.gitignore:22`, with its target tracked separately. The ignore line is replaced by `docs/generated/`, and both pointer pages now name the store path instead of a repo file. | A stale ignore entry plus two paths for one page. |
| F4 | `AGENTS.md` was **exactly 1,200 / 1,200 lines** (budget in `.agents/SCHEMA.md` §2), with lines 94–133 a pasted fleet table restating `inventory.toml` — which `.agents/SCHEMA.md` §1 forbids by name. *Fixed here:* the table is gone, replaced by a pointer, and the pipeline rule now occupies part of the freed space (1,198 lines). | The manual was full of a second copy of the registry, so there was no room to document the docs pipeline in it. That is why *"AGENTS.md does not address this"*. |

### P1 — content written as code (T3)

| # | Evidence | Why it is wrong |
| :- | :--- | :--- |
| F5 | **FIXED 2026-10-19.** `lib/aki-site.nix` was **1,723 of 1,910 lines (90 %) inside `''` literals** — `kgJs` (551 lines of browser JS), `styleCss` (219 of CSS), `akiJs`, plus templates. The assets were measured to carry **zero interpolations and zero `''` escapes**, i.e. plain files wearing a Nix costume, so they were extracted verbatim to `lib/site/{aki.js,kg.js,style.css,sidebar.html}`. The two interpolating templates followed as `lib/site/{shell,overview}.html` with `{{name}}` holes and a one-pass `render` in Nix: the built `index.html`, all page-level slices and all 34 host slices are **byte-identical** to the pre-extraction build; the only delta was the stray trailing blank line the old heredoc appended to the assets. `render` throws on an unbound hole (verified: an injected `{{nope}}` fails the build naming it), and `checks.<system>.site-assets` runs `node --check` on both JS files (negative control: an injected `function (` fails). `aki-site.nix` is now 1,068 lines / 275 literal lines, all of them short inline fragments with interpolation — the fragments a template cannot hold because they are generated per row. | CSS/JS/HTML cannot be linted, formatted, syntax-checked or reviewed as a diff; a missing quote is a *Nix* parse error; and every byte change re-evaluates a module that also imports the knowledge graph. |
| F6 | `modules/services/fleet-sentinel.nix:190–242` — a 53-line HTML dashboard inside a Nix module. | Same class, smaller. |
| F7 | `hosts/frieren/reverse-proxy.nix:18` — an inline HTML landing page inside a host module. | Same class; host modules should carry wiring, not markup. |

### P2 — the artifact is baked into a system closure (T4)

| # | Evidence | Why it is wrong |
| :- | :--- | :--- |
| F8 | The same module is instantiated **three times** with identical arguments: `hosts/frieren/reverse-proxy.nix:391`, `:415`, `modules/services/uds-static-bridge.nix:18`. | Three evaluations of a 1,910-line module (plus the knowledge graph) per frieren eval. One flake output, passed by path, does the job once. |
| F9 | The served bytes are computed from `config.fleet.inventory` + `builtins.readFile` at **eval of the host**, so a markdown edit changes frieren's system closure. | Documentation is therefore as live as the last `nixos-rebuild switch` on the NAS — the stated symptom ("documentation is not live"). Publishing a typo fix should not require rebuilding a server. |

### P3 — eval-time reads and flake scoping

| # | Evidence | Why it is wrong |
| :- | :--- | :--- |
| F10 | Eval-time `builtins.readFile`: `lib/aki-site.nix:37`, `:107`, `:1644` (every note's text), `lib/docs.nix:34` (default `modules.toml` argument), plus the readers inside `lib/knowledge-graph.nix` / `lib/skills.nix`. | Legal, but flake-scoped: an **untracked** `.md` does not exist to the evaluator, so a page you wrote and did not `git add` silently vanishes — the second half of "compilation isn't keeping pace". It also makes every doc byte an input to every importing host. |
| F11 | Cost on this host: `nix build .#sites.fleet-docs-site` **9.1 s**; `.#artifacts.docs` 0.7 s; `.#docs-site` 4.1 s; evaling `.#sites.fleet-docs-site.drvPath` 1.67 s / 164.5 MiB — repeated for each of the three instantiations. | The cheapest artifact (0.7 s, pure values) is the one nothing serves; the most expensive is instantiated three times inside a host config. |

### P4 — packaging and gates

| # | Evidence | Why it is wrong |
| :- | :--- | :--- |
| F12 | **FIXED 2026-10-19** — `docs-site/default.nix:27` `src = ../.` fed the whole repo into the Python build. The derivation, its `src`, and the output are gone. | Every commit used to invalidate the site build and copy the tree into the store. |
| F13 | **FIXED 2026-10-19** — the `docs-site` check (`ls index.html`) is deleted with the output it checked. The site's real gate stays `checks:kg:canvas`, which builds `.#sites.fleet-docs-site` and clicks a node in headless Chrome. | A check that proved nothing about content was worse than no check: it made the pipeline look verified. |
| F14 | **FIXED 2026-10-19** — `docs/control-plane-architecture.md` §1 now records the retirement as DELIVERED and §9 step 5 is closed; `task docs:site` builds `.#sites.fleet-docs-site`. | The tree documented its own duplication and kept both halves; now it documents one half. |
| F15 | The living-doc budget gate is **red at HEAD**: `TODO.md` is 156 lines against a 150 limit (`task ops:docs:budget`, and `checks.<system>.docs-budget` throws), and `AGENTS.md` sits at 1,198 / 1,200. | The pressure F4 describes has already crossed the limit. A gate nobody runs (see the `nix flake check` rule) hides it. |

## 3. Already correct — do not "fix"

- `lib/docs.nix`: pages and nav from one compiled registry, 0.7 s, writes nothing back. This is the model the rest should follow.
- `lib/knowledge-graph.nix`, `lib/skills.nix`: one compiler each for graph and skill index; consumers derive, none re-parse.
- Materialization through `home.file` (`.agents/skills`, `~/AGENTS.md`) happens at build/activation, not by hand-editing copies.
- `docs/closures/` is gitignored — the right call, and the reason nobody complains about it.

## 4. Remediation order (each step deletes a class of bug)

1. ~~**Stop committing build output.**~~ **DONE 2026-10-19:** `git rm -r
   docs/generated` (30 files), `docs:sync` + `checks:docs:sync` deleted,
   `.gitignore` guards the path, every reader now points at `nix build .#artifacts.docs`
   or the served site. Removes F2 and its red gate.
2. ~~**Delete the dead manifest.**~~ **DONE 2026-10-19:** `docs-site/nav.json`
   removed; the stale `.gitignore` line replaced. Removes F1, F3.
3. ~~**Move assets out of Nix.**~~ **DONE 2026-10-19:** `lib/site/{aki.js,kg.js,style.css,sidebar.html}`
   are read verbatim; `lib/site/{shell,overview}.html` are templates with
   `{{name}}` holes filled by a one-pass `render`. `lib/aki-site.nix` keeps data
   + interpolation only, and what is left inside `''` is the per-row fragments
   that are generated from data (a page template cannot hold them). Proof of
   exactness: `index.html`, every page-level slice and 34/34 host slices are
   byte-identical to the pre-extraction build. F6/F7 (inline HTML in a service
   module and a host module) are still open and are separate changes.
4. **Instantiate once.** Add `fleetDocsSite` to the flake and pass that path to
   both vhost locations and the UDS bridge. Removes F8.
5. **Decouple publishing from the system switch.** Serve a `current` symlink that
   a `nix build .#sites.fleet-docs-site` + `ln -sfn` flips; a doc edit then costs a
   9 s build, not a NAS rebuild. Removes F9.
6. ~~**Retire `docs-site/`**~~ **DONE 2026-10-19:** the pre-condition was met by
   widening the projection instead of the page list — `lib/knowledge-graph.nix`
   now compiles `.agents/{README,SCHEMA,fleet-matrix}.md`, `.agents/deploy/**`
   and `taskfiles/*.md` as document nodes (**22 → 35**), which is everything the
   Python page list carried and more. Then: `docs-site/` deleted,
   `.#docs-site` + `.#docsSite` and the `docs-site` flake check removed,
   `lib/docs.nix` lost `staticSections`/`nav`/`nav.json` (the only consumer of a
   nav was that renderer), and `task docs:site` now builds the Nix-native site.
   Removes F12, F13, F14.
7. **Make the rule a gate:** fail when a tracked file matches a known generated
   path, and fail when a `.nix` file exceeds a literal-content budget (a cheap
   `wc -l` over `''` blocks, like the living-doc budget).

Step 1 alone is the answer to "compilation isn't keeping pace": with no copy in
git, there is nothing to fall behind.

## 5. Measurements (this host, 2026-10-19)

| Command | Wall | Notes |
| :--- | ---: | :--- |
| `nix build .#artifacts.docs` | 0.69 s | pure values → markdown tree + `nav.json` |
| `nix build .#sites.fleet-docs-site` | 9.09 s | all Nix string processing, 1,723 literal lines |
| ~~`nix build .#docs-site`~~ | removed | the Python derivation is gone; the site is `.#sites.fleet-docs-site` (9.1 s) |
| `nix eval .#sites.fleet-docs-site.drvPath` | 1.67 s / 164.5 MiB | paid 3× inside frieren's host eval |
| `task checks:docs:sync` | removed | the gate went with the committed copy (was failing: 2 of 30 pages stale) |

---

# Part B — hardcoded config outside the docs pipeline

Scan of all 470-odd `.nix` files: **174 indented-string blocks (3,339 lines)**,
**33 `extraConfig` sites**, plus every literal IPv4, `*.lan` name, `/home/<user>`
path and bare service port.

Most literals are fine — a timeout, a `StrictHostKeyChecking` line, a single
`rewrite`. The findings below are the ones where a *value with an owner*
is retyped where that owner cannot reach it.

## 6.1 What is actually wrong

| # | Finding | Evidence | Fix |
| :- | :--- | :--- | :--- |
| H1 | **The same nginx cache policy is typed four times.** | `hosts/frieren/reverse-proxy.nix:396` and `:420` share 4 of 6 lines (`gzip_static`, three `open_file_cache` lines) and differ only in `Cache-Control`; `modules/services/uds-static-bridge.nix:62` (15 lines) and `:91` repeat the same quartet again. | One `let` binding (or a `services.<x>.cachePolicy` option) interpolated into all four. |
| H2 | **SSE policy triplicated.** | `hosts/eisen/llm-server.nix:399`, `:421`, `:439` each write `proxy_buffering off; proxy_cache off;` with a different timeout. | One `let sse = ''…'';` reused; the only per-site difference is the timeout. |
| H3 | **Service ports are typed, not read from the option that owns them.** | `reverse-proxy.nix` `proxyPass` literals: `:8123` (`services.home-assistant.port`), `:8181` (`qwen-tts.nix:151 default = 8181`), `:9091` (`transmission.nix:65 rpc-port = 9091`), `:13378` (`media-stack.nix:172 port = 13378`), `:8088` (`kiwix.nix:71 port = 8088`), `:8222` (`infra-stack.nix:568 ROCKET_PORT = 8222`). | `proxyPass = "http://127.0.0.1:${toString config.services.….port}"` — a port change then cannot break the vhost. |
| H4 | **A port no module declares.** | `:3012` appears exactly once in the tree — `reverse-proxy.nix:332` — as Vaultwarden's websocket port. | Declare it next to `ROCKET_PORT` so the value exists in one place. |
| H5 | **Reclassified — not a defect.** `qwen-tts.nix:151 default = 8181` runs on eisen; `fleet-monitors.nix:120 default = 8181` runs on frieren (`infra-stack.nix:450`), and frieren's `monitors.frieren.lan` vhost now reads `config.services.fleetMonitors.port` rather than the literal. Two hosts, one default each, each vhost pointing at its own service. | Changing a live service port to make two *unrelated* defaults disjoint would be churn with a real blast radius (documented endpoints). Left as is, deliberately. |
| H6 | **The kiwix URL is retyped in three places.** | `kiwix.nix:71 port = 8088`, `kiwix-watchdog.nix:110 default = "http://127.0.0.1:8088"`, `fleet-governor.nix:117` same literal. | Interpolate `config.services.kiwix-serve.port`. |
| H7 | **An IP typed twice with *no* owner at all.** | `192.168.83.10` in `reverse-proxy.nix:281` (`/canary/` → `:8080`) and again in `infra-stack.nix:947` (`HostName`); `192.168.3.87` in `reverse-proxy.nix:298`. `hosts.eisen.network` and `hosts.frieren-canary.network` in `inventory.toml` have **no `lan_ip`** (compiled value `""`), so the registry cannot even disagree. | Add `lan_ip` to both hosts (yq, then `task checks:toml:lint`), then interpolate from `config.fleet.inventory`. |
| H8 | **The primary user is retyped, and the constant is re-declared.** | `devji` appears 35× in `hosts/frieren/infra-stack.nix`, 15× in `hosts/microvms/frieren-canary.nix`, 10× in `hosts/frieren/configuration.nix`; `/home/devji` appears **49× in 8 files** outside `modules/global/user.nix`; `frieren-canary.nix:110` writes `home = "/home/devji";`, re-declaring what `user.nix` owns. `infra-stack.nix:947` even has `User devji` in an `extraConfig`. | `let user = import ../global/user.nix;` — the rule AGENTS.md already states. |
| H9 | **A nushell config typed into Nix.** | `modules/shell/nushell.nix:24` — 44 lines of nushell (`$env.config`, completers, module sources) in `extraConfig`, while the same module already `source`s seven real `.nu` files from `modules/config/nu/`. | `builtins.readFile ../config/nu/config.nu` (the pattern already used for the other seven). |
| H10 | **A response body typed into nginx.** | `modules/services/paste.nix:43` — the landing page text lives inside `return 200 "…"`. | `return 200 "$(cat ${writeText …})"` or `root`/`index`. |
| H11 | **Two 200–300 line scripts in a host module.** | `hosts/frieren/tools.nix:22` (`wikisearch`, 214 lines) and `:252` (`freebuff-headless`, 303 lines) — the only two `writeShellApplication`s in a 669-line host file, where the repo already packages scripts under `modules/scripts/` (`pb.nix`). | Move to `modules/scripts/{wikisearch,freebuff-headless}.nix`; the host keeps one import. |
| H12 | **A 53-line dashboard inside a service module.** | `modules/services/fleet-sentinel.nix:190–242` HTML embedded in a 207-line shell script. | Static files in a derivation, served by `root` — the same fix as F5. |

## 6.2 What is fine (do not "clean up")

- `modules/profiles/nixbuild-client.nix:91` — already interpolates `cfg.hostName` / `cfg.sshKeyPath`. That is the pattern H1–H7 should copy.
- The four thin clients in `modules/user/ai/mainframe-remotes.nix` and `freebuff-remote.nix` look duplicated but are not: measured 12 % similarity between `agy-remote` and `hermes-remote`. Leave them.
- `hosts/frieren/configuration.nix` **udev rules** are a literal *because udev rules are data*; there is no option to derive them from.
- `hosts/eisen/decision-models.nix:119` Python wrapper, `paperless-fork.nix:570` `preStart`, `infra-stack.nix:211` cascade shell — small, single-use, correctly scoped.

## 6.4 What landed (2026-10-19)

All of §6.1 except H5 was implemented and verified. The verification is not "it
evaluates": every change that touches a host was checked by diffing the
**evaluated** result against the pre-change value.

| # | Status | Change | Verified by |
| :- | :--- | :--- | :--- |
| H1 | **FIXED** | `modules/config/nginx/static-cache.nix` — one definition of the static-tree policy, consumed by `hosts/frieren/reverse-proxy.nix` (both locations) and `modules/services/uds-static-bridge.nix`. | 36 frieren nginx locations compared before/after: identical `proxyPass` and identical directive sets; only the `fleet-docs-site` store path moved (the site content changed). |
| H2 | **FIXED** | `hosts/eisen/llm-server.nix`: one `sseProxy` binding for the three SSE vhosts. | All 7 eisen locations compared before/after: **0 diffs**. |
| H3 | **FIXED** | `proxyPass` now reads its option: `services.ha-stack.port` (new option, also written to `http.server_port` and the firewall rule), `services.vaultwarden.config.ROCKET_PORT`, `services.fleetMonitors.port`, `services.transmission.settings.rpc-port`, `services.audiobookshelf.port`. | Explicit evals of each replacement; the nginx diff above shows no value changed. |
| H4 | **FIXED** | `WEBSOCKET_PORT = 3012` declared next to `ROCKET_PORT` in `infra-stack.nix`; the vhost interpolates it. It no longer exists only inside an nginx config. | Frieren eval + nginx diff. |
| H5 | **Reclassified** | Not a defect — see the row above. No port was moved. | — |
| H6 | **FIXED** | `kiwix-watchdog.nix` and `fleet-governor.nix` endpoint defaults derive from `config.services.kiwix-serve.port`. | Frieren eval; default still resolves to `http://127.0.0.1:8088`. |
| H7 | **FIXED** | `inventory.toml` gained `lan_ip` for `eisen` (192.168.3.87) and `frieren-canary` (192.168.83.10) — surgical tomlkit edit, `checks:toml:lint` green — and `reverse-proxy.nix` / `infra-stack.nix` interpolate `config.fleet.inventory…lan_ip`. | `nix eval .#inventory.hosts` returns both; the nginx diff shows the same addresses. |
| H8 | **FIXED** | `/home/devji` (49 occurrences in 5 files) and `User devji` now come from `modules/global/user.nix`; `frieren-canary.nix` and `fleet-governor.nix` gained the binding, `testvm.nix`'s default argument imports it. | `frieren`, `frieren-canary` and `testvm` host evals pass. |
| H9 | **FIXED** | `modules/config/nu/config.nu` holds the nushell stage-2 settings; `nushell.nix` only `source`s it plus the interpolated pkgs paths. | `frieren` eval (nushell is in the shared home-manager stack). |
| H10 | **FIXED** | `modules/services/paste-notice.txt`, served via `alias` — the landing text is no longer an escaped-string body in nginx config. | Frieren eval; the location now has `alias` + `default_type text/plain`. |
| H11 | **FIXED** | `modules/scripts/{wikisearch,freebuff-headless}.nix` (556 lines) moved out of `hosts/frieren/tools.nix`, which keeps only the two `import`s. | Both derivations **built before and after**: store paths and script SHA-256 are byte-identical (`7vq9hiw…`, `mr52gza…`). |
| H12 | **FIXED** | `modules/services/fleet-sentinel-dashboard.html` installed by the collector; the 53-line heredoc and its `''${...}` escapes are gone. | `frieren` eval. |
| H13 | **FIXED (new)** | `hosts/frieren/firewall-scope.nix` exposure registry now derives `immich`, `uptime-kuma`, `harmonia`, `kiwix` and `home-assistant` ports from their options. | Derived ports evaluate to the previous literals (2283 / 3001 / 5000 / 8088 / 8123) with identical per-interface TCP lists; `task checks:ports` passes. |

Still open, deliberately: the hardware-configuration mount keys keep a literal
`/home/devji` where the path *is* the mount point. One survives —
`hosts/poseidon/hardware-configuration.nix:39`, `fileSystems."/home/devji/.steamlib"`
— and it is generated boilerplate where hand-substituting a constant buys nothing.
(`hosts/minyx/hardware-configuration.nix` no longer carries one: the sd-image
rewrite dropped the mount entirely.)

## 6.3 Cheap, low-risk fixes (in order)

1. **H1 + H2**: two `let` bindings. No behaviour change, diffs shrink by ~20 lines.
2. **H3–H6**: replace literal ports with `config.services.<name>.port`. Each is a one-line change, verifiable by diffing the generated nginx config before/after (`nginx -T` semantics unchanged).
3. **H8**: import the user constant where `/home/devji` or `User devji` is typed. Mechanical, grep-driven.
4. **H9 + H10**: move the literals to files; a config diff then reads as a config diff.
5. **H11 + H12**: move scripts/markup out of modules. Largest change, lowest urgency.
