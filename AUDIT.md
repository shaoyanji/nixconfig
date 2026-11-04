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
### 2026-11-03 — eisen gets a TTY-only `server` persona
- **The gaming desktop is no longer the only way eisen boots.** `hosts/eisen/server.nix` is
  `specialisation.server` (declared in `configuration.nix`): it subtracts SDDM, niri/Ryoku,
  gamescope, Steam, gamemode, Sunshine, the gaming guard's `/proc` walk, and the
  `video=HDMI-A-1:1920x1080@60` mode that exists only so gamescope has a known output. Both
  toplevels ride in one generation, so systemd-boot lists the persona and nothing is rebuilt to
  pick it — `bootctl list` on the next boot, or
  `/run/current-system/specialisation/server/bin/switch-to-configuration switch` live.
- **Why subtraction and not a new service:** the desktop stack holds ~450–500 MiB of VRAM at idle
  (`hosts/eisen/MANUAL.md` §3) on an 8.18 GiB card, which is resident expert slots, plus the Steam
  client's RAM that an mmapped 68 GB expert arena would rather see as page cache.
- **The one trap:** `services.displayManager.defaultSession` is forced to `steam` in the base and
  nixpkgs asserts it names a real session, so the persona must override it — `lib.mkForce null`
  *conflicts* with the base's mkForce (an option cannot be both types), hence `lib.mkOverride 10`.
- **Verified:** `checks:host HOST=eisen` green (module system + 2020 assertions, 262 s / 2.6 GiB on
  frieren); the specialisation's own module system evaluates with zero failed assertions, and the
  overrides are the ones the module claims (`sddm`/`xserver`/`steam`/`gamescope`/`ryoku`/`sunshine`
  false, `defaultSession = null`, `defaultUnit = multi-user.target`, guard disabled, kernel params
  without the HDMI mode); compiled inventory + `checks:inventory:compiled` green.
- **Not verified — and it is what the boot menu needs:** the specialisation toplevel has not been
  built. eisen was off the network for the whole turn (`arp FAILED`, `tailscale ping` timeout,
  `ssh: No route to host`) and frieren must not instantiate a host closure. The first
  `nixos-rebuild boot` on eisen builds it; `bootctl list` must then show the `specialisation
  server` entry.

### 2026-11-03 — eisen generation 30 landed; a third of it came over the LAN, and the box is DDR3
- **The two-week drift deploy is live**: `nixos-system-eisen-26.11.20261016.f20cd90`, toplevel
  `gxjdavda…`. `nixos-rebuild` (as `devji`) built the whole closure and then failed at the profile
  symlink — root cannot eval this flake's git dir and `devji` cannot write the system profile, so the
  fix is `nix-env -p /nix/var/nix/profiles/system --set <built>` + `switch-to-configuration switch` as
  root. Same for the next one: build as `devji`, activate as root.
- **Substitution sources, measured from the unit journal** (narSize sums): `192.168.3.25:5000` 761
  paths / **9.89 GB**, numtide 1611 / 10.68 GB, cache.nixos.org 469 / 5.28 GB, `eu.nixbuild.net` 200 /
  3.40 GB, cachix 143 / 0.21 GB — **29.5 GB total, 34 % of it LAN**. The remaining ~19.6 GB over a
  measured ~2.6 MB/s WAN *is* the 1 h 59 m wall clock; the gigabit hop was never the constraint, but
  "nothing came from the LAN" was wrong (a 10-path sample drawn from the log tail, i.e. exactly the
  paths frieren lacks).
- **eisen is DDR3-1600, not DDR4 quad-channel.** `dmidecode -t 17`: 4 × 16 GiB Hynix rank-2
  **DDR3 1600 MT/s**; EDAC `dimm_mem_type` = `Unbuffered-DDR3`; 62.7 GiB usable on a Machinist X99
  PR8-H DDR3 board. Corrected in `inventory.toml` (compiled truth), `docs/eisen-llm-architecture.md`,
  `hosts/eisen/MANUAL.md`, `HANDOFF.md`, the `llm-server.nix` threads comment, the regenerated
  `.agents/fleet-matrix.md`, and the open cell in `hosts/delphi/reports/utility-layer-recon.html`.
- **`strata.service` now stops instead of looping**: `ConditionPathExists=/dev/dri/renderD128` with
  `StartLimitBurst=3`/`StartLimitIntervalSec=300`, verified live (`ConditionResult=yes`, unit back and
  serving `qwen3.8-flash-next-coder-iq1_m` on `:8085` after a ~130 s load).

