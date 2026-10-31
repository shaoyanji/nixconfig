# AGENTS.md

**Nixconfig** — Personal Nix flake managing NixOS, nix-darwin, and Home Manager across the hosts registered in `inventory.toml`.

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `taskfiles/README.md` for ownership and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth. Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md` — see `.agents/README.md` for the full index.

---

## Agent entry contract (read this first)

1. **This file is the manual, not the rulebook.** The documentation contract is
   [`.agents/SCHEMA.md`](.agents/SCHEMA.md): one fact one home, budgets, status
   vocabulary, skill frontmatter. Every living doc is bounded on purpose.
2. **Start from intent.** `task help` → `task find:<word>` → the owning shard.
   Never invent a task name; never add one before walking the ladder in the
   `task-plane` skill (eval → jq → Nix lib → check → task → script → Go).
3. **Truth order:** compiled data (`inventory.toml`, `modules.toml`) → host and
   module Nix → taskfiles → docs. A table that exists twice is a liability.
4. **Facts are evaluated, not guessed.** `nix eval .#inventory…` (~0.2 s) or
   `nix eval .#agentSkills…` (~1.2 s). Never evaluate a full host to answer a
   fact question; never run `nix flake check` on this host.
5. **Verification is phased:** eval to catch a config error · build to prove a
   closure · size to plan a build. **Never run a check before a local rebuild**
   except the boot — the switch already evaluates and builds, so a pre-flight
   check re-instantiates the whole toplevel for no extra proof. A boot is the
   thing a switch cannot prove before it happens: `checks:boot:self` on nixos
   (BOOT=1, default) runs the config; `checks:boot` is the CI path for others.
6. **This is a live host.** Bounded gates only, one host per process, no
   top-level evals during the 03:00–05:30 window, and no ssh in unattended
   paths. Watch `task ops:health` before blaming the config.
