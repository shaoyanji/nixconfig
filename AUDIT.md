# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. An entry older
> than a week rolls into the agent turn log — `task ops:audit:roll` posts it as an
> xs event and removes it here, because what happened is a turn, not a document.
> Design rationale lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`). Budget:
> 300 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-27)

Rows with a command were re-measured 2026-10-27; live-system rows (observation,
knowledge, backups, DNS, tailnet) last confirmed 2026-10-20.

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 35 devices: 20 active (13 NixOS, 7 external), 15 preserved, 0 wip | `nix eval .#inventory.derived`, `task dev:inventory:counts` |
| Host gates | per-host eval (assertions) and per-host VM boot to stage-2, one process each | `.#hostChecks.x86_64-linux.<host>`, `.#hostBootChecks.aarch64-linux.delphi` |
| Known red gates | `cassini` (xdg.desktopEntries on darwin), dormant. `minyx` passes its gate on its own arch (`ARCH` now resolves per host, so no flag); its hardware is the shortfall, not its config: continuous under-voltage in `dmesg` | `task checks:host HOST=minyx` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | frieren pihole+unbound owns the zone, minyx blocky+keepalived is the secondary behind VIP `192.168.3.50` (priority 200/1, unicast peers); delphi crab-hole answers public DNS only, same address | `task checks:dns:failover`, `docs/dns-failover.md` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-11-05 — mail atlas, sixth pass: the mailbox decides the inbox
- **The box only knew what the page was told.** Mail archived from a phone or the web client
  never reached `mail_box`, so it kept counting as inbox. `mail-atlas-reconcile` now reads the
  Message-IDs of the IMAP Inbox through `himalaya` (500 a page, 13 pages for 6394 envelopes)
  and writes the difference through two new endpoints, `/api/atlas-boxes` and
  `/api/atlas-box-set`: absent from the Inbox and `inbox` → `archived`, `queued` → `gone`, and
  present again →  `inbox`. `mail-atlas-reconcile.timer` runs it nightly at `04:20`, before the 06:30
  bulk sweep, so the sweep decides against a set that already knows what left the Inbox.
- **Both directions, measured on the live account:** 7 letters archived in Gmail became
  `archived` (inbox 2007 → 2000); a letter forced to `archived` while still in the Inbox came
  back as `restored: 1`; a second pass changed 0 rows. A walk stopped at the page cap exits 2
  and writes nothing (verified with `--max-pages 3`), because a partial set would empty the
  working set.
- **Box history.** `mail_box_event` is append-only: every move records `from_box`,
  `box`, a reason (`decision archive`, `drain done`, `left the inbox`) and a time, from
  all three writers. The handled list shows the last line with its age (`trashed · 1 h
  ago`), the reader the last four (`queued 3 h ago → trashed 1 h ago`), and existing
  boxes were backfilled as `recorded` from `changed_at`. A no-op write appends nothing
  (verified `changed: 1` then `0`). Postgres renders `+00`, which V8 rejects once there
  are microseconds — `parseTime` is why every `now()` timestamp stopped arriving blank.