### 2026-11-03 — the Appwrite project expires on purpose
- **`dragon court` is abandoned, not restored.** Appwrite Cloud (org `bountystash`, created 2024-04-21)
  warned that the paused project is deleted on **2026-11-17**. Nothing in this tree, in any `shaoyanji`
  or `Bountystash` repo, or in sops names Appwrite, so no caller, key or CI job breaks when it goes.
- **Restoring was the alternative and was refused:** it stops the clock, not the question — the project
  pauses again on inactivity and mails the same 14-day warning. Look-then-decide (restore, browse, export,
  delete) was offered and declined. Record: `appwrite-dragon-court-abandoned`.

### 2026-11-03 — the Vivid reply went out, and a draft without `From:` could not
- **Sent, not drafted.** The BESS Construction Manager reply to Ally Freeman (Vivid) left the
  `jisifu` Gmail account as `Matt Ji <matt@bountystash.com>` with the tailored CV and German
  Anschreiben attached, threaded on her subject. Verified by posting the same message to the account
  itself: the delivered copy carries `From:`, both PDFs and a decodable body, while the copy
  `himalaya message send --save` appends to Sent is serialized **without** `From:` — the local copy
  loses a header the recipient never misses. 81 KiB on the wire, both attachments intact.
- **Drafts now carry a sender.** `appflow-sync` saved drafts with no `From:`, so a saved draft could
  not be sent as-is: himalaya takes the SMTP envelope sender from that header. `draft_message` sets
  `SENDER` (`APPFLOW_SENDER`, default `Matt Ji <matt@bountystash.com>`).
- **Record and queue agree.** `vivid-construction-manager-bess-2027` is `applied` — *CV + letter sent
  03.11.2026, awaiting reply* — and her mail row is resolved (7 verdicts), so the row leaves the human
  queue while the reply is outstanding.

### 2026-11-03 — triage routes by rule, and two models may disagree
- **The 511 was a routing inversion, not a backlog.** `machine sender:` fired on `noreply@`/`mailings@`
  and returned `action`/`human`, and `PROTECTED` forbade the second model from closing verification and
  security-alert mail — 203 + 104 rows manufactured by two lines. Rules now run deadline → record →
  one-shot → machine sender, so the same mail is `action`, `digest`, `robot`, `digest`.
- **`julia` and `laya` override each other** in both directions; only a tie keeps the assigned tier, and a
  sender that keeps writing with no deadline is a feed → `digest`. `triage.expireDays` resolves `review`
  rows untouched for 30 days; `triage.pointers` (gumball) is exempt and expires at 7.
- **Application mail reaches the pipeline.** A plugin may claim by subject, so `Bewerbung`/`application:`
  from an employer's own mailbox goes to `agent:apps` instead of a person: 68 rows, 9 statuses written,
  5 applications discovered on the first sync.
- **`task agents:mail:sweep`** resolves a block by selector (`SENDER=`, `OLDER=`, `TIER=`), dry by
  default and refusing to run with no selector. Human queue **511 → 50** in one pass: 307 rows re-tiered
  by rule, ~150 old review rows expired, 235 CI notices closed by the drain, 43 application mails taken
  by the pipeline. The 50 left are 21 action, 2 person and 27 review — readable in one sitting.
- **A classifier bump has to move the second opinion with it.** Bumping only the first name left rows
  the second pass believed it had judged and the queue grew 47 → 83; the second name is now derived from
  the first. Each run also takes 500 messages, so a new name needs three hourly runs to finish the archive.

### 2026-11-03 — the queues drain themselves, and the ledger rolls into the turn log
- **Every queue now has a consumer.** `agent:ci` held 237 open and 0 resolved ever: the triage unit's
  `ExecStartPost` runs `email-ci-drain.py` (`-` prefixed, so a drain failure cannot mark the classifier
  red) and closed 234 — a notice older than 14 days is stale, and only the newest per repo+workflow
  survives. The 3 left are the newest of nixconfig/nixcachix, Obsidian-Git-Sync/CI, .dotfiles/tests.
- **The pipeline sync stopped being a reflex.** `appflow-sync.timer` runs `--sync --apply` hourly at :00,
  11 minutes after the classifier files at :49; an empty queue exits in 222 ms.
- **The ledger is not a document.** `task ops:audit:roll` posts each entry older than a week as an xs
  event (subject `nixconfig:ledger-<date>-<slug>`, whole body, id derived from the subject so a retry is
  the same event) and removes it; `AUDIT.md` keeps current state plus the recent week. Two entries rolled
  on the first run, read back from the log.