7. **Ask the record before you write.** A task that is novel to you starts with
   `task ops:notes:near Q="<intent>"` (ranked notes, each with its lineage) and
   `task ops:notes:lineage ID=<id>` — so an idea attaches to the one it grew out
   of (`from`) instead of restating it. Then: proposal and open work → an
   `AGENTS.nix` note (`task ops:notes`; authoring: `agents-notes` skill); what
   happened → `AUDIT.md`; history → `docs/history/`; procedure → `docs/` or a
   skill. No new root markdown file [[flake/policies.nix#root-markdown-closed]].
8. **Do not read `AGENTS.nix` in full.** It is a ~3,500-line compiled data store;
   reading it whole wastes context. Query it with `task ops:notes[:host|:show|:search]`
   or `nix eval .#agentsNotes…` (0.2 s). Structural "what touches X" questions go to
   the knowledge graph (`task ops:kg[:host|:skill|:doc|:blast]`), not `grep`.
9. **The closed loop is real:** `fleet-sentinel` records jobs, generation age,
   disk and PSI every 15 min; gatus pages on `[BODY].state != ok`. A green
   socket is not a successful job — read the ledger.
10. **TOON is the IR: consume it, emit it, and let the machine own the formats.**
    JSON is the linking layer a program consumes; TOON is its projection for an
    agent. TOML, YAML and Nix are source truth and cross the boundary in their own
    tools (`yq -p toml -o json`, `nix eval --json`, `toon -d | yq -o yaml`), never
    by hand. Repair only the interface: `task dev:toon:fix` recounts `[n]`, and
    `checks:toon` / `checks:toon:surfaces` keep both rules true.

## Agent turns: the xs coordination endpoint (mandatory)

Every agent governed by this file produces and consumes the fleet turn log on
**delphi**. It exists so an agent can see who is working on what, from which base
commit and branch, before it starts, and so a merge or a test is checked against
what actually landed instead of a stale chat report. It is coordination state,
not a chat relay, and it changes no merge authority: a builder still does not
merge unless a task says so.

Endpoint: `https://delphi.cloudforest-kardashev.ts.net:8449`, tailnet only. A
`tailscale serve` front on 8449 proxies the loopback shim; there is no public
route and no other port. The token is a sops secret and is never written down:

```bash
X=https://delphi.cloudforest-kardashev.ts.net:8449
export AGENT_TURNS_TOKEN="$(sops -d ~/Documents/nixconfig/modules/secrets.yaml | yq -r '.["agent-turns-token"]')"
```

**Before a turn** — read the recent turns for the repo, then the subject, and
look for a live claim or an `in_progress` twin:

```bash
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" "$X/v1/events?repo=nixconfig&limit=20" | jq '.events'
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" "$X/v1/events?subject=nixconfig:my-task" | jq '.events'
```

If another agent claimed the same area or is `in_progress` on the same subject,
stop and report the collision; do not start a parallel edit that will conflict.

**After a turn** — append one summary. `201` plus an entry id is success; `200`
means that UUID is already stored and the post was a safe retry.

```bash
curl -sS -H "Authorization: Bearer $AGENT_TURNS_TOKEN" -H 'Content-Type: application/json' \
  -X POST --data @turn.json "$X/v1/events"
```

`turn.json` carries exactly these fields; the shim rejects unknown ones, which is
what stops a transcript being posted as an extra key:

- `id` client-generated UUID (the dedup key) · `ts` RFC 3339 · `source` agent name · `kind` `"turn"`
- `subject` `<repo>:<task-id>` — the repo prefix is what `repo=` filters on · `action` one line
- `rationale` string or `null` · `base_commit` git hash or `null` · `branch` name or `null`
- `files_changed` list · `commits` list of hashes · `claims` list of areas or files claimed
- `outcome` `done` | `in_progress` | `blocked: <one line>` | `failed: <one line>`

Summaries and identifiers only: no secrets, tokens, passwords, private keys, mail,
no full conversation text. The shim scans free text and refuses credential-shaped
bodies with a 400, and there is no update or delete route (405 by design).

If the endpoint is down or a post times out, `task agents:xs:post` appends the body
to `~/.local/state/agent-turns/queue.jsonl` itself and the next successful post
replays it in order — a repeated UUID returns the stored id, so replay is
idempotent. Continue the turn and report the queue depth. Never post a
turn copy to any other endpoint or publicly, and never use it in place of the
structured prompt and report files you already use to hand work to another agent.

Backup hook (cadence is an open decision, so nothing schedules it yet):
`task infra:xs:export OUT=<dir>` on delphi writes `frames.jsonl` plus `cas/`.

## Home Initialization & Tautological Control Plane

When an AI agent or developer session initializes from the home directory (`$HOME` / `~`):

1. **Repository Root & Provenance**:
   - The canonical path is `~/Documents/nixconfig` (`frieren`: symlink to `/Volumes/data/projects/nixconfig`; a NAS client on other hosts — `readlink -f` it before trusting it, because where home-manager owns the path it is a read-only store copy whose `git rev-parse` reports the active generation, not your pull).
2. **Taskfile Control Plane — versioned source, imperative landing**:
   - `~/Taskfile.yml` is **not** hand-made: it is decrypted from the repo's encrypted `modules/secrets/DE-Taskfile.yaml` by `task infra:secrets:decrypt:detaskfile-home` (and as the second half of every `infra:rebuild:*`), so its source of truth is tracked. Landing it is still a task, not activation, so a host keeps a stale copy until that step runs — `scratch` exits **100** on `task` from `$HOME` for exactly that reason (no file).
   - The file must stay a pure forwarder: `include` the repo Taskfile flattened and define nothing else. A duplicate task name makes task reject the whole file (`Found multiple tasks (load-env)`, exit **203**) — measured on delphi 2026-10-29, and the reason frieren reported the same 203 from 2026-10-22. Setting `NIX_CONFIG` there is worse than useless: the var reaches the command environment and every `nix` call fails with "syntax error in configuration line".
   - Consequence: `task` from `$HOME` works only after the decrypt step has run on that host. Until it has, use `task -t ~/Documents/nixconfig/Taskfile.yml <cmd>` or run inside the clone, never `task -g`.
   - Making it declarative is open work — `AGENTS.nix` note `taskfile-plane-handmade`. Until then this is context, not an invariant.
3. **Agent Guidance & Skills Materialization**:
   - `~/.agents/` (`~/.agents/skills/`, `~/.agents/deploy/`, `~/.agents/README.md`) provides guidance and skill shards.
   - The canonical fleet operational manual is `AGENTS.md`. The local host system card + persona is the flake output `.#homeAgents.<host>` (`lib/home-agents.nix`), linked to `~/AGENTS.md` by activation; refresh manually with `task dev:inventory:home-agents`.
4. **Secrets & SOPS State**: two encrypted files, two identity planes, one CA —
   the state and its rekey procedure are [`docs/sops-rekey.md`](docs/sops-rekey.md).

---

## Architecture Overview

### Flake Output Assembly

```
flake.nix → flake/outputs.nix (the one assembly node)
  ├── nixosConfigurations  ← mkNixosHost (lib/mk-nixos-host.nix), inline
  ├── darwinConfigurations ← darwinSystem, inline
  ├── homeConfigurations   ← homeManagerConfiguration, inline
  ├── packages            ← flake/packages.nix
  ├── checks              ← flake/checks.nix
  ├── devShells           ← flake/devshells.nix
  ├── docs                ← lib/docs.nix (generated markdown tree)
  └── fleet-docs-site     ← lib/aki-site.nix (the rendered site)
```

**Host registration flow**:

1. One entry per host in `flake/host-inventory.nix`: defines `kind` (nixos/darwin/home), `system`, module chain, and host module path
2. `outputs.nix` projects inventory by `kind` — the kind picks the assembler, nothing is wired by hand
3. `flake/module-sets.nix` defines the 5 global module chains used as baselines

### Module Chains (defined in `flake/module-sets.nix`)

| Chain                            | What it includes                                                                       | Used by                                                                            |
| -------------------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `globalModulesNixos`             | global + nixos + home-manager-shared + sops + nix-index + dms + dank-greeter (desktop) | poseidon, aristotle, aceofspades, ancientace, eisen, frieren, scratch, stark, fern |
| `globalModulesImpermanence`      | globalModulesNixos + impermanence + disko                                              | schneeeule                                                                         |
| containers + impermanence (ares) | globalModulesContainers + impermanence + disko                                         | ares (Steam kiosk)                                                                 |
| `globalModulesContainers`        | global + noDE + sops + home-manager + nix-index (no dms/niri desktop)                  | mtfuji, kellerbench, applevalley, sledgehammer, guckloch (WSL), deckstation        |
| own chain (see `flake/host-inventory.nix`) | global + determinate-nix + sops + `raspberry-pi-3` — no noDE, so no Home Manager | minyx |
| `globalModulesMacos`             | global + macos + nix-homebrew + home-manager + sops                                    | cassini (darwin)                                                                   |
| `globalModulesDemo`              | global + demo + home-manager (no sops)                                                 | demo (NixOS demo VM)                                                               |
| `globalModulesHome`              | standalone HM sharedModules + allowUnfree                                              | penguin, alarm, kali (standalone home-manager)                                     |

### Complete Client OS Fleet Inventory

> **No table here — by design.** The fleet registry has exactly one home:
> [`inventory.toml`](inventory.toml), compiled once by `lib/inventory.nix`. Read it
> with `nix eval --json .#inventory.hosts | jq` (0.15 s, no host eval) or the catalog
> in `docs/generated/fleet-inventory.md` (`nix build .#artifacts.docs`). A pasted
> table disagrees with itself within a month — `.agents/SCHEMA.md` §1, `docs/docs-pipeline-audit.md` F4.

### Module Layout

```
modules/
  global/          — Global NixOS/Darwin/Home-Manager module chains
    user.nix       — Canonical user constants (user = devji, import this, not hardcode)
    global.nix     — Nix config: experimental features, substituters, GC
    nixos.nix      — NixOS HM embedded: overlays, home-manager-shared, role:home
    noDE.nix       — Container host HM: role:minimal + shell
    macos.nix      — Darwin HM: role:home
    impermanence.nix — Persistence rules for devji user
    demo.nix       — Demo HM: role:demo, no sops
    home-manager-shared.nix — sharedModules for embedded HM (sops, nixvim, nix-index, niri, dms)
  profiles/        — Reusable host profiles
    base-node.nix  — Common NixOS baseline (kernel, SSH, keyd, networkmanager, sops, user devji)
    boot.nix       — Boot loader profile (systemd-boot/EFI defaults)
    firewall-baseline.nix — Firewall on, only TCP/22 by default
    server-hardening.nix — Journald caps, tmp cleanup, /var bind-mount to data disk
    nas-client.nix — Automount /Volumes/data from the NAS server (frieren)
    burgernas-client.nix — Automount the BurgerNAS cold-vault export, with the fail-fast NFS options a sleeping peer needs
    steamos.nix — Steam kiosk (greetd autologin + upstream gamescope-session, audio, 32-bit GL, Avahi)
    sunshine.nix — GameStream/Moonlight server (Sunshine on LAN, video/render/input groups)
    nixbuild-client.nix — Optional nixbuild.net remote builder (distributedBuilds, off by default)
  services/        — Service modules
    aria2-daemon.nix  — aria2 RPC + AriaNg web UI via nginx (delegates to native services.aria2)
  roles/           — User role assemblers (minimal, home, demo)
  user/            — User module domains
    base/          — CLI/editor/env base
    ai/            — AI tools (aichat, antigravity-cli, codex, mods, opencode)
    desktop/       — Niri compositor integration
  shell/           — Shell baseline (`base.nix`: bash+tmux) on top of nu/starship/zsh
  config/          — Config data (authorized-keys, fetches.json, shells/*.nix)
    shells/        — Dev shell definitions (flaskpy, jekyll, yarn, pdf, yt, kali, pi, etc.)
  lib/             — Internal library functions
```

### Packages

Custom packages built from the flake:

- (none — the `pkgs/` directory and agent-era packages were removed in 2026-09/10; the `packages` output is `{}`)

---

## Essential Commands

### Taskfile Entrypoints

```bash
task help                        # List all tasks
task --list-all                  # Same, unfiltered
task status                      # git status + hostname
```

### Knowledge Graph & Notes Queries (AGENTS.nix & ops:kg)

```bash
# --- AGENTS.nix Queries (Decisions, Proposals, Open Todos) ---
# Do NOT read AGENTS.nix (3,500+ lines) directly into context.
task ops:notes:host HOST=<host>         # Notes affecting a host (e.g. eisen, frieren)
task ops:notes:show ID=<id>             # Inspect one note by ID (summary, refs, exit criteria)
task ops:notes KIND=open STATUS=OPEN    # List active open backlog across fleet
task ops:notes:module PATH=<path>       # Reverse lookup: which notes touch this module
task ops:notes:task TASK=<task>         # Reverse lookup: why does this task exist
task ops:notes:search Q="<phrase>"      # Fast substring search across all notes
nix eval --json .#agentsNotes.byHost.<h> | toon -e # Machine-readable note IDs for host (0.2s)
nix eval --json .#agentsNotes.open | toon -e      # All open note IDs (0.2s)

# --- Knowledge Graph Queries (Hosts x Skills x Docs) ---
# Do NOT raw-grep for structural relationships. Query the compiled graph.
task ops:kg                             # Graph summary stats & highest-degree hub nodes
task ops:kg:host HOST=<host>            # Inbound edges: skills and docs touching this host
task ops:kg:skill SKILL=<name>          # Inbound mentions + skill tags
task ops:kg:doc DOC=<path>              # Reverse lookup: hosts & skills documented in file
task ops:kg:blast TARGET=<id>           # Blast radius: transitive dependents before breaking edits
task ops:kg:comention HOST=<h> MIN=2    # Multi-hop co-mentioned hosts sharing docs
task ops:ask Q="what touches <host>"    # Natural language query routed to graph
```

### Host Lifecycle

```bash
task infra:plan:host:<host>      # Build/evaluate host closure (dry run)
task infra:apply:host:<host>     # Apply configuration to remote host
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:rollback:host:<host>  # Roll back to previous generation
task infra:logs:host:<host>      # View remote journald logs
```

### Local Rebuilds

```bash
task infra:rebuild:nixos         # switch IS the build; no pre-flight checks (NOM=1 for TUI)
task infra:rebuild:darwin        # darwin-rebuild switch (local) + refresh ~/Taskfile.yml
task infra:rebuild:home-manager  # home-manager switch (local) + refresh ~/Taskfile.yml
```

### Client OS Maintenance & Debugging Runbooks

#### 1. Dry Run & Evaluation

Before deploying changes to any client OS, evaluate its configuration:

```bash
task infra:plan:host:<host>   # substitute the closure, apply nothing
```

That is the pre-build instrument. A toplevel `.drvPath` eval instantiates the
whole graph (>120 s, CI-only) and a switch forces it anyway — Agent Verification
Protocol below. `.config.networking.hostName` proves nothing at all.

#### 2. Deploying Remote Hosts

The same two tasks as Host Lifecycle above: `infra:deploy:*` = gate → plan →
apply → validate, `infra:apply:*` applies an already-planned closure.

#### 3. Remote Log & Service Inspection

Diagnose failing units or check live output:

```bash
task infra:logs:host:<host> UNIT=<unit>   # Tail journald for UNIT (defaults to go-backend)
ssh <host> systemctl status <unit>        # Inspect unit status on remote host
ssh <host> journalctl -b -p err           # View system errors from current boot
```

#### 4. Rollback Runbook

If a deployment degrades a host:

```bash
task infra:rollback:host:<host>           # Roll back remote host generation
# For local recovery:
sudo nixos-rebuild --rollback switch      # Local NixOS rollback
```

#### 5. NAS Client Automount Recovery (fern & clients)

If `/Volumes/data` fails to mount due to early-boot network timing (causing `StartLimitBurst` hit):

```bash
nas-recover                               # Canonical recovery tool
# Or manually restart the automount unit:
sudo systemctl restart Volumes-data.automount
```

#### 6. SOPS Secrets & Key Verification

Verify decryption across all hosts and rotate recipient keys:

```bash
scripts/task/sops-drift-check.sh          # Verify all encrypted files decrypt cleanly
task infra:sops:update-keys               # Rekey all files when .sops.yaml changes
```

#### 7. frieren (NAS) Rebuild Topology

Host-specific procedure lives in
[`.agents/deploy/hosts/frieren.md`](.agents/deploy/hosts/frieren.md#rebuild-topology-read-before-rebuilding-this-host):
the nightly window, the origin-vs-local trap, one rebuild at a time, and how to
tell load from deadlock.

### frieren: wiki stack, cache-warm, hermes, SSH CA

Also in that runbook: kiwix is declarative, uncached fleet builds go through
`task infra:update:fleet`, never run `hermes gateway install` there, and every
host can sign certs.

### Git & Flake

```bash
task dev:git:quick-push          # Stage tracked, AI-commit, push
task dev:git:ai-commit           # Stage + interactive AI commit
task dev:git:ai-commit-push      # Stage + AI commit + push
task dev:git:build-push          # AI commit after successful build
task dev:git:quick-pull          # Pull with submodules
task dev:flake:update-complete   # Full flake update workflow
task dev:flake:update:bountystash # Update single input
task dev:flake:update-transitive # Update transitive inputs a root update misses
task dev:nixbuild:plan           # Report build/fetch gaps per host vs substituters
task dev:nixbuild:warm           # Build gaps on remote builder + cachix push (budget!)
task dev:closure:menu            # Traversable closure explorer (gum TUI; subcommand after --)
task dev:closure:reduce          # Closure reduction report: duplicate groups + every concrete copy
task dev:closure:attribution     # Attribute closure bytes to owners (services, package farms)
task dev:qmd:refresh             # (Re)index markdown docs (repo docs + personal vault) into qmd
task dev:qmd:vault:refresh       # (Re)index personal Obsidian vault into qmd
```

### Data & Storage Lifecycle

```bash
task data:audit                  # Audit NAS storage taxonomy, permissions, media hygiene
task data:clean:metadata         # Scan and remove macOS metadata artifacts (._*, .DS_Store)
task data:clean:downloads        # Cleanup orphaned control files and empty staging dirs
task data:protect:private        # Enforce 0700 permissions and .nomedia shields
task data:index:refresh          # Refresh qmd docs and vault search indices
```

### Closure Analysis (store-DB, no eval)

Cheap "what is actually in this system" analysis: it reads the store database via
`nix path-info` instead of evaluating Nix — the fix for `checks:quick` having
stopped being quick. Targets the local `/run/current-system` by default,
`HOST=<name>` (SSH-resolves a remote host and reads *its* store DB), or an
explicit store path.

```bash
task dev:closure:size HOST=<name>          # total size + path count
task dev:closure HOST=<name>               # subsystem breakdown
task dev:closure:top N=20 HOST=<name>      # biggest contributors by own size
task dev:closure:graph HOST=<name>         # terminal ASCII graph (Graphviz -> graph-easy)
task dev:closure:toml HOST=<name> OUT=...  # 3-level tree for handoff / agent reports
task dev:closure:tui                       # interactive host + view picker
task dev:closure:diff FROM=<old> TO=<new>  # closure deltas (module-reduction scoreboard)
task dev:closure:native                    # same breakdown, computed natively by Nix (prototype)
task dev:closure:native:diff               # [gate] Nix-native output == shell output, byte-for-byte
```

Backed by `scripts/task/closure-analysis.sh`. Generated report trees are **not
tracked** (`docs/closures/` is gitignored) — they are point-in-time and stale
after any rebuild. Regenerate on demand; use `dev:closure:diff` to compare
generations.

**Nix-native prototype.** `lib/closure-graph.nix` computes the same five views
from Nix's own store graph (`pkgs.closureInfo` → `exportReferencesGraph`) instead
of the store DB, and `scripts/task/closure-graph-diff.sh` proves parity — on
frieren all five views are byte-identical for a 3949-path system closure, an
older generation, and a 141-path package closure. Two things to know if you
touch it:

- `closureInfo` needs its roots *declared*. `builtins.storePath "/nix/store/…"`
  for a live path, or a derivation attribute; a bare `/run/current-system`
  symlink is not in the input closure and `exportReferencesGraph` refuses it.
- It is **local-store only** (no `HOST=<name>`): `closureInfo` builds locally.

Rationale and the eval-speed trade-off: `docs/control-plane-vision.md` §4/§6.

### Validation

```bash
task checks:quick                # Bounded: cheap inventory checks, one host eval each, lint
task checks:host:HOST=<host>     # [gate] ONE host (name required): module system + assertions + registry
task checks:hosts:HOSTS="a b"    # [gate] a NAMED set, one at a time — no default, never the fleet
task checks:flake                # [gate] run `nix flake check` only on a machine that can hold it
task checks:flake:transitive     # Sweep transitive flake pins vs upstream (read-only)
task checks:qmd:docs             # qmd repo-docs collection registered + index fresh
task checks:qmd:vault            # qmd Obsidian vault collection registered + index fresh
nix build .#hostChecks.x86_64-linux.<host> -L                     # ONE host gate (~13 s, ~700 MiB)
nix eval .#inventory.hosts.<host>.role                            # Compiled registry (0.15 s, no host eval)
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath  # full-config check, ONE host
#   ^ this one instantiates the whole system derivation graph (>120 s here, and the
#     reason the old fleet-wide host-eval checks were fatal). ONE host per invocation.
task checks:nix:lint             # deadnix (fail) + statix (advisory)
```

#### HARD RULE [[flake/policies.nix#flake-check-memory-gated]]: no `nix flake check` on a small host

It evaluates **every flake output** in one process — 23 NixOS configs, measured
2026-10-15 at 339.78 s / 6078.5 MiB / SIGKILL 137 on this 11 GiB host, which then
sat at 62 % IO-stall with 5.4 GiB swapped. `task checks:flake` refuses below
16384 MiB. Check **one** host (`checks:host HOST=`, 13 s / 720 MiB)
[[flake/policies.nix#no-fleet-default]] or a named set under the watchdog
[[flake/policies.nix#sweeps-under-watchdog]]; `MODE=eval` checks an
aarch64/darwin host from here. The fleet is CI's job.

`scripts/task/oom-guard.sh` is what makes a sweep safe: it polls `oom_kill`,
memory/io PSI and `MemAvailable` every 10 s over the whole **process group**
(a 4.9 MiB direct-child peak hid a 6 GiB grandchild) and kills the run on
pressure instead of taking the host down.

#### Agent Verification Protocol (compute discipline)

Verification is **phased, and each phase has exactly one job.** Confusing the
phases is what produces both failure modes at once: cheap per-option evals run as
ritual (proving nothing) while the build that would have caught the error is
never run.

**Phase 1 — Pre-build: one bounded gate, not a toplevel force.**
`nix eval .#nixosConfigurations.<host>.config.networking.hostName` proves nothing
(one option, no type checking). `nix build .#hostChecks.<system>.<host>` runs the
module system and every assertion — 13.16 s / 720 MiB on frieren — and is the
normal pre-build gate.

The whole-toplevel force (`…toplevel.drvPath`) instantiates the entire derivation
graph: **>120 s with swap on frieren**, O(hosts) in memory. It is a **CI / operator
instrument**, never a per-edit or pre-rebuild step. `nixos-rebuild switch` forces
the same graph, so a `.drvPath` eval first is duplicate work for no extra proof.
On a local rebuild, run **no** check first — the switch is the check.

- **Cheaper first.** `hostChecks` catches the option-conflict / bad-value / policy
  class without instantiating the closure. Reach for `.drvPath` only when the
  change is derivation-level wiring and CI cannot cover it.
- **Budget it, and run it under the guard.**
  `bash scripts/task/oom-guard.sh --timeout 180 -- nix eval --raw …` kills the run on
  10 s OOM/PSI polling instead of dragging the host into swap death. Use
  `--timeout 3` for the leaf registry reads (`.#inventory.*`), which cost 0.15 s.
  The guard samples a **baseline** before the command starts and aborts only above
  `max(threshold, baseline + 5)`: on a host already saturated by unrelated work
  (frieren, io full avg10 44-61 %) an absolute threshold aborted a 1.1 s run, which
  makes the gate unrunnable rather than protective. Its result line prints the
  baseline, so "peak" is never confused with "this command caused it".
- **Preserved hosts are not check targets.** `status = "preserved"` is dormant,
  and some are *known-broken* (cassini's `homeDirectory` conflict predates this
  tree). `warm-host.sh --check`, `infra:deploy:*` and `infra:apply:*` warn and
  exit 0 **before any eval, cache query, ssh or validate** — a dormant failure
  is not this run's regression. Revive with `ALLOW_PRESERVED=1`; never sweep
  preserved hosts into a fleet check.
- **Scope to what the change reaches, never the fleet:** host-local edit → that
  host; chain module (`modules/global/*`, `modules/profiles/*`, `modules/roles/*`)
  → one representative host per chain affected; `flake/` wiring → one host per
  kind (nixos, darwin, home) — **active** hosts only.
- **Batch into ONE bash loop**, not one tool call per host.
- **A whole-system sweep is for wiring changes, not a habit.** Eval a whole system
  sparingly; eval the closure you changed often.
- **Keyless environments (fresh clones, sandboxes).** Evaluation needs no sops
  keys — sops-nix only declares paths. Safe: `nix eval`, `alejandra --check`,
  `deadnix`, `statix check`. Not keyless: `checks:quick` (sops drift), `infra:*`
  secret tasks. Stock Nix also needs the `pipe-operators` flag (see below).

**Phase 2 — Build: the build IS the test.** Once a change alters the closure,
evaluation is no longer evidence. Build it — never on the target host:

```bash
task infra:warm:host:<host>      # build on the builder; verify the cache serves it
task infra:deploy:host:<host>    # ONE intended host: gate → plan → apply → validate
# checks:build:route is CI/operator-only: it forces the toplevel. Do not chain
# it in front of a rebuild; invoke it deliberately when routing is in doubt.
```

Fleet-wide building is a **schedule**, not an ad-hoc action (`fleet-warm-cache`
runs weekly on `frieren`). A host that is needed now is deployed out of schedule
with `infra:deploy:host:<host>` — one intended host, never the fleet.

**Phase 3 — Size/shape analysis is build preparation, not verification.**
`dev:closure:top`, `dev:closure:size`, `dev:closure:reduce` answer *"what is big,
what will be fetched, what is duplicated"* — questions you ask to decide **how** to
build. They read the store DB and verify nothing. Use them before a build; never
in place of one.

> **eval to catch a config error · build to prove a closure · size to plan a
> build.** Never build without cause — but never mistake an eval for one.

**A check must not be able to spend build budget.** `frieren` configures
`eu.nixbuild.net` as a distributed builder (`/etc/nix/machines`), and nixbuild.net
bills **per build-second** against a 25 h/month free tier — so any `nix build`
that reaches a missing derivation spends money, wherever it is run from. Two
rules follow:

- **Never call `nix build` in a check/gate path.** `nix build --dry-run` does not
  build, but it is one edit away from not being a dry run — on 2026-10-15 a
  `--check` that used `nix build --print-out-paths` dispatched full closures (incl.
  stark's NVIDIA closure) to the remote builder and consumed the month's budget.
  Prefer `nix eval --raw "<attr>.outPath"` (forces the path, builds nothing) plus
  `nix path-info --store <cache> <path>` (asks the cache).
- **If a check must shell out to nix build, pass `--builders ""`** so it cannot
  dispatch even if the dry-run flag is lost. `scripts/task/warm-host.sh` does this
  in `pending_count()` and so does `checks:host` (its default flags are
  `--builders ""`, so the gate can compile its own three-line artifact and still
  never reach nixbuild).

Budget is spent deliberately, by `task dev:nixbuild:warm` — never as a side effect
of looking.

**What offloading a check can and cannot buy.** Measure before adding a flag,
because the answer is not intuitive and it was measured on frieren 2026-10-20:

```
task checks:host HOST=fern            10.56 s   958 MiB   local compile, no builders
offloaded (OFFLOAD=1)                12.68 s   746 MiB   remote build itself: 746 ms
```

**nixbuild.net runs derivations; it does not evaluate.** The host gate's cost is
the module system + 1961 assertions, i.e. a local `nix eval`; the derivation it
finally builds is a three-line `runCommand` that echoes a summary. So sending
that derivation to the builder saves ~0.7 s of a 10.6 s gate and recovers
nothing of the 958 MiB. The same asymmetry holds one level up: `task
infra:warm:host:<host>` offloads a closure's **compilation**, while its
evaluation stays local.

- **Cannot be offloaded:** evaluation, assertions, `MODE=eval`, `checks:flake` —
  the memory and CPU they cost are yours. Bound them (one host per process, under
  `oom-guard.sh`) and keep them out of the nightly window.
- **Can be offloaded:** closure builds (`dev:nixbuild:warm`, `infra:deploy`
  warming) and — the only real offload for evaluation — **the whole gate to CI**,
  where each host gets its own runner: `task dev:ci:trigger:<host>` builds
  `nixosConfigurations.<host>` **and** `hostChecks.<arch>.<host>` and pushes both
  to cachix. A host whose artifacts are there needs no local gate at all.
- **`checks:host`'s three routing flags**, one question each: default
  `--builders ""` (compile here, never spend budget) · `STRICT=1`
  (`--max-jobs 0 --builders ""`, substitute-or-fail: "is this host warmed?") ·
  `OFFLOAD=1` (`--max-jobs 0` + `/etc/nix/machines`: dispatch deliberately).

**Never put ssh in an unattended path.** A pre-switch hook that opens ssh can
block on an interactive auth prompt: Tailscale SSH added a browser check on `fern`
and silently hung an unattended run for 5 minutes. Use the LAN address
(`TARGET=user@<lan-ip>`) or, better, ask a question the binary cache can answer
over plain HTTP with a timeout (`scripts/task/warm-host.sh` does exactly this).

**When a build IS needed, never run it *on* the target host — warm it
elsewhere first.** A `nixos-rebuild build --flake .#<host>` executed on a
   lightweight host saturates it (measured: load ~9.4 on fern's 2c/4t, killed
   after 30 min), while the same closure built on a CI runner and pushed to
   cachix took **6m53s** and left the host a substitution-only rebuild. The
   constraint is already declared per host in `inventory.toml`
   (`compute_tier`, `allowed_tasks`) — e.g. fern: *"15W dual-core processor and
   8GB RAM; avoid heavy compilation loops"*. Burn CPU on builders, not on the
   machine that asked for the config.
   - **Preferred — CI** (free, already wired, maps host→runner arch from
     `inventory.toml` and pushes to the `shaoyanji` cache):
     `task dev:ci:trigger:<host>` (= `gh workflow run nixcachix.yml -f host=<host>`).
   - **Or the remote builder** (nixbuild.net free tier = 25 build-hours/month,
     so budget it): `task dev:nixbuild:plan` to report the gaps, then
     `task dev:nixbuild:warm` (builds with `--max-jobs 0`, pushing to cachix).
   - **Verify the warm landed** before touching the host:
     `task checks:build:route` must report READY (it asks the cache directly,
     over HTTP, with no ssh) — `task dev:nixbuild:plan` is the nixbuild.net view.
   - This is `exp-107`/`exp-113` in `AGENTS.nix`; the enforcement gate is
     `task checks:build:route`, implemented by `scripts/task/warm-host.sh`.

````
### Secrets & SOPS

```bash
task infra:secrets:edit:secrets  # Edit sops secrets file
task infra:secrets:edit:apikeys  # Edit API keys env file
task infra:secrets:edit:taskfile # Edit encrypted Taskfile
task infra:sops:get:*            # Query a secret value
task infra:sops:fzf              # Select env entries interactively
task infra:sops:update-keys      # Rotate SOPS recipient keys
````

### SMTP Auth

```bash
task infra:smtp:auth             # Interactive SMTP auth for hosts (using app passwords)
# Prompts for: host, username, app-password; outputs MSMTP/MUTT config for the host
```

### Site (`docs-site/` retired 2026-10-19; the site is `.#sites.fleet-docs-site`)

Nix-native `lib/aki-site.nix` served by frieren, nav from the knowledge graph
(`docs/docs-pipeline-audit.md`); the publisher site (`dev:site:*`) is separate.

```bash
task docs:build   # markdown tree (nix build .#artifacts.docs)   ·   task docs:site   # rendered site
```

### TOTP (cloak)

```bash
task dev:cloak:view              # Pick TOTP from list (gum filter)
task dev:cloak:view:github       # Direct by name
task dev:cloak:edit              # Edit TOTP accounts file
task dev:cloak:sync-bw -- ./export.json  # Import from Bitwarden export
```

### Operator Helpers

```bash
task agents:menu                 # Interactive operator control plane
```

### Nix Raw Commands

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel          # Build host closure
nix build .?submodules=1#nixosConfigurations.<host>.config.system.build.toplevel  # With submodules (CI)
nix build .#hostChecks.x86_64-linux.frieren                                  # ONE host eval gate (~700 MiB)
bash scripts/task/oom-guard.sh --timeout 3 -- nix eval --raw .#inventory.hosts.fern.role  # leaf read, no host eval
nix build .#devShells.x86_64-linux.default                                   # Enter dev shell
alejandra <file>                                                             # Format Nix file
alejandra --check <file>                                                     # Check formatting
```

---

## Storage

`/srv/data` on frieren → `/Volumes/data`: [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md)
[[flake/policies.nix#media-tree-isolation]] [[flake/policies.nix#library-content-is-not-scheduled]]

**Portable tool library** (`bin-*`, `appimages`) is what NON-Nix machines execute, so
linkage is the contract, not size: `eget` hangs on its asset picker without `--asset`,
a fetch is static-only [[flake/policies.nix#library-fetch-is-static]], and the tree
mirrors to BurgerNAS [[flake/policies.nix#library-crosses-the-wire]] (`task data:library`).

---

## Secrets

Sops planes, files, CA, rekey: [`docs/sops-rekey.md`](docs/sops-rekey.md)
[[flake/policies.nix#secrets-are-encrypted]]
[[flake/policies.nix#ca-only-user-access]]

---

## CI

Inventory-driven, no matrix: [`docs/ci-pipeline.md`](docs/ci-pipeline.md)
[[flake/policies.nix#ci-matrix-is-inventory]]

---

## Nix gotchas

Traps, patterns, agent failure modes: [`docs/nix-patterns.md`](docs/nix-patterns.md)

HARD RULE [[flake/policies.nix#toml-through-a-tool]]: TOML through a format-aware
tool; `yq -i -f script.yq` applies nothing, so verify the compiled result.

---

## Adding a New Host

1. Create host module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix` for simple cases)
2. Add hardware/storage as needed (e.g., `hardware-configuration.nix`, `disko.nix`, or profile imports)
3. Register in `flake/host-inventory.nix` with:
   - `kind` (`nixos`, `darwin`, or `home`)
   - `system` (e.g., `"x86_64-linux"`)
   - Module chain (`globalModulesNixos`, `globalModulesImpermanence`, `globalModulesContainers`, etc.)
   - Host module path(s)
   - `specialArgs` or `extraSpecialArgs` as needed
4. Output assembly is automatic via the `kind` projection in `flake/outputs.nix`
5. Build: `task infra:plan:host:<name>` or `nix build .#nixosConfigurations.<name>.config.system.build.toplevel`

For provisioning a new server:

- The host's age key (from `ssh_host_ed25519_key`) must already be in `.sops.yaml` for `hashedPassword` decryption
- `ssh.ca.enable = true` is inherited from `base-node.nix`
- SSH in using a cert from your workstation

---

## Task Namespace Summary

See [Task Control Plane](docs/task-control-plane.md) for full namespace definitions and workflow examples.

| Namespace       | What                                                                                                         | Skill                                  |
| --------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| `infra:*`       | Host lifecycle, secrets, SOPS, detached jobs (`infra:job:*`), microVM guests (`microvm:*` declarative, `vm:canary:*` runner) | `.agents/skills/infra/SKILL.md`, `.agents/skills/microvm/SKILL.md` |
| `agents:*`      | Operator menu, xs, OAuth                                                                                     | `.agents/skills/agents/SKILL.md`       |
| `checks:*`      | Validation, smoke checks, nix lint                                                                           | `.agents/skills/checks/SKILL.md`       |
| `dev:*`         | Git, flake, site, PRs, packages                                                                              | `.agents/skills/dev/SKILL.md`          |
| `data:*`        | NAS storage taxonomy, hygiene, permissions, media unindexing                                                 | `.agents/skills/data/SKILL.md`         |
| `moto:*`        | Motorola Android (Termux) shell, file push/pull, Wish/Gum menu                                               | `.agents/skills/moto/SKILL.md`         |
| `serv00:*`      | Serv00 FreeBSD hosting, Devil CLI, webserver lifecycle                                                       | `.agents/skills/serv00/SKILL.md`       |
| `dragoncourt:*` | Alwaysdata Debian hosting, PHP/Wasm webserver                                                                | `.agents/skills/dragoncourt/SKILL.md`  |
| `envs:*`        | Envs.net Debian hosting, public_html / Gemini / Gopher, build pipeline                                       | `.agents/skills/envs/SKILL.md`         |
| `bountystash:*` | Bountystash Console (<14KB TCP budget), preview & Cloudflare Pages deployment                                | `.agents/skills/bountystash/SKILL.md`  |
| `apps:*`        | Job application workflow (appflow): status updates, email flow, sync, builds                                 | `.agents/skills/apps/SKILL.md`         |
| `services:*`    | Legacy wrappers (canonical: `infra:*`)                                                                       | `.agents/skills/services/SKILL.md`     |
| `google-drive`  | Google Drive OAuth setup, rclone, tailscale funnel                                                           | `.agents/skills/google-drive/SKILL.md` |
| `antigravity`   | Delegate coding to Antigravity CLI (Google's agent) with `--dangerously-skip-permissions` and `--jsonschema` | `.agents/skills/antigravity/SKILL.md`  |
| `crush`         | Delegate coding to Crush CLI (Charm's agent) with `--yolo` and structured output                             | `.agents/skills/crush/SKILL.md`        |

---## Taskfile as the Agent Contract

`task --list-all --json` is the discovery API (`desc`, `summary`, aliases): `summary`
carries the variable/exit-code contract, `internal: true` is banned (it hides the task
from JSON), and wildcards are not invocable — call the concrete name. The graph is
compiled (`lib/taskfile.nix`), so `checks:tasks` asserts it *and* its parity with
`task --list-all --json`. Authoring: `docs/task-control-plane.md`, `task-plane` skill,
observation tasks → `taskfiles/ops.yml`.

## Memory hierarchy (jev decides escalation)

| Layer              | Role                                          | When used                                      |
| ------------------ | --------------------------------------------- | ---------------------------------------------- |
| MEMORY.md          | Boot — persists across sessions               | Always loaded                                  |
| Vault              | Fast working memory — offline, personal       | First stop for context                         |
| qmd wiki           | Resource — docs, runbooks, codebase           | Concept/location queries                       |
| mem0 / supermemory | Deep consult — when vault + wiki insufficient | Decided by jev (min-prob 0.8, min-margin 0.15) |

Search order: vault → wiki (qmd BM25) → graph (`task ops:kg:*`) → mem0/supermemory (jev-decided) → web. Skills: `qmd search "<topic>" -c skills --format json`.

---

## qmd Search Operations

Local hybrid search over markdown docs and notes via `qmd` (`pkgs.llm-agents.qmd`;
where it is not on PATH — `delphi`, measured 2026-10-30 — the tasks resolve the
`flake.lock` pin themselves via `scripts/task/qmd-docs-index.sh`, and the `qmd`
skill carries the bare-`qmd` one-liner). Three canonical collections:

| Collection  | Target Path                                              | Content                                                                                 |
| ----------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `nixconfig` | `/srv/data/projects/nixconfig` (`~/Documents/nixconfig`) | This repo's documentation: README, AGENTS.md, runbooks, `docs/*`, `taskfiles/README.md` |
| `vault`     | `~/vaults/personal` (NAS link → `/Volumes/data/Obsidian-Git-Sync`; a `cloud` host gets a git checkout of the same repo) | Personal Obsidian vault: zettels, schematics, notes |
| `skills`    | `~/.hermes/skills/`                                      | Agent skills indexed for BM25 search                                                    |

### Index lifecycle

```bash
task dev:qmd:refresh             # Register (if missing) and reindex both collections
task dev:qmd:vault:refresh       # Reindex the Obsidian vault only
task dev:qmd:docs:refresh        # Reindex nixconfig docs only
task checks:qmd:docs             # Verify nixconfig collection registered + index fresh
task checks:qmd:vault            # Verify vault collection registered + index fresh
```

The `checks:qmd:*` tasks exit 1 when a collection is missing or any `.md` file is newer than the index; run them after doc edits.

### Querying

```bash
qmd search "impermanence disko" -c nixconfig   # repo docs only
qmd search "zettel topic" -c vault             # vault only
qmd search "query"                             # all collections
qmd search "query" --json | toon -e                      # agent-friendly output
qmd get "#docid"                               # fetch a full document from search results
qmd status                                     # index health and file counts
qmd update                                     # incremental reindex (fast, BM25)
```

Prefer BM25 `qmd search` (instant); `qmd embed` (semantic vectors) is optional and slower. Prefer qmd over raw `grep` when locating concepts or runbooks across repo docs and the vault — it is ranked and collection-scoped.

The `nixconfig` collection masks `**/*.{nix,md}`, so a `nix eval`-time comment and
the page that explains it are one query apart — which is why a `.nix` header no
longer has to carry the essay. Vector-embedding offload to Eisen:
[`docs/qmd-embedding-offload.md`](docs/qmd-embedding-offload.md).

**Structural queries are the graph, not `grep`.** `.#knowledgeGraph` compiles hosts × skills × docs, with three edge kinds: `mentions` (a doc's tokens name a host or skill), `references` (a doc's markdown links point at another doc — the layer that makes it a lattice, `ops:kg:doc` answers with it) and `tagged` (skill → tag); `task ops:kg:*` are the six fixed traversals for "what touches X". The Elixir sidecar is the DEFAULT path: `kg-query.sh` answers from its socket when live (32 ms vs 441 ms for the same question through jq on this tree; `task ops:kg:speed` re-measures both), falls back to jq byte-identically, and `checks:kg:sidecar` proves both agree — it starts at login (`programs.kgSidecar`) from the COMPILED graph. `--native` is the parity experiment (`checks:kg:native`, part of `checks:quick`), not the query path; `ops:kg:blast` is the reverse closure that jq has no one-liner for.

---

## Key Operator Helpers

- `agents:menu` is the interactive operator control plane
- `task menu` is the whole-Taskfile gum TUI; `menu:list` / `menu:json` are its
  machine surfaces. A task is never `internal: true`
  [[flake/policies.nix#task-surface-visible]] — that breaks the agent endpoint.
- NAS client recovery logic lives under `modules/profiles/nas-client.nix`

## Deployment Guidance

Host deployment flows use `infra:*` tasks directly. See `.agents/deploy/README.md` for host-specific deployment notes. Per-host quirks live in `.agents/deploy/hosts/*.md` — a host is not only its own config: delphi runs the service-tier `sandbox` microVM (`hosts/microvms/guests.nix`) behind `/microvm/*` and the terminal deck, where `ssh slides@delphi.bountystash.com` is the deck, `task microvm:ssh NAME=sandbox` (from delphi) is the guest shell, and plain `ssh delphi.bountystash.com` is the host shell as `devji`; frieren's `frieren-canary` guest is proved end to end by `task vm:canary:test` (boot → ssh → guest API → host proxy → stop → teardown). Guest mechanics: `hosts/microvms/README.md`.

## Git Hooks Setup

Pre-commit hooks in `.githooks/` run deadnix (hard gate), statix (advisory), and a formatting check accepting either alejandra or nixpkgs-fmt (hard gate). Tools missing from PATH are fetched via nix from the nixpkgs revision pinned in `flake.lock`, so the checks are machine-independent. Enable with:

```bash
bash .git-hooks-setup.sh    # sets core.hooksPath to .githooks/
```

## Nixpkgs Formatting

**alejandra is the canonical formatter** — every tracked `.nix` file is
aljandra-clean, and `dev:fmt`, `checks:nix:fix` and the pre-commit hook all run
it. The hook is a thin wrapper over `scripts/task/nix-fmt.sh`, so it uses the same
versions and the same cache as the tasks and no longer accepts `nixpkgs-fmt`.
**Never run `nixpkgs-fmt` repo-wide — it would rewrite ~170 of 187 files**, and it
is no longer installed: `base-node.nix` ships `alejandra`, `deadnix` and `statix`
instead, which also lets `nix-fmt.sh` take its PATH branch and skip the first-run
`nix build`. `task checks:nix:lint` is the deadnix/statix pass, not a formatter
check.

`scripts/task/nix-fmt.sh` is the **single implementation** behind every Nix
format/lint path, so the watcher can never use different tool versions than the
gate that judges the commit:

| Task | What |
| :--- | :--- |
| `task checks:nix:fix` | one-shot fix — the hard gates (deadnix + alejandra), all paths |
| `task dev:fmt` | alias of `checks:nix:fix` |
| `task checks:nix:lint` | **read-only gate** — deadnix (fails) + statix (advisory) |
| `task checks:nix:format` | **read-only gate** — `alejandra --check` |
| `task checks:nix:watch` | **the watch hook** — auto-formats on every save |
| `task checks:toml:lint` | every tracked `.toml` parses (the `yq` rule's guard) |

The script takes `--tools LIST` (a comma-separated subset of
`deadnix,statix,alejandra`), which is how the read-only gates keep their exact
tool sets — `checks:nix:lint` is deadnix+statix and `checks:nix:format` is
aljandra — **without** introducing a second place that resolves tool versions.
Add a new Nix tool task by passing `--tools`, never by calling
`nix-shell -p alejandra` (or deadnix/statix) directly.

The default tool set is the **hard gates, `deadnix` and `alejandra`** — the ones
that make the commit fail. statix is advisory and never auto-applied
[[flake/policies.nix#statix-advisory]] — its W20 warning fires on the house style,
so `checks:nix:lint` only *reports* it. To write its suggestions deliberately,
pass it by name:
`bash scripts/task/nix-fmt.sh --fix --all --tools deadnix,statix,alejandra`.

The toolchain resolves from the **nixpkgs revision pinned in `flake.lock`** — the
same versions `.githooks/pre-commit` uses — and is cached as GC-rooted out-links
under `~/.cache/nixconfig-nixfmt/`, so a save costs ~70 ms instead of re-resolving
a shell. The pin is re-resolved when `flake.lock` changes.

**Auto-format hook (no manual tool calls).** Start it once and leave it:

```bash
task checks:nix:watch
```

It watches `**/*.nix` via task's `watch` flag and formats only the files git
reports as dirty, so a save touches one file. It writes only when a file actually
changes — deadnix/statix/alejandra are idempotent (verified) — so it cannot
re-trigger itself into a loop. Verified end to end: a misformatted file is fixed
in under 1 s, and a pure indentation change is restored byte-identical.

One caveat it reports rather than hides: **deadnix will not strip the last lambda
argument**, so `{pkgs}: …` with an unused `pkgs` stays flagged. `--fix` re-verifies
after writing and exits non-zero on residue the tools cannot rewrite, instead of
claiming success on a tree the commit gate would still reject.

#### Operating the watcher (read this before backgrounding it)

| | |
| :--- | :--- |
| Start | `task checks:nix:watch` |
| Status | `task checks:nix:watch:status` — pid + elapsed, or "not running" |
| Stop | **`task checks:nix:watch:stop`** — signals the watcher by pid and verifies it exited (or Ctrl+C in the foreground) |
| Watch interval | `interval: '500ms'` at the root of `Taskfile.yml` — coalesces a multi-file save into one run (task's default is 100ms and duplicate events were observed) |

Three behaviours that bit us, all confirmed against
[task's watch docs](https://taskfile.dev/docs/guide/watch):

- **Stopping it is not "kill the shell that started it".** Watch mode is known to
  leave children running, and the watcher is a *grandchild* of whatever launched
  it — killing the launching shell left a live `task checks:nix:watch` formatting
  the repo for ~8 minutes, and it looked stopped because the parent PID was gone.
  Use `task checks:nix:watch:stop`: it matches the watcher cmdline exactly (so it
  can never signal the shell that launched it, or its own shell), signals it,
  waits, and **verifies** it is gone rather than assuming the signal landed. If
  you must do it by hand, `pkill -x task` then check `pgrep -x task`.
- **A task's `cmds` run in task's own restricted shell, not bash.** `kill` is an
  "unsupported builtin" there and silently does nothing — the stop task looked
  like it succeeded while the watcher kept running. Any builtin that is not plain
  POSIX may be missing, so drop to a real shell for it:
  `bash -c 'kill "$1"' _ "$pid"`.
- **`--dry` does not suppress `watch: true`.** `task --dry checks:nix:watch` starts
  a real watcher and blocks; it timed out a probe here. There is no dry run for a
  watch task.
- **`watch: true` only applies to CLI invocations.** Called from another task's
  `cmds`/`deps` it does *not* start a watcher, so it cannot be pulled in as a
  dependency and quietly hang a pipeline.

`sources` drives both change detection *and* the up-to-date check. This task has
no `generates`, so it re-runs on every change — correct for a formatter, and it
writes nothing when there is nothing to change, which is what keeps it stable.

## External Package Registry

External fetched dependencies are registered in `modules/config/fetches.json` and resolved through `lib/fetches-extra.nix`. Update hashes with:

```bash
task dev:config:hash-update    # runs nix-hash-update.sh
```

## Documentation & Site Compilation

Documentation is markdown or data that Nix compiles into a store path; the store
path is the artifact. Nothing derived is committed, and no second renderer is
allowed beside the first.

| Layer | Owner | Rule |
| :--- | :--- | :--- |
| content | `*.md`, `AGENTS.nix`, `inventory.toml`, `modules.toml` | hand-written only, never generated |
| projection | `lib/inventory.nix`, `lib/docs.nix`, `lib/knowledge-graph.nix`, `lib/skills.nix` | one pure Nix compiler per projection |
| artifact | `.#artifacts.docs` (generated markdown), `.#sites.fleet-docs-site` (the rendered site) | store paths, never repo copies |
| serving | `hosts/frieren/reverse-proxy.nix`, `modules/services/uds-static-bridge.nix` | serve the path; never re-derive content in a host module |

- **Never commit a derivative** [[flake/policies.nix#generated-not-tracked]]:
  `docs/generated/` is `nix build .#artifacts.docs`, and a committed copy is a second
  source of truth. The path is gitignored so a copy cannot return; with no drift gate
  to maintain, build output is never duplicated.
- **Content is not code.** CSS/JS/HTML go in files the derivation reads, not `''`
  literals in a `.nix` file (90 % of `lib/aki-site.nix` is such literals): literals
  cannot be linted or reviewed, and every byte re-evaluates a module that imports
  the knowledge graph.
- **One instantiation.** Build the site once (`.#sites.fleet-docs-site`) and pass the
  path to every vhost/socket; three `import`s with identical args are three evals.
- **A rendered surface is compiled** [[flake/policies.nix#surfaces-are-compiled]]:
  one registry emits pages, mounts and `data/services.json`; an ownerless card fails the gate.
- **Publishing must not need a system switch.** If a `.md` edit lands inside a
  host's closure, the docs are as live as the last `nixos-rebuild`.
- **Eval-time `builtins.readFile` is flake-scoped.** An untracked `.md` does not
  exist to the evaluator — `git add` before you eval or serve.
- **An unlinked page is a page nothing routes to.** A `docs/*.md` earns its place
  by being named from a living document; deleting it is the other valid answer.
  [[flake/policies.nix#no-orphan-docs]]

Audit, evidence and remediation order: `docs/docs-pipeline-audit.md`.

## Documentation Map

| File                                 | Content                                                                |
| ------------------------------------ | ---------------------------------------------------------------------- |
| [`README.md`](README.md)                          | Full repo documentation, architecture, all workflows                   |
| [`AGENTS.md`](AGENTS.md)                          | This file — canonical agent routing and codebase manual                |
| [`inventory.toml`](inventory.toml)                     | Canonical fleet device registry; compiled by `lib/inventory.nix` (counts derived, not written). `[repos.*]` lists the repos that are ours but not vendored here (their own CI and authoring) — `nix eval .#inventory.repos` |
| [`docs/inventory-schema.md`](docs/inventory-schema.md)           | Inventory schema, compiled artifacts, and the automatic checks          |
| [`docs/sops-rekey.md`](docs/sops-rekey.md)                  | Sops planes and files, `.sops.yaml` anchors, SSH CA, rekey procedure, fresh-host bootstrap |
| [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md)            | `/srv/data` layout, permissions/sentinels, media-scanner rules, ingest doors |
| [`docs/steam-cache.md`](docs/steam-cache.md)                | LAN Steam content cache: front/cache split, flash-tier measurements, how to disable |
| [`docs/fleet-inventory.md`](docs/fleet-inventory.md)            | Pointer page — the catalog itself is `.#artifacts.docs` (`nix build .#artifacts.docs`), never committed |
| [`docs/modules-registry.md`](docs/modules-registry.md)           | Pointer page — the knob registry is built from `modules.toml` at build time |
| [`lib/aki-site.nix`](lib/aki-site.nix)                   | The rendered site (`.#sites.fleet-docs-site`): nav comes from the knowledge graph |
| [`docs/docs-pipeline-audit.md`](docs/docs-pipeline-audit.md)        | Docs/site pipeline audit: duplicated artifacts, content-in-Nix, remediation order |
| [`docs/closure-reduction.md`](docs/closure-reduction.md)          | Closure size levers, evidence chains, and the runtime/interactive/one-shot tiers |
| [`docs/closure-debloat.md`](docs/closure-debloat.md)            | Tiered debloat plan: exclusive/shared/core attribution and a realistic floor |
| [`.agents/fleet-matrix.md`](.agents/fleet-matrix.md)            | Compact fleet context matrix for LLMs and agent prompts                |
| [`docs/task-control-plane.md`](docs/task-control-plane.md)         | Task namespace policy and workflow examples                            |
| [`docs/ci-pipeline.md`](docs/ci-pipeline.md)                | CI: inventory-driven host selection, path rules, the two builds per host |
| [`docs/nix-patterns.md`](docs/nix-patterns.md)               | yq/format traps, non-obvious Nix, build-budget traps, store reclaim (GC roots), agent failure modes |
| [`docs/NUSHELL.md`](docs/NUSHELL.md)                    | Shell layer: `nu -c` config trap, secrets loader, LLM/decision commands, extras verdicts |
| [`docs/frieren-access.md`](docs/frieren-access.md)             | frieren service-access runbook (LAN/tailnet matrix, DNS, direct ports) |
| [`docs/dns-failover.md`](docs/dns-failover.md)                | Resolver pair, route vs node failover, why the `/32` cannot fail over |
| [`docs/userland-package-ownership.md`](docs/userland-package-ownership.md) | Package ownership and role wiring                                      |
| [`docs/eisen-llm-architecture.md`](docs/eisen-llm-architecture.md) | eisen LLM stack: design rationale, model roster, measured performance (runbook: `.agents/deploy/hosts/eisen.md`) |
| [`taskfiles/README.md`](taskfiles/README.md)                | Taskfile ownership map and shard reference                             |
| [`hosts/sledgehammer/USB.md`](hosts/sledgehammer/USB.md)          | Sledgehammer live USB creation guide                                   |
| [`AGENTS.nix`](AGENTS.nix)                         | Decisions, proposals, open work and design studies as queryable notes |
| [`MANUAL.md`](MANUAL.md)                          | Operator manual: services, ports, closed loop, DMS integration         |
| [`.agents/SCHEMA.md`](.agents/SCHEMA.md)                  | Documentation/skill contract: budgets, status vocabulary, one fact one home |
| [`docs/history/`](docs/history/)                      | Superseded narrative (audit/TODO/HANDOFF) — never linked as current    |
| [`AUDIT.md`](AUDIT.md)                           | Current state + dated change ledger                                    |