- **The reader and the frame, tightened.** A modal `<dialog>` with `display: flex` renders when
  it is closed (an author rule outranks the UA sheet) — `dialog#reader:not([open])` is why a
  closed letter no longer leaves a slab at the foot of the page; the dialog is `height:
  fit-content` (the UA's `inset: 0` turns `auto` into a viewport stretch) and sizes to the
  letter. Bodies split into paragraphs across blank lines, one-sentence-per-line and hard
  wraps; subject clamps to two lines, snippet to one (rows 139 → 79-101 px); the page itself
  never scrolls, panels do; below 1180 px the field folds instead of the gates becoming a
  cramped strip over the list.
- **Verified:** three switches on delphi; `mail-atlas-reconcile.service` rc=0 in 15.5 s; served
  `style.css`/`app.js`/`index.html` md5-identical to source; the header reads `2000 INBOX`;
  `docs-budget` rc=0 (`mail-atlas.md` 303/400, this file 213/300); alejandra clean; task digest
  pin updated (569 tasks, parity exact).

### 2026-11-05 — mail atlas, fifth pass: the list is an inbox
- **A decided letter leaves the list.** `mail_box` (`inbox` / `queued` / `archived` /
  `trashed` / `gone`) is the working set; `/api/atlas-act` writes `queued` in the same
  statement that records the decision, `/api/atlas-close` records the outcome, and the page
  drops the row locally. Measured through CDP: mark → `a` took the list from 48 to 47, the
  header from 2037 to 2036 inbox and 0 to 1 queued, and the letter appeared under `queued`.
- **The page is an inbox, not a browse.** The list is the wide column (the field is 29 % and
  folds away, which also stops the particle simulation and survives a reload); tabs
  `inbox / queued / handled / all`; the header counts the working set; `more letters` pages
  with a new `off` parameter (verified 48 → 96 rows). Tag chips no longer appear when there
  is no query.
- **One command for Hermes.** `H` or the header button opens a sentence box with no letter
  behind it; it writes `mail_command`, read by `task agents:mail:atlas` beside the per-letter
  rows and closed with `/api/atlas-command-close`. Nothing executes it — no auto-drain for
  `hermes`/commands, by decision.
- **Verified:** six switches on delphi; `atlas-search` box filter and `atlas-stats`
  (`inbox`/`queued`/`commands`); command POST → row 1; four test rows and two test commands
  removed, queue empty; task digest pin updated (568 tasks, parity exact).

### 2026-11-05 — mail atlas, fourth pass: the queue is executed, batches answer
- **The timer had never executed anything.** `mail-atlas-drain` resolved a Message-ID with
  `envelope search 'subject "…"'`; a real subject (`[shaoyanji/nixconfig] Run failed: nixcachix -
  main (047f44a)`) is not a valid query, the oldest pending row threw, and the oneshot died before
  reaching the rest. The run also missed `cat` on the unit's `PATH`, so himalaya could not read its
  password. Resolution is now: `date` of the message, its two neighbouring days (the `Date:` header
  carries the sender's offset), one alphanumeric token of the subject — the header still decides —
  and a miss closes the row `dismissed "not in inbox"`. `coreutils` joined the script's runtime.
- **Proof, measured:** three live rows executed — `moved uid 308188`, `trashed uid 309635`,
  `trashed uid 310174` — and two rows queued against already-archived mail closed as `not in inbox`.
  A run that resolves costs ~7 s; the old full-mailbox fallback (`--deep-scan`, 60 pages) cost **74 s**
  on this 6000-envelope inbox. The timer fires on its own every 5 min (`*:0/5`, 20 s jitter,
  persistent) — observed at 13:15:42 with `pending: 0`.
- **Batch decisions did nothing.** `space` marked rows but `x`/`a` posted the row `id` where
  `/api/atlas-act` binds `messageId`; every insert failed the foreign key and the page reported "the
  archive did not answer". Selection and the queued badge are keyed by Message-ID now, and two marked
  newsletters queued in one gesture (verified through CDP key events, `2 queued · delete`).
- **The list's keys:** `space` marks (click on the row's box too), `a`/`x` apply to the marked set or
  the focused row, `x` twice queues, `Esc` clears the marks.

### 2026-11-05 — mail atlas, third pass: decisions, clean text, no pointer-driven frames
- **A letter can be decided.** The reader carries `archive`, `queue deletion` and `send to Hermes`
  (`a` / `x` / `h`); deletion asks twice, and Hermes takes a free-text instruction. They write
  `mail_action` rows — requests, never effects — read by `task agents:mail:atlas` and closed through
  `/api/atlas-close`. Posting one also resolves the message's open `email_triage` verdicts.
- **The page stopped printing markup.** Escapes (`\u00E4`, `ma\_77`), HTML entities (`&ldquo;`),
  double-escaped tags, headings, rules, link and image syntax are reduced to text at render; the
  stored body is untouched. Over all **2051** archived bodies no delimiter, entity or escape
  survives outside tokens (`WPC__Kg`, a masked phone number).
- **The particle field was drawing scratches.** `particles.wat` pushed velocities to ~6 px *per frame*
  (≈375 px/s), so every comet tail — a frame count times that velocity — became a line 300–1000 px
  long across the page. The push constant is now `0.0105` (measured **43 px/s** at rest, **79 px/s** at
  3.4 amplitude) and the tail is capped at 12 frames, so a fast particle reads as a short stroke.
- **The pointer no longer times the animation.** The graph's loop used to stop at rest, so a mousemove
  was the only thing painting a settled graph and every move re-phased the sweep and the sparks.
  The loop now always requests a frame (half rate when settled) and nothing outside it draws.
- **Enter works with the caret in the search box,** as long as that box still holds the query the
  list was built on; arrows and Enter were re-tested through CDP key events, not by calling handlers.
- **Verified:** two switches on delphi; headless Chromium against the running vhost with the cache
  disabled — `↵` opens the reader, `Kühler`/`#id#` render without escapes or brackets, the three
  buttons read `queued` after posting and still read it when the letter is reopened, 11 rows of test
  decisions were removed afterwards, `task agents:mail:atlas` prints the queue, no console errors.

### 2026-11-05 — mail atlas, second pass: the search drives the instruments
- **Tofu, fixed at the root.** The Han glyphs (title, seal, ten gate glyphs) came from whatever CJK
  font the reader's OS happened to have, and a machine without one drew boxes. `han.woff` is a
  build-time `pyftsubset` of Noto CJK TC covering the 28 glyphs the page writes — **11.9 kB**, served
  same-origin with `font/woff`; the canvas labels name the family explicitly because canvas has no
  fallback chain beyond what you pass it.
- **The graph now carries the answer.** Every node has a heat from the result set: gate gauges show
  the share of the answer a gate claims, tag diamonds and letter dots scale with it, unclaimed gates
  stay faint, hot links carry travelling sparks and the outer ring sweeps. Positions persist across
  keystrokes, so typing moves the field instead of rebuilding it. `data-hot`/`data-layout` expose the
  state the way the page renders it (17/52 for `?q=invoice`).
- **The WASM field moves with the query.** `mood(amp, swirl)` is the only channel from page to
  simulation; measured on the built module, mean particle speed goes **4.65 → 11.24 px/s** at
  amp 3.4 and settles back, and a dry query tints the current gold. The page schedules the impulses:
  an inhale at the search box on submit, a ripple per keystroke, a heartbeat at the graph centre
  when results land. `data-state` is `found`/`void`/`seeking` from that, not from a CSS class.
- **One fuzzy classifier, two renderers.** Exact substrings get a solid `mark`, subsequence matches a
  dotted one, and canvas labels draw the same runs in gold. Snippets drop markdown images and
  tracking URLs before rendering. Mobile thins labels by heat instead of shrinking them.
- **Verified:** switch landed; `han.woff` `font/woff` 11900 B, `particles.wasm` `application/wasm`,
  `/openapi.json` `200` through the new route; headless Chromium on `:8085` reported `found`/17 hits,
  `void`/0 for `?q=zzqx`, 48 letters for `?q=kleinanzeig`, **no console errors**, and 390×844 renders
  without overlap.

### 2026-11-05 — mail atlas: the archive gets a reading surface
- **A taxonomy, not a folder.** `mail_category` (10 domains, glyph + stance), `mail_tag`,
  `mail_tag_rule` and `email_tag(message_id, tag, source)` in `email_archive`; the rules pass
  (`mail_atlas_autotag`, hourly at `:50` via `mail-atlas-tag.timer`) placed 1536 of 2050 messages
  on the first run in 0.47 s and adds 0 on a second. `pg_trgm` is created by db-init as `postgres`
  because the plugin schema runs as the archive role.
- **Fuzzy finding is three signals**: `ts_rank` on the body, trigram `similarity` on subject and
  sender, and tag similarity; `coalesce(:q,'')`/`coalesce(:cat,'')` because an empty query-string
  value arrives as `NULL` and every unfiltered search answered `[]` with a `200` until it did.
- **The page** (`modules/services/mail-atlas/site/`) is one nginx vhost on `127.0.0.1:8085` with
  `/api/` proxied same-origin, mounted at `https://delphi.cloudforest-kardashev.ts.net:8452` by the
  portal registry (8451 stays reserved for the archive rival). A flow-field particle simulation is
  compiled from `particles.wat` by `wabt` at build time (918 B of real WASM); the relation graph is
  a spring simulation over query → categories → tags → letters.
- **Verified:** `hostChecks aarch64-linux.delphi` 1974/1974 assertions; switch landed; page `200`,
  `particles.wasm` served as `application/wasm`; headless Chromium rendered 48 letters for
  `?q=kleinanzeig` and 12 for `?q=invoice` with `<mark>` highlights, no console errors.

### 2026-11-04 — downloads-sort stops calling a dead download "in flight"
- **The unit was red for a bug, not a decision.** `strata-probe.bin` (39.7 GB, preallocated, one
  `IQ3_XXS-00001` header and none of its bytes) carried an `.aria2` control file from 11-03 that
  aria2 had no record of (`tellActive`/`tellWaiting`/`tellStopped` all `[]`); the sorter tested the
  control file alone, so it printed `INFLIGHT` hourly forever and staging never emptied.
- **That case is `STALLED`**; with aria2 unreachable a control file still means INFLIGHT.
  `*SUMS`/`*.sha256`/`*.md5`/`*.log` are `SIDECAR`, and `.gguf` routes to `software/models/` after the
  classifier answered "software" and moved 149 GB mid-job — sizes match HF, nothing truncated.
- **Staging is empty:** corpse and companions in `downloads/.stale/` (38 GB); `Result=success`,
  `/sentinel/status.json` `{"state":"ok"}`, gatus green.

### 2026-11-04 — the duplicate monitors leave frieren; the alert sink stays behind
- **Retired, and nothing was lost by it.** frieren's `gatus` and `uptime-kuma` are gone, with the
  `status.`/`monitors.frieren.lan` vhosts and the 3001/8181 holes. Both kuma databases held **zero
  monitors** (`select count(*) from monitor` = 0 on each: 37 MiB of dashboard, 0 checks), so the
  checks that existed were gatus's ten endpoints.
- **They moved to delphi**, where `services.fleetMonitors` probes the NAS across the tailnet —
  jellyfin `:8096`, immich `:2283`, home assistant `:8123`, harmonia `:5000`, audiobookshelf by
  `Host: audiobooks.frieren.lan`, paperless on `127.0.0.1:28981` — each port one frieren's
  `serviceExposure` registry already opens on tailscale0. The Steam cache (loopback only) and the
  resolver check (`10.99.0.53` is delphi's own failover address) cannot be carried by a probe.
- **The alert path inverted.** delphi has the checks and no SimpleX identity; frieren has the
  identity (`~/.simplex`) and no gatus. `alerting.address`/`url` are options now: frieren keeps the
  bridge on `0.0.0.0:5226`, opened only on tailscale0, and delphi's gatus posts to
  `100.97.61.65:5226/alert` — proved by a POST and by gatus's own triggered alert arriving.
- **Also:** the 05:00 scorecard reads delphi's API; exposure, portal, restic paths and
  `docs/frieren-access.md` dropped the dead units. `checks:host` green on both (delphi 1973
  assertions, frieren 23.7 s), both switches landed, `is-system-running` = `running`.

### 2026-11-04 — the agent-suite loss is the engine's prefill guard, and IQ1_M answers it too
- **The tier question is closed, and not the way the docs first said.** IQ2_XS at
  `--max-context 16384` loaded with `636 MiB of VRAM free` and 50.9 GB RSS, then aborted on the
  **4K prompt** stage; `--no-ple` is refused outright under `--native` ("the PLE key is native
  too"), so the PLE table in the larger packs is not a ~28 GB shard that can be dropped. Both
  hypotheses for making 68/76 GB fit are dead.
- **Then the served pack lost the engine the same way.** `tools/strata_bench.py --runs 3` on
  IQ1_M at 16384 stalled in 3 of 3 agent runs, turn 3 of 6, always `layer 1 of the prompt chunk
  from token` 9076 / 9121 / 9063, with the engine's own guard (`no progress for 60 s`, exit -6)
  and the wrapper respawning it. `oom_kill` 0, no kernel line, 636 MiB VRAM free at load: it is
  the prefill path, not memory, not VRAM and not the quant.
- **Context 16384 was reverted.** It truncates the session at turn 3, so the KV it saves buys
  nothing: served is IQ1_M at `--max-context 32768`, `--kv int8`, MTP on, 24 engine threads.
  The 16K baseline stands as the number to beat — chat median 11.30 tok/s, 4K prompt 166.8 tok/s,
  agent cache hit 55.8 %, per-turn first token 93.77 s, agent decode 8.40.
- **Also landed:** `LimitCORE = "0"` on `strata.service` (a 2026-11-04 abort spooled ~50 GB into
  systemd-coredump's temp file and took `/` from 44 to 94 GB for five minutes); the runbook now
  carries the transient-unit retest recipe plus the two traps (`.venv/bin/python` needs the FHS
  env, no `/bin/bash` on this host); `hosts/eisen/MANUAL.md` §7 carries the tier table, the 16K
  baseline and the stall; `strata-quant-tier` was distilled to the 30-line budget and the engine
  work split into `strata-engine-bump-retest` (0.1.56 rebuild, the prefill rework is the prize).
- **Upstream:** reported as [Niko1221/Strata#5229](https://github.com/Niko1221/Strata/issues/5229)
  (the guard's own message cites the closed #29) with the three stall sites, the build
  fingerprint and the four questions; cross-commented on #4566 and #3807, which track the same
  family on 0.1.46/0.1.47 and on gfx1031.
- **Verified:** `git push` gates (docs budget, docs links, task-graph digest pin) green on every
  push; the switch landed (`/run/current-system` = `d5g8xiyw…`, `strata` active, `n_ctx` 16384 at
  the time, later 32768, `LimitCORE=0`); eisen was then powered off on request.

## Open debt (`task ops:notes`)

1. `cassini`'s darwin assertion (`xdg.desktopEntries`) — dormant, reproducible
   with `MODE=eval`; `minyx`'s kernel conflict is gone (the board evaluates,
   passes its gate and is active since 2026-10-27).
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