- **A switch refuses a written tree.** `switch-preflight.sh` fails on tracked modifications unless
  `ALLOW_DIRTY=1`, which then stamps commit, diff hash and time into `~/.local/state/nixconfig-dirty-rev`:
  generation 160/161 were built from trees no commit describes.
- **Agents read TOON.** Reporting and queue tasks print TOON by default (`FORMAT=text` for a person,
  `FORMAT=json` for a machine), including the xs list; the CI drain reports a count and five rows, not
  237 ids. `docs/email-archive.md` 400 → 383 and `docs/nix-patterns.md` 400 → 375, so neither sits at
  the wall that fails the next paragraph.

### 2026-11-03 — the importer's window was the bug, and a second model takes work off a person
- **The stall had a fixed cause.** `maxPages × pageSize` bounded both the scan and the `known` set, so from
  2000 archived messages on a run found only known mail and still exited 0. `known` is now complete
  (`--known-limit`) and the scan depth derived (`--max-pages 0`): `--limit 800` imported 800 across 25 pages
  where the old code stopped at 700 of a 5000-message request.
- **A second architecture re-reads the human queue.** `serve.secondary` serves `laya` on 8092 in the same
  sandbox (~24 MiB); the triage asks it about what a person is holding and only lets it demote. First run:
  427 of 872 closed as bulk, with invoice and application subjects protected (16 of 500 would have been
  money or candidacy mail). Human queue 872 → 511; `agent:apps` returned to 0.
- **Drafts, not sends.** `--draft` writes an RFC 5322 draft with its attachments into Drafts through
  himalaya; verified by downloading the 24,791-byte PDF back out of the draft, then deleting the test.
  `agents:apps:set` now calls the plugin's own stage ladder instead of an awk copy that already disagreed.
- **Agents read TOON.** `JSON=1` on the reporting tasks, `TOON=1` projects it through the `toon` binary;
  text stays the default, so the tasks read the same to a person as before.

### 2026-11-03 — the pipeline queue stops refilling: acknowledgements count, alerts leave
- **German acknowledgements and already-held events kept mail open**, so the same message returned every
  run; both close now with the reason in the ledger, and "Application Received" maps to `applied`.
- **An alert is not an application**: relays send alerts from the same address as application mail, so
  "Vollzeitstelle in Freiburg" reached `agent:apps` with a body whose "interview" looked like evidence, and
  discovery could mint a record from it. The subject decides unless it states an event.
- **Evidence**: queue 4 → 1, no status rewritten, a second run closes 0, deployed `sync.py` equals the repo
  file; the one left is Tibber's note, naming no employer in its subject.

### 2026-11-03 — delphi activates the guest plugin, and the boot test stops firing on a pin
- **The plugin is live**: generation 160 at 13:26 carries `services.appflowPlugin.enable`. Evidence from the
  running system, not the exit code: `/api/plugins` lists `agent:apps` (open 4, resolved 23), the 12
  application routes appear in `/openapi.json`, `applications`/`application_mail` exist with 151/78 rows, and
  `appflow-sync` resolves on PATH so `task agents:apps:pipeline` prints the stage counts.
- **The boot test fired on a taskfile pin.** `switch-preflight.sh` treated every `flake/*` file as stage-1
  input, so moving `flake/taskfile-digest-pin.nix` started a full VM boot — under TCG, because this OCI
  instance exports no `/dev/kvm` (`accel=kvm:tcg` logs "failed to initialize kvm" and boots anyway). The
  task plane is now excluded, `BOOT=auto` skips with `reason=no /dev/kvm`, and `BOOT=1` still forces it.
  Verified three ways: auto on this host skips, a real `flake/devshells.nix` edit still says `BOOT=run`, and
  `BOOT=1` overrides.
- **Two gates were red, both from this work.** `nix-header-budget` flagged the comment essays atop
  `modules/plugins/appflow/{default,packet}.nix` and `modules/scripts/html2markdown.nix` (now three lines
  each, rationale only in the plugin README); `secrets-mirror-is-a-copy` caught
  `email-archive.vip-senders` written only into the mirror, which moved into the submodule and re-synced.

### 2026-11-03 — the packet is a plugin's Nix build, and one JSON Resume is the base
- **The PDF step left the runtime entirely.** `modules/plugins/appflow/packet.nix` is a derivation: `typst`
  0.15.1 from this flake's pin, Libertinus bundled with it, two templates and `strings.json` copied into the
  sandbox. `nix build` returns the packet; `task agents:apps:packet` only writes the JSON inputs. No Node, no
  uv, no venv, no font package, no network, and nothing installed on the host.
- **A guest, not a resident.** The pipeline's tables, endpoints, importer and packet moved from
  `modules/services/` to `modules/plugins/appflow/`; the mail hub declares only `rules`, `sql`, `schema`,
  `packages`, and delphi opts in with `services.appflowPlugin.enable`. Deleting the directory removes every
  trace; nothing in the hub imports it by name.
- **One base file.** The base is a JSON Resume, not two bespoke documents: `~/.config/appflow/resume.json`
  holds the contact block, work, education and skills, and the CV template walks those arrays. It is operator
  state because the upstream repo is private and carries a date of birth and a street address. Language is a
  field, not a second document: the application record picks `de`/`en` and headings plus month names come
  from `strings.json`.
- **A sandbox clock is not a clock.** The first render dated the letter *1 January 1980* — a Nix build runs
  with `SOURCE_DATE_EPOCH=1980-01-01`, so `datetime.today()` is the epoch. The date is now an input the task
  passes in, which also makes it part of the build hash. Verified by reading the artefact, not the exit code:
  `pdftotext` on a real record (`adorsys-gmbh-ai-engineer-m-w-d`) shows the real header, `3. November 2026`,
  the German letter body and the CV sections.

### 2026-11-03 — the pipeline moves next to the mail, and the VIP list becomes declarative
- **`applications` + `application_mail` in the archive database.** The workflow's schema (149 records) imports
  as-is with `stage` derived from `task apps:overview`'s rules beside the freeform `status`; the join table
  carries `matched_by` and `confidence`, so a company match is recorded as evidence and never overwrites.
  Token matching was removed after it gave one record whose `company` is a role name ~30 mails from
  unrelated employers; the phrase rule links 74 and that record 0.
- **`owner = agent:apps`** routes ATS mail to the pipeline (`greenhouse`, `personio`, `join.com`, …) and job
  alerts to `digest`. `/api/attention` now excludes every `agent:*` owner — the person queue was showing the
  pipeline's 27 ATS mails, which is exactly the pollution a queue dies of.
- **The VIP list is sops, not state.** `email-archive.vip-senders` in `modules/secrets.yaml`, landed 0400 by
  sops-nix; the tmpfiles state file it replaced is gone. Verified end to end: the VIP's mail reads
  `person / VIP address` in the queue, and the classifier's comma-split handles one sops line.
- **Evidence:** 149/149 records imported (prep 62, applied 34, lead 22, rejected 22), 1100 messages re-judged
  in 2.9 s under `rules+engine+apps` (agent:ci 236, agent:apps 27, person 4, review 239).
- **The database writes, the JSON is exported** (the sunset direction chosen 2026-11-03). `agents:apps:sync`
  writes status from ATS mail — monotonic (`received < follow-up < interview < rejected`, oldest message
  first, so a September acknowledgement cannot overwrite an October interview), one application per message,
  ledger with alternatives — then resolves the mail. First live run: 4 updates (WattFox applied → follow-up
  → interview, adorsys applied → follow-up → rejected), queue 27 → 23. `agents:apps:export` regenerates
  `applications.json` key-for-key from `/api/applications-export` (verified: 149 rows, identical key set).
  What is left is the workflow repo becoming a client (its `bin/` still reads the JSON).
- **The hub is plugins, and it hydrates the tracker.** `services.emailArchive.plugins` turns a sender list,
  a tier and an owner into routing (`GET /api/plugins` reports every owner's depth; `task agents:hub` prints
  it), so a third plugin is config. Verified by loading a rule set directly: a `gatus@` sender routed to
  `agent:fleet`, an unknown sender fell through to the engine.
- **Mail discovers applications.** A message naming an employer the pipeline lacks creates a row with
  `origin = 'discovered'` and its `message_id` ("Willkommen bei AmRest", "Deine Bewerbung bei Lease a Bike"),
  then the same monotonic write applies — AmRest landed as `Rejected (email 2026-09-23)`, Lease a Bike as
  `Follow-up Required`. ATS boilerplate with no status resolves as noise, ledger intact: the pipeline queue
  went **22 → 4** in one pass.
- **The hub counted double and was fixed:** `plugins.sql` first reported 1399 open for 1100 messages,
  because both classifiers hold a verdict. It reads the newest verdict per message, like `/api/attention`.

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
