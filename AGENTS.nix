# AGENTS.nix — the repo's narrative knowledge as data.
{
  schemaVersion = 1;
  notes = {
    agent-vault-rbw-only = {
      title = "Agent credentials go through rbw; agent-access is not installed";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-19";
      summary = "aac's field-scoped tunnel costs one unpackaged binary, a permanent bw shim (its Bitwarden provider shells out to bw anyway), a pty-only listener and a third-party default relay. The fleet keeps rbw from nixpkgs and bounds reads with a dedicated user, a short unlock window and an item allowlist.";
      refs = {
        modules = ["flake/cli.nix"];
        tasks = ["checks:ssh:bitwarden"];
        docs = ["docs/rbw-agent-secrets.md"];
      };
      body = ''
        Verified 2026-11-19 against agent-access v0.11.0 and rbw 1.15.0:
        - The release tarball is dynamically linked and fails on NixOS; a patched
          build runs, but that is a second unpackaged Rust binary to carry.
        - aac's Bitwarden provider shells out to `bw` for status, unlock and get,
          so rbw still needs a shim and the `bw` name stays in the tree.
        - `aac listen` is a ratatui TUI that panics without a pty.
        - The default relay is a third party; rbw keeps the vault client local.
        - `rbw get --raw` carries every field aac reads, and `--field` selects one.

        The boundary is the procedure in docs/rbw-agent-secrets.md: a dedicated
        user, `rbw lock` in a trap, `lock_timeout`, and item namespacing with an
        allowlist glob. The residual risk is stated there — an unlocked agent
        reads the whole account, which is the property aac would have narrowed.

        Exit: agents follow the doc; revisit aac only when a grant must be
        narrower than the account, and that decision needs no bw shim.
      '';
    };
    firecrawl-local-loopback = {
      title = "firecrawl-local is built on clanker and serves hermes extract on loopback";
      kind = "decision";
      status = "REJECTED";
      priority = "P2";
      date = "2026-11-19";
      summary = "No prebuilt exists, so the crate is compiled once on clanker and patched to frieren's loader; measured the same day it answers a scrape 5-25x faster than the cloud path at 23 MiB idle, and hermes reaches it through FIRECRAWL_API_URL instead of the keyed cloud API.";
      refs = {
        modules = [
          "hosts/frieren/tools.nix"
          "modules/user/ai/hermes-user.nix"
        ];
      };
      body = ''
        Built 2026-11-19 from crates.io `firecrawl-local` 0.1.0 on clanker (`nix shell nixpkgs#rustc nixpkgs#cargo nixpkgs#gcc`,
        5m42s on 4 vCPU): 23,843,336 bytes, sha256 2c7fbf19…cc8b. It links against clanker's store glibc, so it is patched
        to frieren's loader and gcc-16.2.0-lib rpath (`--set-interpreter`, `--set-rpath`) before first use.

        Runtime, not a derivation: ~/.local/bin/firecrawl-local, unit ~/.config/systemd/user/firecrawl-local.service
        (`serve --port 3002`, FIRECRAWL_CLOUD=off, FIRECRAWL_LOCAL_BROWSER=auto). Chrome comes from the store, not the
        repo: ~/.local/bin/firecrawl-chrome execs the chromium agent-browser already pins (157, on cache.nixos.org, so
        nothing is pushed to the fleet edge) and gc-roots it under ~/.local/state. JS-only pages were header-only under
        `never` and render under `auto` (quotes.toscrape.com/js: 0 → 3 quotes, status 200).

        Measured 3 runs per page, warm: example.com 0.02 s vs 0.42 s cloud, NixOS manual 0.33 s vs 1.59 s; idle RSS
        23.1 MiB, not the vendor's 11.

        Wiring is two pins. `hermes doctor` named extract firecrawl while the tool resolved to tavily (measured
        2026-11-19), so the persona config pins `web.extract_backend: firecrawl`, and FIRECRAWL_API_URL in
        ~/.hermes/.env.local (folded in by hermes-env-sync) points that provider's self-hosted branch at 127.0.0.1:3002.

        Verified by calling `web_extract_tool` with the unit stopped: it named port 3002 and refused. It also rescued
        that failure through keyless cloud, so a dead loopback degrades quietly rather than erroring.

        Exit: replace the user-local binary and unit with something a host rebuild owns, then REJECT this note.
        Met 2026-11-24: `programs.hermes-user.firecrawl` in hermes-user.nix builds the crate as a `buildRustPackage`
        derivation (the cargoHash the prebuilt note called the blocker: fetched crates.io 0.1.0 plus a `cargoDeps`
        vendor run), declares the same unit (`serve --port 3002`, FIRECRAWL_CLOUD=off, FIRECRAWL_LOCAL_BROWSER=auto),
        ports the firecrawl-chrome launcher to a store script, and removes all three hand-placed files in a
        checkLinkTargets guard. frieren sets `firecrawl.enable`; every other host keeps the defaults.
      '';
    };
    config-registry-schema = {
      title = "The config registries have no schema, and four conventions nothing checks";
      kind = "open";
      status = "DELIVERED";
      priority = "P4";
      date = "2026-11-11";
      summary = "A cpg schema pass over modules.toml, taskfiles/checks.toml and inventory.toml found rules no gate enforced: knob path location, option casing, a group with no root row, and ports that live only in description prose. Delivered 2026-11-19 as lib/registry-schema.nix plus checks.<system>.registry-schema.";
      refs = {
        modules = [
          "modules.toml"
          "flake/check-inventory.nix"
          "inventory.toml"
          ".sops.yaml"
        ];
        tasks = ["checks:knobs" "check:verify" "agents:review:schema"];
        docs = [".agents/skills/cpg/SKILL.md"];
      };
      body = ''
        Swept 2026-11-11 with `task agents:review:schema` over modules.toml, the first six rows of taskfiles/checks.toml
        (now `flake/check-inventory.nix`) and two inventory hosts. `checks:knobs` already proves every knob path exists,
        every host resolves and `metadata.total_knobs` matches. These are the rules nothing proves.

        - `knobs.ai.path` is `modules/global/noDE.nix`, the only one of 17 outside `modules/profiles/` or
          `modules/services/`. The gate allows it, so the convention is real only in the other 16 entries.
        - Three options are camelCase (`profiles.dwlDesktop.enable`, `services.zettelGraph.enable`,
          `services.mataroaConsole.enable`); 14 are kebab. All resolve as Nix paths, so nothing decides which style holds.
        - Six services name their port only inside `description` (:5000, :8123, :8088, :6801, :8453, :8454).
          `checks:ports` audits firewall against live listeners, so two knobs could claim one port unseen.
        - `taskfiles/checks.toml` has a root row for `checks:appflow` and none for `checks:audit`, which exists only as
          `:handoff` and `:system`. `check:verify` pairs rows with tasks; it says nothing about roots.
        - `inventory.toml` omits `managed` on 27 of 38 hosts. That one is settled — `lib/inventory.nix` defaults it to
          false — and is recorded so the next sweep does not re-open it.
        - `.sops.yaml` defines the `garnix` anchor and references it in no group, and `acersops`/`acersopshost` carry
          one recipient value.

        Delivered 2026-11-19: `lib/registry-schema.nix` records the conventions and each departure WITH the excepted
        value, and `checks.<system>.registry-schema` (built by `checks:quick`) fails on any other departure; the six
        prose ports are `port` fields now. Root rows are recorded as a census (30 flat families, `appflow` the only
        umbrella) since `check:verify` pairs rows with tasks; `.sops.yaml` is another registry.
        2026-11-20: the check now covers `.sops.yaml` too — every `keys:` anchor must be claimed by a group's age list
        and every `*alias` must resolve; `sopsAnchorExceptions` records `garnix` (garnixMachine's on-host
        repo-key, not a group recipient).
      '';
    };
    model-provider-epistemics = {
      title = "Model availability is provider-scoped, not inferred across vendors";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-10";
      summary = "Model slugs and availability cannot be extrapolated across multi-provider chains: OpenRouter, Ollama Cloud, and NVIDIA NIM curate distinct catalogs and versions. Fallback chains must verify each live endpoint before bumping configs.";
      from = ["epistemics-declared"];
      refs = {
        modules = [
          "modules/user/ai/hermes-persona/config.yaml"
          "flake/epistemics.nix"
        ];
        tasks = ["checks:hermes"];
        docs = ["AGENTS.md"];
      };
      body = ''
        An agent upgrading a model family (e.g. Nemotron 3.5 Super VL) across a
        multi-provider fallback chain cannot extrapolate names across hosts.
        While OpenRouter serves `nvidia/nemotron-3.5-super-vl:free` and NIM
        serves `nvidia/nemotron-3.5-super-vl`, Ollama Cloud (`ollama.com/v1`)
        maintains a closed list of ~23 models where Nemotron is pinned to
        `nemotron-3-super` and `nemotron-3-ultra`.

        A slug declared on a provider that does not serve it causes immediate
        failover or 404. Every provider in `fallback_providers` must be
        verified against its real `/v1/models` endpoint before landing.
      '';
    };
    eval-cost-ladder = {
      title = "Eval cost is chain size; the debt is duplicated facts";
      kind = "proposal";
      status = "ACCEPTED";
      priority = "P1";
      date = "2026-11-08";
      summary = "A host gate is its chain's option surface, not a host file; derivation equality is the refactor instrument, hosts and the user role are feature lists, the check surface has three verbs over one table, and the task-plane split is blocked on where a task's desc lives.";
      from = ["dendritic-flake"];
      refs = {
        modules = [
          "flake/module-sets.nix"
          "modules/roles/home.nix"
          "modules/user/desktop/suite.nix"
          "scripts/task/drv-equality.py"
          "scripts/task/check.sh"
          "scripts/task/lib/taskfile_graph.py"
          "scripts/task/skills-task-mirror.py"
          "tests/taskfile-graph/expected.json"
          "flake/checks.nix"
          "flake/check-inventory.nix"
        ];
        tasks = ["checks:drv-equality" "checks:host" "checks:skills:mirror" "check:leaf" "check:list" "check:verify"];
        docs = ["docs/task-control-plane.md" "docs/control-plane-vision.md" "docs/nix-patterns.md" "AGENTS.md"];
      };
      body = ''
        Claim: a gate's cost is its chain. Reproduce the split by evaluating the
        same host on a desktop chain and on the lean role — the difference is the
        chain, and a host file's 700 lines are the smaller half. The scaffolding
        (`nix flake check` forbidden, oom-guard, phased protocol) exists because
        the fleet check inherits that floor per configuration.

        Six rungs, cheapest first; all landed, three of them differently than
        planned.
        1. Derivation equality as the refactor instrument — `checks:drv-equality`.
        2. A host as a feature list — `mkHost` + `chainFeatures`
           (`flake/module-sets.nix`); 30 configurations unchanged across it.
        3. Cut the chain — the role was never the cost: `systemd-policy` alone
           was +356 MiB, and every feature now evaluates at 897 MiB. Table and
           method: `docs/control-plane-vision.md` §"A gate's cost is its chain".
        4. Three verbs over one table — `taskfiles/checks.toml` plus
           `check:leaf|host|cache` and `check:list`, with `check:verify` in
           `checks:quick`. The 94 named tasks stay the implementation: `check.sh`
           dispatches `task <name>`, so a deleted name moves its command into a
           TOML string. Why: `docs/task-control-plane.md`.
        5. Task plane — the PARSER moved, not the data, because `desc` has to live
           in YAML for go-task. yq + `taskfile_graph.py` replaced
           `lib/taskfile.nix` and the digest pin; parity was proved before the
           deletion.
        6. Documents — every table that mirrored a source is compiled or gone;
           AGENTS.md is 223 lines and its floor without deleting knowledge is ~200.

        OPEN: rung 3's last item — the classification gate out of the host eval,
        beside `checks:units` — is a safety decision, not a refactor.
        Not doing: IFD (1.8 s on every eval that touches it), splitting HM out of
        hosts to shrink host eval, a second renderer beside the site.
      '';
    };
    dendritic-flake = {
      title = "Dendritic flake — `self` as the only import root";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-05";
      summary = "flake-parts owns the outputs and every file under `modules/` is a named flake output imported through `self`, so no file list is hand-maintained and finding a module's users is a graph query, not a grep across relative paths.";
      from = ["d1-compiled-context"];
      refs = {
        modules = ["flake.nix" "flake/outputs.nix" "flake/systems.nix" "flake/devshells.nix" "flake/checks.nix" "flake/nix-registry.nix" "flake/module-sets.nix" "flake/host-inventory.nix" "lib/nix-files.nix" "lib/knowledge-graph.nix"];
        tasks = ["checks:host" "checks:tasks" "ops:kg:module"];
        docs = ["README.md" "docs/nix-patterns.md"];
      };
      body = ''
        Problem: `flake/outputs.nix` was assembled by hand, hosts listed modules in
        `flake/host-inventory.nix`, chains in `flake/module-sets.nix`, and a module
        reached a sibling by relative path — so "who uses this file" was a grep.

        Shape: `flake-parts` owns the outputs; every file under `modules/` gains a
        name imported through `self`; `flake/host-inventory.nix` keeps `kind`,
        `system` and the host path. Gate: the same toplevel `drvPath` per
        representative chain, `checks:host` green.

        DELIVERED in four commits (2026-11-05/06): flake-parts owns the outputs
        (32 names, three chain toplevels unchanged at one git state); then
        `lib/nix-files.nix` walks the tree and dev shells move to `perSystem`;
        then `.#modules` names every file under `modules/`, with chains, 33 host
        files and 43 host sub-modules naming 136 imports; then 21 files name their
        own 66 imports, so no sibling is reached by path from anywhere and the
        graph reads name edges on both sides.

        Exit: met. `flake/outputs.nix` projects from `inventory.toml` and the walk
        (`project = kind: fn:`), so neither a file list nor a host list is
        hand-maintained, and `checks.<system>.nix-registry` fails a duplicate name
        or one that resolves to no file. Line counts did not fall — `flake.nix` +31
        for the flake-parts body, `checks.nix` +28 for the gate — the lists did.

        Finished 2026-11-08: the "loads with arguments" exception is gone too —
        the 13 such loads name their file, so `grep 'import \.\./' modules/`
        answers nothing and what remains is `builtins.readFile` of data. Two dead
        files removed (`services/go-backend.nix`, `scripts/examples.nix`); the
        go-backend gate stays in `flake/host-check.nix` as "no host declares that
        unit". The rule the tree keeps is `self.modules."<name>"`, never a sibling
        path (`docs/nix-patterns.md`); the commit log is the rest.
      '';
    };
    d1-compiled-context = {
      title = "D1 — compile context, never hand-maintain a table";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Hosts, skills and the graph are compiled from files (`inventory.toml`, `.agents/skills`, the tree) so every consumer reads one value. A table that exists twice disagrees with itself within a month.";
      refs = {
        modules = ["lib/inventory.nix" "lib/skills.nix" "lib/knowledge-graph.nix" "flake/outputs.nix"];
        docs = [".agents/SCHEMA.md"];
      };
      body = ''
        Adding a host or skill is a file, not a table edit. The projection is the only consumer of the source; nothing downstream re-parses it.
      '';
    };
    d2-eval-first = {
      title = "D2 — a question is a `nix eval` before it is a script";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Compiled data answers faster and validates schema on the way. A shell helper that re-parses TOML is a second parser waiting to disagree.";
      refs = {
        tasks = ["ops:bench:evals"];
        docs = ["docs/task-control-plane.md"];
      };
      body = ''
        Measured: `.#inventory.hosts.<h>.role` 151 ms warm vs `yq` 42 ms raw. The eval is ~3.5x slower and worth it whenever the answer must match what deploys.
      '';
    };
    d3-append-only-ledger = {
      title = "D3 — observation is an append-only ledger, not a dashboard";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "`fleet-sentinel` records jobs, generation age, disk and PSI every 15 min; gatus pages on `[BODY].state != ok`. A green socket is not a successful job.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix"];
        tasks = ["ops:health"];
      };
    };
    d4-no-neo4j = {
      title = "D4 — no Neo4j server; the graph is a projection + Cypher export";
      kind = "decision";
      status = "REJECTED";
      date = "2026-10-19";
      summary = "A ~10^3-node graph does not justify a JVM heap competing with the NAS page cache on an 11 GiB host. The Cypher export exists so an external instance can be fed in one command.";
      refs = {
        modules = ["lib/knowledge-graph.nix"];
        tasks = ["ops:kg"];
      };
    };
    memory-architecture = {
      title = "Memory architecture — vault → qmd → mem0/supermemory → web; ai-memory ungated scratch";
      kind = "decision";
      status = "ACCEPTED";
      date = "2026-11-19";
      summary = "Five-layer memory hierarchy with nix/AGENTS.nix as policy authority; ai-memory stays ungated scratch because nix eval (.#knowledgeGraph) already discovers truth in local files and nix AST.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["lib/knowledge-graph.nix" "modules/user/ai/personas" "modules/services/agent-turns.nix"];
        docs = ["docs/agent-turns.md" "AGENTS.md" ".agents/SCHEMA.md"];
        tasks = ["ops:health"];
      };
      body = ''
        **Layers, in search order.** MEMORY.md (boot, always loaded) → vault (fast working memory) → qmd wiki (docs, runbooks, codebase) → mem0/supermemory (deep consult, decided by jev) → web. The supermemory key writes durable directives for context transfer between the Telegram instance and the tab 3 controller; mem0 stores structured TOON.

        **ai-memory is not authority.** It has no server unit on this fleet and is "never authority for a repo fact." Its handoffs/message/workstreams are rich but the server is not run here; the knowledge graph (.#knowledgeGraph, 1991 nodes compiled from the nix tree) already discovers truth in local files and nix AST, so there is no information digest that needs staging through ai-memory before reaching nix data structures.

        **nix determines policy.** AGENTS.nix notes and .#knowledgeGraph are the compiled source of truth for what exists; xs turn log on delphi is live coordination. Nothing here changes merge authority.
      '';
    };
    d5-one-skill-tree = {
      title = "D5 — one fleet-wide skill tree, materialized by Home Manager";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Two skill copies is the failure mode that made `.#agentSkills` and the deployed tree disagree. Home Manager links one store bundle with `force`.";
      refs = {
        modules = ["modules/user/ai/skills/default.nix"];
        docs = [".agents/README.md"];
      };
    };
    d6-doc-budgets = {
      title = "D6 — living documents have budgets; history moves out";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Over budget is a signal to move detail, not raise the limit. This note set is the 2026-10-19 extension: narrative that is not `AGENTS.md` lives in this file as notes.";
      refs = {
        tasks = ["ops:docs:budget"];
        docs = [".agents/SCHEMA.md"];
      };
    };
    p0-context-plane = {
      title = "P0 — context plane (compiled skills, schema, graph)";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P0";
      date = "2026-10-19";
      summary = "Skills, the inventory and the knowledge graph are compiled and schema-checked. `.#homeAgents.<host>` renders the host card from the same registry; the Python renderer is gone.";
      refs = {
        hosts = ["frieren"];
        modules = ["lib/skills.nix" "lib/knowledge-graph.nix" "lib/home-agents.nix"];
        docs = [".agents/SCHEMA.md" "docs/agent-context/HOME-PREAMBLE.md"];
      };
      body = ''
        Exit criterion met: `nix eval .#agentSkills.count` answers in ~1.2 s; `checks.<system>.skills-schema` fails on a malformed skill.
      '';
    };
    p1-sentinel-push = {
      title = "P1 — close the sentinel loop fleet-wide";
      kind = "proposal";
      status = "IN FLIGHT";
      priority = "P1";
      date = "2026-10-19";
      summary = "Only frieren is observed today; a host whose collector dies is simply absent. Add one optional egress (`pushUrl` + sops bearer) to the existing sentinel module behind the existing vhost, no new port.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix" "hosts/frieren/infra-stack.nix"];
        tasks = ["ops:health"];
      };
      body = ''
        Exit: three hosts push for a week; a powered-off host shows `stale:>2h` rather than a missing row; ingest stays behind the existing vhost.
      '';
    };
    sentinel-queue-probe = {
      title = "Sentinel observes the mail queue, not just its sockets";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-11-19";
      summary = "`agents:hub` is pull-only, so a queue that stopped draining was silent until a person looked. The collector now reads `/api/queue-health` from the archive and degrades on person/action backlog, fresh unowned attention mail, an unreachable probe and importer lag.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix" "modules/services/email-archive-endpoints/queue-health.sql"];
        hosts = ["delphi"];
        tasks = ["ops:health" "agents:hub"];
      };
      body = ''
        Thresholds are options rather than constants so a host opts in and owns what `degraded` means there: `maxOpenPerson` 25, `maxOpenAction` 40, `maxUnmatchedFresh` 20, `maxMailAgeHours` 26 with a prior-week baseline. Only a host holding the archive sets `queueProbe.url`; an absent probe is neutral, an unreachable one degrades.
      '';
    };
    p2-vault-write-path = {
      title = "P2 — a real write path to the vault";
      kind = "proposal";
      status = "PROPOSED";
      priority = "P2";
      date = "2026-10-19";
      summary = "The gap is not search, it is writing: one inbox file per host per day, curated by hand, never overwritten. NFS down must fail loudly and lose nothing.";
      refs = {
        modules = ["modules/profiles/nas-client.nix" "hosts/frieren/infra-stack.nix"];
        tasks = ["dev:qmd:vault:refresh"];
      };
      body = ''
        Frontmatter: source, host, date, status, tags. Generated tables link to `.#knowledgeGraph`; they are never pasted into the vault.
      '';
    };
    p3-graph-query = {
      title = "P3 — graph vs prose vs qmd";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-10-19";
      summary = "`qmd` answers \"where is this explained\"; the graph answers \"what touches X\". `.#knowledgeGraph` compiles hosts, skills, docs and mentions; `ops:kg:*` is the query path.";
      refs = {
        modules = ["lib/knowledge-graph.nix"];
        tasks = ["ops:kg" "ops:kg:host" "ops:kg:blast"];
      };
      body = ''
        Neo4j rejected (D4). If multi-hop queries ever outgrow jq, the next candidate is an embedded engine, not a server.
      '';
    };
    p4-taskfiles-to-evals = {
      title = "P4 — taskfiles to evals, and the last Python";
      kind = "proposal";
      status = "IN FLIGHT";
      priority = "P4";
      date = "2026-10-19";
      summary = "Some tasks re-implement what Nix already knows. The ladder: eval, jq, lib, check, task, script, Go — added only when nothing above answers the question.";
      refs = {
        modules = ["lib/home-agents.nix"];
        tasks = ["ops:bench:evals"];
        docs = ["docs/task-control-plane.md"];
      };
      body = ''
        Delivered: home card in Nix; MANUAL §1's identity table replaced by the generated host card; §2's service map compiled to `docs/generated/fleet-services.md`; `software.services` is a typed record (name, port, note) with duplicate-name/port issues, so every host's "what runs here" is data. Remaining: retire the `modules-menu.sh sync` wrapper once no hand table is left — §2's unit and reach columns are operational, so they stay prose.
      '';
    };
    p5-dms-widget = {
      title = "P5 — DMS sentinel widget";
      kind = "proposal";
      status = "PROPOSED";
      priority = "P5";
      date = "2026-10-19";
      summary = "Surface the sentinel where the operator already is: one DMS custom module reading the existing loopback `status.json`. No token plumbing, no daemon, no second palette.";
      refs = {
        hosts = ["frieren"];
        modules = ["modules/services/fleet-sentinel.nix"];
        tasks = ["ops:health"];
      };
      body = ''
        Notify on the transition (3-failure threshold), not on every poll. Exit: red card on degraded, green on recovery, no new service or port.
      '';
    };
    p6-canary-gate = {
      title = "P6 — canary as the promotion gate";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P6";
      date = "2026-10-19";
      summary = "The canary is the HOST, not a guest: `hostBootChecks.<arch>.<host>` boots that host's own module list in a VM and fails unless stage-2 is reached. `task checks:boot HOST=` (KVM/CI) and `checks:boot:self` (this host, before its switch); CI's `boot-canary` job for `modules/services/**`.";
      refs = {
        modules = ["flake/boot-checks.nix" "flake/outputs.nix" ".github/workflows/nixcachix.yml"];
        tasks = ["checks:boot" "checks:boot:self"];
        docs = ["docs/ci-pipeline.md" "hosts/microvms/README.md"];
      };
      body = ''
        The SubZeroClaw guest was the wrong instrument: its own kernel and root, so
        it could never fail for the host being promoted. It stays a sandbox
        (`vm:canary:*`); the promotion gate imports `<host>.modules` verbatim, moves
        root onto the VM disk, drops the bootloader, and neutralises sops (no TPM,
        no keys in a VM). Assertion: `Reached target Multi-User System` on the serial
        console, then a QEMU-monitor crash — the driver's backdoor shell has a hard
        300 s connect budget and a Requires on /dev/ttyAMA0 that aarch64 guests do not
        always satisfy.

        Reach: delphi booted its real graph to stage-2 under TCG; CI with KVM is
        seconds. Not in reach: hardware (no eMMC/NVIDIA/TPM), so netbook gen 50's
        HANDOFF class is covered while its eMMC trigger is not — said in the file.

        A boot is not a hygiene step. Re-running it after doc edits that could not
        change the guest is what pegged one of delphi's two cores while it served
        delphi.bountystash.com and ssh. So `checks:boot` refuses without /dev/kvm,
        before its first eval (`boot-gate-needs-kvm`), and the one emulation allowed
        is `checks:boot:self` / `BOOT=1`: the machine being switched, one vCPU,
        niced — the initrd nobody can diagnose from outside.

        Cost is printed by every run (watchdog elapsed + process-group peak RSS) and
        appended to `$XDG_STATE_HOME/nixconfig/boot-check.log`, with the delta against
        the last run for that host: the affordability claim is a comparable number.
      '';
    };
    microvm-guests = {
      title = "MicroVM guests: declarative, store-shared, one base module";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-23";
      summary = "`microvm.vms.<name>` on frieren (brlan, KVM, cloud-hypervisor) and on delphi (aarch64, qemu/TCG: OCI A1 exposes no EL2, and cloud-hypervisor has no TCG backend). A guest reads the host's /nix/store over virtiofs, so starting one is seconds on KVM and minutes under TCG; no image is built either way, only the shares persist.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["hosts/microvms/base.nix" "hosts/microvms/frieren-canary.nix" "modules/profiles/microvm-host.nix" "hosts/delphi/configuration.nix"];
        tasks = ["microvm:list" "microvm:start" "microvm:stop" "microvm:ssh" "vm:canary:run" "vm:canary:test"];
        docs = ["hosts/microvms/README.md"];
      };
      body = ''
        The shape is Stapelberg's ("Coding Agent VMs on NixOS with microvm.nix", 2026-02-01):
        a shared read-only store, explicit shares, ephemeral by default. Nothing is copied at boot.

        Two tiers, and the tier is a declaration. frieren's guests are ephemeral tooling
        (`autostart = false`, /var is tmpfs, a restart is a factory reset). delphi's sandbox is a
        service tier — `autostart = true`, 4096 MiB, two stub httpd units, Stirling PDF — because a
        reboot should bring back what the vhost serves.

        State is a named volume, never a bind mount: `persist = { stirling = { size = 4096; }; }`
        mkfs's one ext4 image per name under `<stateRoot>/sandbox/volumes/` and finds it by **label**
        (enumeration order is not identity), so the guest owns the filesystem and its own uids.

        TCG is why the guest needed a wider device timeout: systemd's 90 s expired before udev
        published the virtio-blk labels. `DefaultDeviceTimeoutSec = 600` there; KVM untouched.

        How to get in — the guest is a service tier, not a shell you visit: `ssh sandbox` on delphi,
        or `task microvm:ssh NAME=sandbox`. Plain `ssh delphi.bountystash.com` is the HOST shell as
        `devji`; `sandbox` resolves only on delphi because the bridge subnet is host-local.

        The deck is OFF, and it is a development facility rather than a service: `slidesUser =
        "slides"` plus `exposeSsh = 2222` brings back a forced command into a terminal markdown deck.
        It was turned off because it leaked — every login is a TUI that no one closes, and under TCG
        each one cost real host CPU (three abandoned sessions were 0.65 of the box's two cores). The
        forced-command traps, kept for whoever turns it back on: `AuthorizedKeysFile` REPLACES the
        default, so the keys NixOS writes to `/etc/ssh/authorized_keys.d/%u` must be named back;
        StrictModes refuses a keys file whose path is not root-owned, so the hop's public half lives
        in `/srv/microvm/hop-auth`; and a fleet cert's principal is the user name, so the account
        needs `AuthorizedPrincipalsFile` listing `devji`.
      '';
    };
    arch-shape = {
      title = "Architecture — the layers, in one note";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Each layer only consumes the layer above: inventory -> flake assembly -> task plane -> host closure -> observation. A host does not parse TOML; a skill does not re-derive fleet facts.";
      refs = {
        modules = ["flake/outputs.nix" "lib/inventory.nix" "lib/docs.nix"];
        docs = ["docs/task-control-plane.md"];
      };
    };
    non-goals = {
      title = "Non-goals and standing rules";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "The prohibitions that keep this repo from re-growing the slop it just removed.";
      refs = {
        docs = [".agents/SCHEMA.md"];
      };
      body = ''
        - No second fleet table anywhere; query `.#inventory` or link the generated page.
        - No monitoring database on frieren; the ledger is bounded (D3/D4).
        - No per-host agent daemon for observation (P1 pushes the same unit).
        - No Neo4j as a local service (D4).
        - No broad host rewrite in one pass, no moving secrets/encrypted data.
        - Do not add a task when a `nix eval` answers the question (D2).
        - Never run `nix flake check` on a small host (6 GiB / SIGKILL 137).
        - A completed item is `DELIVERED` with a path, not "done".
      '';
    };
    download-route-bulk = {
      title = "Bulk downloads go through aria2: frieren's daemon, delphi's gigabit";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-04";
      summary = "Anything over 5 GiB is an aria2 job, never curl or wget, and the route follows the bottleneck: frieren's system RPC daemon for anything that lands on /srv/data, delphi's one-shot aria2c when the CDN is throttling the WAN path.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["modules/services/aria2-daemon.nix" "modules/aria2.nix" "modules/user/base.nix"];
        docs = ["docs/storage-taxonomy.md"];
      };
      body = ''
        - Threshold: over 5 GiB is `aria2c -x16 -s16 -k1M`, not `curl -O` or `wget`. Metadata and API reads stay curl.
        - Route: frieren runs the system `services.aria2-daemon` on :6800 (sops `aria2-rpc-secret`, session in /var/lib/aria2) and is the default for anything that ends up on /srv/data. delphi has only the BINARY (role:minimal -> user/base.nix ships `aria2`); `modules/aria2.nix` is the zen persona and is NOT on the containers chain, so there is no RPC daemon there. One-shot `aria2c` on delphi, then rsync to frieren.
        - Why delphi at all: its uplink is gigabit while HuggingFace measured 2.7 MB/s from frieren and 1.45 MB/s from eisen (2026-11-03). The bottleneck is per-connection CDN throttling, not the LAN, so the cloud host is the right fetcher for a big pull even though every byte then crosses the tailnet once.
        - Trap that cost a verification pass: aria2 names a file after the FINAL url segment, so a HF `resolve/...` url that redirects to `cdn-lfs` lands as a 64-hex filename. `stat` on the expected name reads 0, and a completion watcher then reports a perfect download as a size mismatch. Take `files[].path` from `aria2.tellStatus`; never assume the name.
        - `complete` means "wrote the bytes it was told to": check the exact byte length AND the publisher's SHA-256 (HF repos ship SHA256SUMS) before anything is copied, moved into a model dir, or loaded.
      '';
    };
    open-strata-eisen-rx5700 = {
      title = "Implement Strata MoE inference on eisen's RX 5700";
      kind = "open";
      status = "DELIVERED";
      priority = "P0";
      date = "2026-10-20";
      summary = "Deploy Niko1221/Strata (Qwen3.8-Flash-Next 125B MoE Coder IQ1_M) on eisen's RX 5700 (Navi 10 / gfx1010) via experimental HIP build without compromising Vulkan gaming.";
      refs = {
        hosts = ["eisen"];
        modules = [
          "hosts/eisen/amd-rx-5700.nix"
          "hosts/eisen/llm-server.nix"
          "hosts/eisen/strata.nix"
        ];
        tasks = ["checks:host"];
        docs = [
          ".agents/deploy/hosts/eisen.md"
          "docs/eisen-llm-architecture.md"
          "hosts/eisen/MANUAL.md"
        ];
      };
      body = ''
        Delivered: Niko1221/Strata running Qwen3.8-Flash-Next 125B MoE Coder IQ1_M on eisen's AMD Radeon RX 5700 (Navi 10 / gfx1010, 8 GB VRAM).
        Architecture: Strata compiled with gfx1010 HIP architecture under hermetic FHS wrapper (strata-fhs) on /mnt/storage/strata with official AMD TheRock ROCm 7.14 wheels, keeping host Mesa/RADV Vulkan clean for Steam and Sunshine.
        Service & Endpoints: Systemd service strata.service serving on :8085; Nginx port 80 proxy and Tailscale serve (https://eisen.cloudforest-kardashev.ts.net/) reverse-proxying directly to Strata; llama-swap dormant and commented out.
        SubZeroClaw Harness: ~/.subzeroclaw/config pointed to :8085, successfully executing end-to-end agent tool loops.
        Performance: Benchmarked at 167 tok/s prompt ingestion, 14.6–21.0 tok/s decode, and 87.5% MTP speculative drafting acceptance rate (70/80 tokens accepted) with 32K context and INT8 KV cache. Documented in hosts/eisen/MANUAL.md.
        Gaming Guard: llama-swap-gaming-guard unit updated to suspend strata.service when Steam games launch, returning 100% VRAM to Proton/Gamescope.
      '';
    };
    strata-quant-tier = {
      title = "The Strata pack tier is a page-cache question, not a bit-width one";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-11-03";
      summary = "IQ1_M Coder (58.41 GB) is the lossiest quant in the family and was never a choice — it was what fit. Every Swift 1.5 tier of the same base is 66–84 GB against 62.7 GiB RAM, so the page-cache miss rate decides decode speed, not the KLD table.";
      from = ["open-strata-eisen-rx5700"];
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/strata.nix" "hosts/eisen/server.nix"];
        tasks = ["infra:status:eisen" "checks:host"];
        docs = [".agents/deploy/hosts/eisen.md" "hosts/eisen/MANUAL.md"];
      };
      body = ''
        Served is ISTA-DASLab's Coder pack at IQ1_M: 29.61 + 28.80 = 58.41 GB pruned to 256 of
        512 experts. That tier was never chosen — it was what fit — and it is the lossiest quant
        in the family. The candidate family (Swift 1.5, same MoE base, all 512 experts) is 66.55
        to 83.74 GB against 62.7 GiB RAM, and Strata mmaps the GGUF with a ~23–32 GiB expert
        arena, so page cache, not bit width, sets decode speed.

        Measured 2026-11-04, shards verified against the publisher's SHA256SUMS and packs built
        by tools/iq_pack.py (96 exact conversions, 0 rounded): IQ3_XXS 75.97 GB decodes 7.4–20.8
        tok/s (median 12.2 desktop, 10.4 `server`), IQ2_XS 68.15 GB 7.2–20.3 (median 13.0) — both
        under IQ1_M's 14.6–21.0, and the TTY persona does not close the gap.

        They also lose the agent suite, and so does IQ1_M once the engine's prefill guard fires:
        "no progress for 60 s ... reading the prompt (batched): layer 1 of the prompt chunk from
        token 9076", the wrapper restarts the engine and the session resumes — `oom_kill` 0, no
        kernel line. `--no-ple` is refused under `--native`, so PLE is not a separable shard, and
        16384 context made it worse rather than better. That is an engine version, not a tier:
        see strata-engine-bump-retest.

        Also a measurement trap: the chat medians are cold/warm, not tier — IQ1_M re-measured
        right after a restart scores 13.8 / 7.0 / 7.3 against its own 14.6 warm baseline. Compare
        tiers only on a server that has been answering for a while.

        Exit: IQ1_M stays served (`--max-context 32768`, `--kv int8`, MTP, 24 threads); the larger
        packs stay on the host for a retest. Table and full numbers: hosts/eisen/MANUAL.md §7.
      '';
    };
    strata-engine-bump-retest = {
      title = "Strata 0.1.56 on gfx1010: the prefill rework is what the agent loop waits for";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-04";
      summary = "The served engine is 0.1.46.2 while 0.2.10 ships 0.1.56, and 0.1.48+ carries a chunked prompt read, a ~34% long-prompt skip and exact AVX2 CPU rows. Rebuild locally for gfx1010 and re-run the same suite: 93.8 s per-turn prefill is the number to beat.";
      from = ["strata-quant-tier"];
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/strata.nix"];
        tasks = ["checks:host"];
        docs = [".agents/deploy/hosts/eisen.md" "hosts/eisen/MANUAL.md"];
      };
      body = ''
        The pack question is settled (IQ1_M, strata-quant-tier); this is the engine, which is
        ten point releases behind ours. Everything below is newer than 0.1.46.2 per the
        upstream changelog: 0.2.4 reads long prompts layer by layer in big chunks instead of 16
        tokens at a time (8K prompts reach 231 tok/s); 0.2.4 skips work the last 20 layers
        cannot use on prompts over ~3,700 tokens (~34% at 16K, same top choice in 99.5% of 799
        positions); 0.2.4 adds exact AVX2 rows for the experts the CPU computes (+25% decode and
        +26% prompt read on their test box — the Haswell here is that branch); 0.2.9 has
        STRATA_COALESCE_PREFILL, off by default; 0.2.8 reads slightly malformed tool calls at
        98.3% against 92.9% over 1,462 agent turns. Nothing else in 0.2.x touches this host:
        DFlash2 needs gfx1100+, the NUMA split is a two-socket feature, DSpark stays off on
        CPU-bound boxes, and the split engine is multi-GPU.
        Build it as the local HIP engine for gfx1010 — the packaged rx9070 binary will not run
        here — and read BUILD.json back before measuring, since that version is the result.
        Also A/B the pair #4566 reports as a stall mitigation on 0.1.56 (`--adapt-swaps 0` with
        STRATA_VERIFY_COHERENT=1): our stall is in a chunk read rather than the verify path, so
        it is a test, not an assumption.
        Exit: `tools/strata_bench.py --runs 3` on a warm server beats the 2026-11-04 baseline
        (chat median 11.30 tok/s, 4K prompt 166.8, agent 8.40, per-turn first token 93.77 s) and
        reports its stall count; MANUAL §7 and upstream #5229 carry the numbers; checks:host
        HOST=eisen is green. No gain means the note keeps the number and the answer stands.
      '';
    };
    deepseek-v4-flash-eisen = {
      title = "DeepSeek-V4-Flash 284B on eisen: does a 57 GiB CPU pack beat what the box already serves?";
      kind = "experiment";
      status = "REJECTED";
      date = "2026-11-09";
      summary = "Synchopate's 56.56 GiB DeepSeek-V4-Flash pack fits eisen's 62.5 GiB RAM but not its silicon: the bundled binary needs AVX-512 and dies with SIGILL here, and the AVX2 source build that runs decodes at 2.9 tok/s against Strata's 19.4. Strata stays resident; the pack stays on disk.";
      from = ["download-route-bulk"];
      refs = {
        hosts = ["eisen" "frieren"];
        modules = [
          "hosts/eisen/deepseek-v4.nix"
          "hosts/eisen/llm-server.nix"
          "hosts/eisen/strata.nix"
        ];
        tasks = ["checks:host"];
        docs = ["docs/deepseek-v4-flash.md" ".agents/deploy/hosts/eisen.md"];
      };
      body = ''
        Download done 2026-11-09 through frieren's aria2 RPC, then sorted to
        /srv/data/software/models: three shards (60.74 GB) plus the 15.8 MB
        prebuilt llama-server. The HF CDN served eisen at 1.45 MB/s, so the LAN
        copy to /mnt/storage/models is the route, not a fetch on the host.

        Measured 2026-11-10: REJECTED, on two counts.
        - The bundled binary never serves a token. It traps `invalid opcode`
          inside its own text: a `-march=native` Zen 5 build on a Xeon E5-2673
          v3 with `avx2 bmi2 fma` and no AVX-512. The pack's README carries the
          `avx512` tag, and its own reference decode is 9.06-10.74 tok/s on 16C
          Zen 5 / DDR5-5600, so 15 tok/s was already above better silicon.
        - The source build does run. `synchopate/llama-modchip` clones llama.cpp
          at d2f83055 and applies its patch; `scripts/build_zen5_llama.sh` reads
          `/proc/cpuinfo` and leaves AVX-512 off. Load 4 min for 56.57 GiB, then
          pp 6-7 tok/s over 601 prompt tokens and tg 2.9 tok/s over 128
          predicted, three runs, `cache_prompt:false`.

        So the pack works on this box at a quarter of Strata's 19.4 tok/s agent
        session. It stays on disk with its built binary, nothing is imported, and
        Strata keeps :8085. Steps and launch line: docs/deepseek-v4-flash.md.

        Exit: a decode rate either justifies a port of its own on eisen.lan and a
        place in the router (`checks:host HOST=eisen` green), or the note goes
        REJECTED carrying the measured number.
      '';
    };
    qwen38-35b-a3b-eisen = {
      title = "Qwen3.8-35B-A3B on eisen: does it reach 50 tok/s and take Strata's job?";
      kind = "experiment";
      status = "REJECTED";
      date = "2026-11-10";
      summary = "Qwen3.8-35B-A3B Q4_K_M copied to eisen (21.7 GB, sha256 matched) and benched on Vulkan with the experts in RAM: 15.6-15.9 tok/s decode over three 128-token runs and 93 tok/s prefill, against a 50 tok/s bar and Strata's 19.4. Rejected — ~1.7 GB of expert weights per token against 25.6 GB/s is a ~15 tok/s wall.";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/llm-server.nix" "hosts/eisen/strata.nix"];
        tasks = ["checks:host"];
        docs = ["docs/eisen-llm-architecture.md" "hosts/eisen/HANDOFF.md"];
      };
      body = ''
        Copied 2026-11-10 from frieren's /srv/data/software/models over the LAN at
        ~78 MB/s; 21,713,462,944 B and sha256 1961032690...cfa5 verified on both
        ends. It sits at /mnt/storage/models beside the DeepSeek pack.

        The bar was explicit: 50 tok/s would have made it the default agent coder
        in Strata's place. Measured on the Qwen recipe, not a CPU path —
        llama-server 0.7.0, Vulkan RADV NAVI10, `-ngl 99 -ot exps=CPU -t 12 -tb 24
        -c 32768 --flash-attn on`, 3.10 GiB VRAM resident with the experts in host
        RAM and a 12 s load off page cache:
        - decode 15.7 / 15.6 / 15.9 tok/s over 128 predicted, three runs,
          `cache_prompt:false`;
        - prefill 93-94 tok/s over 601 prompt tokens, 30-32 over 23;
        - an agent-shaped turn, 18 tokens in and 161 out, decoded at 15.9 tok/s.

        Rejected on two counts. It is a third of the 50 tok/s bar, and it is also
        below Strata's 19.4 tok/s agent session, so it displaces nothing even if
        the bar is set aside. Nor is it a tuning miss: ~3 B active parameters at
        Q4_K_M is ~1.7 GB of expert weights per token, and 25.6 GB/s of DDR3-1600
        divides into ~15 tok/s. 50 tok/s needs about three times this board's
        bandwidth, which is a hardware change rather than a flag.

        Exit: a decode rate above 50 tok/s on this box, or the note stays
        REJECTED. The file stays on disk for a retest, nothing is imported, and
        Strata keeps :8085.
      '';
    };
    doc-budget-ci = {
      title = "Doc budget gate in CI";
      kind = "open";
      status = "CLOSED";
      priority = "P0";
      date = "2026-11-19";
      summary = "A doc-only push allocated zero runners and gated nothing; the `docs-budget` CI job now runs the same check as `task ops:docs:budget`, proven on a `*.md`-only push (run 44540530585 at `fede3c1b`).";
      refs = {
        modules = [".github/workflows/nixcachix.yml" "scripts/task/docs-budget.sh"];
        tasks = ["ops:docs:budget"];
        docs = [".agents/SCHEMA.md" "docs/ci-pipeline.md"];
      };
      body = ''
        Closed 2026-11-19. A `*.md`-only push (`fede3c1b`, `docs/ci-pipeline.md`)
        ran `docs-budget` green in 51 s while `build-machines` and `boot-canary`
        were skipped — run 44540530585 — so the gate now fires on exactly the
        push that allocates no runner.

        The job's later steps cover what the script cannot. `docs-budget.sh`
        skips `.agents/skills/*` on purpose (their bodies are `lib/skills.nix`'s
        to compile and `flake/prose-budget.nix`'s to bound), and `checks.policies`
        compares that record through `agent-prose-budget` — it joined the job on
        2026-11-17, so a skills-only edit is gated without a host build. Beside
        it: `prose-tells` for vocabulary, `taskfile-graph` and `nix-comments` for
        pointers, module edges for imports.

        Why a gate exists here at all: no `if:`, no path filter, and
        `concurrency` per ref — a run superseded within seconds is cancelled, so
        the newest commit on the branch is the one that must be green.
      '';
    };
    dormant-host-gates = {
      title = "Dormant host gates — minyx and cassini";
      kind = "open";
      status = "IN FLIGHT";
      priority = "P0";
      date = "2026-11-19";
      summary = "`minyx`'s `boot.kernelPackages` collision is fixed (`mkOverride 1200`). `cassini`'s darwin chain is being repaired: the module-shape and Linux-option faults are landed and a Linux host still gates, the third fault is an infinite recursion in the home role.";
      refs = {
        hosts = ["minyx" "cassini"];
        modules = ["modules/global/macos.nix" "modules/global/linux-systemd.nix" "modules/global/global.nix" "flake/module-sets.nix" "modules/roles/home.nix" "modules/profiles/base-node.nix" "modules/user/ai/freebuff-remote.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        `cassini`'s stated blocker was stale: `modules/user/ai/freebuff-remote.nix`
        already gates `xdg` on `isLinux`.

        2026-11-19, `ALLOW_PRESERVED=1 task checks:host HOST=cassini MODE=eval`
        (1.9 s to reach the head of the chain). Two faults are cleared and landed:

        1. `modules/global/macos.nix` moved `home-manager`, `nix-homebrew` and
           `users` under an explicit `config`; nix-darwin's checker rejects them at
           module top level.
        2. `modules/global/linux-systemd.nix` carries `systemd.oomd`,
           `systemd.timers` and `services.journald`, imported by the `nixos`,
           `containers` and `demo` features only — never by `base` or `macos`.
           `lib.mkIf` could not do this: `pushDownProperties` rewrites
           `services = mkIf c { journald… }` into `services.journald = mkIf c`, so
           the missing-option check runs with the condition false. Measured twice,
           both gating attempts reverted.

        Third fault, now the head: infinite recursion while evaluating
        `modules/roles/home.nix`, module argument `dankShell` — the darwin chain
        provides no such argument, and the role's `fleet.hmUserFeatures` default
        includes `desktop`. Hypothesis to test next: darwin's feature list must not
        include `desktop`, or `dankShell` needs a darwin default.

        Gates so far: `checks:host HOST=netbook` green in 10.2 s after the split, so
        the move did not change a Linux host. cassini is still red at fault 3.

        Exit: a green (or explicitly expected-red) `checks:host HOST=<one>
        MODE=eval`, run by the owner when the hardware is powered on. Verification
        of a dormant host is the owner's call, never an agent's drive-by eval.
      '';
    };
    dns-second-resolver = {
      title = "DNS failover — a second always-on resolver";
      kind = "open";
      status = "BLOCKED";
      priority = "P1";
      date = "2026-10-19";
      summary = "One resolver is a single point of failure. The module and the check exist; the blocker is hardware, not code.";
      refs = {
        modules = ["modules/net/dns/failover.nix" "hosts/frieren/dns.nix"];
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
      body = ''
        Exit: `checks:dns:failover` exits 0 (not 2); stopping frieren's resolver leaves clients resolving. `BLOCKED` names the blocker: no second always-on node is provisioned.
      '';
    };
    steamlink-ble-vantage = {
      title = "Steam Link as a 2 W living-room sensor and power gate";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-11-11";
      summary = "The living-room Steam Link cannot host a service, but at 2 W it is the one host that can stay awake to sense the room and gate a 300 W eisen — and the pieces (BLE scan, CEC standby, ether-wake) are already on the device.";
      from = ["dns-second-resolver"];
      links = ["mqtt-bus" "pi-eisen-ondemand"];
      refs = {
        modules = ["modules/services/home-assistant.nix" "modules/services/fleet-monitors.nix"];
      };
      body = ''
        Measured 2026-11-11 over `ssh root@192.168.3.48`: one ~1 GHz ARMv7 core, 269 MB RAM with 127 MB free,
        yaffs2 read-only root (1.8 G scratch, 131 M `/tmp`), 100 Mbit wired, no RTC, no cron, no compiler.
        Settled: not a resolver and not a cache (12.5 MB/s, 1.8 G); the asset is 2 W. It is also the one home
        device absent from `inventory.toml` — `kind = "external"` with `is_nix`/`managed = false` is the gokrazy shape.

        **The jitter is the path, not the host — and it is queueing, not loss.** 5 GHz -> 2.4 GHz -> powerline ->
        2.4 GHz backhaul, bridged, so `tracepath` reports one hop and no intermediate IP can be blamed. 0% packet +
        loss everywhere, a ~10 ms floor and 100-700 ms peaks in both directions (box -> gateway averages 103 ms
        while frieren -> gateway is 0.58), so minutely sensing does not read it and the LLM door stays on eisen.

        **Already on the device.** `bin/wake-eisen` sends `ether-wake` to eisen's `00:e0:22:1c:bb:ed`;
        `bin/cecmanager` links `libDMPCECSrv.so` and exposes HDMI port select plus standby status, so the TV is
        controllable without `/dev/cec*`; `hci0` is UP under BlueZ 5.47 and an 8 s `lescan` returned 146
        advertising reports; `bluealsa` runs. Nothing here needs writing from scratch — it needs wiring.

        **Ranked, by value per watt.**
        1. Power gate: CEC standby plus no BLE presence for 20 min plus no live stream -> power eisen off.
           300 W x 4 idle hours a day is 438 kWh/yr against the Link's 17.5 kWh/yr for the whole year.
        2. Publish that presence to Home Assistant from the floor the basement cannot see (the MQTT bus' first client).
        3. CEC: controller connects or TV powers on -> wake eisen and select its HDMI port.
        4. Room-side latency, probed from frieren (inside the LAN, against the 0.58 ms gateway baseline) — never
           from delphi: a cloud pull crosses WAN + tailnet + the same mesh, so it cannot be differenced, and the
           module has no push endpoint to let the box report in itself.

        **The trap.** `pi-eisen-ondemand` says nothing should auto-sleep a gaming desktop. A sensor-driven sleep
        is not a timer, but it must refuse while a stream, generation or SSH session is live, and start as
        notify-only. It answers over ssh and the UI cannot power it off, so it goes down only at the wall.

        **Exit.** Two weeks of notify-only decisions that match what a human would have done, then the poweroff
        path; or REJECTED if eisen is already asleep whenever the room is empty.
      '';
    };
    ytcast-oled759-live-stream-wedge = {
      title = "Playing anything on the 65OLED759: UPnP renderer on 49152, YouTube by Lounge";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-11";
      summary = "The set has no Cast receiver and answers no SSDP, but port 49152 is a UPnP MediaRenderer: SOAP AVTransport plus a Jellyfin DLNA URL plays any library file. YouTube works through Lounge (`ytcast -pair`), VOD only — a live stream wedges the app into ambient mode and nothing on the network recovers it.";
      links = ["steamlink-ble-vantage"];
      refs = {
        tasks = ["ytcast"];
      };
      body = ''
        **The TV.** Philips 65OLED759/12 at 192.168.3.26, Titan OS (`titanos.local`). It advertises
        `_philipstv_s_rpc._tcp`:1926, jointSPACE:1925 and `_secure-mqtt._tcp`:8883 — no `_googlecast._tcp`,
        no `_dial._tcp`, nothing on 8008/8009 — no Cast receiver. Port **49152** is the way in.

        **Any local file, via DLNA.** A direct GET is the only way to find it: `curl http://192.168.3.26:49152/description.xml`
        returns `urn:schemas-upnp-org:device:MediaRenderer:1` (DMR-1.50) with AVTransport at `/avt_control`, while an SSDP
        M-SEARCH to the set gets zero replies, so every discovery tool concludes there is no renderer. Verified 2026-11-11:
        browse Jellyfin's ContentDirectory (`/dlna/<uuid>/contentdirectory/control`, library `arr`), take the item's `res`
        URL, then SOAP `SetAVTransportURI` + `Play` on `http://192.168.3.26:49152/avt_control` — transport went PLAYING with
        `dur=1:38:40`. Serving from frieren on a new port does not work: the firewall drops it and the set retries to STOPPED.

        **Why casting still works.** `ytcast -pair <code>` redeems the app's TV code through
        `https://www.youtube.com/api/lounge/pairing/get_screen` and caches a screen id; playback is then
        cloud-relayed via `POST /api/lounge/bc/bind`. Port 8009 is never touched.

        **What wedges it.** A live stream (2026-11-11, `jfKfPfyJRdk`): the app dropped to ambient mode and
        answered nothing afterwards, and a VOD cast from the same session vanished too — exit 0 both times,
        because Lounge accepts what the TV never hears. Recovery needs a physical key press: `/6/input/key`,
        `/6/powerstate` and `/6/pair/request` all return 403 on this set, and the Steam Link's `cecmanager`
        has no CLI and is not running.

        **Rule.** VOD only, one cast at a time, and opening the YouTube app is the last step: a cast is
        queued, not raised — 2026-11-11, `ytcast` returned 0 while Bloomberg TV was on screen and the video
        played the moment the app was opened by hand, so nothing on the network opens it. Stopping the DMR
        hands the set back to the previous input, which makes `media:stop` restore the channel that was on. The `ytcast` task allows only
        `not_live`/`was_live` and refuses anything it cannot classify — the first guard failed open on
        `jfKfPfyJRdk`, where yt-dlp errors instead of reporting `is_live`. Pair again when a cast goes silent.
      '';
    };
    resolver-independence = {
      title = "Resolver independence for clients + health gate";
      kind = "open";
      status = "OPEN";
      priority = "P1";
      date = "2026-10-19";
      links = ["dns-second-resolver"];
      summary = "Clients still depend on one resolver. Client-side fallback and a health probe can ship before a second server exists.";
      refs = {
        modules = ["modules/net/dns/failover.nix"];
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
      body = ''
        Measured 2026-10-22: there is NO secondary. `55c1477c` (2026-10-15) removed
        pihole-ftl, unbound and dns-failover from fern, and `docs/dns-failover.md`
        kept claiming fern was the second member until this pass corrected it.
        `rg 'role = "secondary"' hosts/ modules/` returns nothing, `checks:dns:failover`
        exits 2, and frieren is the only answer for `*.frieren.lan` AND for the LAN
        service records it carries (`eisen.lan`, `laya.lan`, `tts.lan`). delphi does
        answer the shared address, but with crab-hole, which cannot hold a zone: it
        NXDOMAINs every `.lan` name even though the hosts behind them are up.

        The dependency worth removing first is the ZONE'S SINGLE HOME, not the data
        plane: losing frieren makes hosts that are still up (`eisen.lan`,
        `laya.lan`) unreachable by name, and that is the cheapest to fix because
        delphi is always-on and already a resolver — the missing piece is static
        records (a dnsmasq front, or split DNS), not hardware. Second: hand every
        client both resolvers (router DHCP, or `networking.nameservers`, which only
        aristotle sets today).

        Half-met 2026-11-24: `profiles.dnsClient` (exp-104) consolidates the
        client half — aristotle, diogenes and eisen now declare VIP + tailnet +
        public fallback in one option set — and `checks:dns:resolver-health`
        plus the gatus `dns://` endpoint on delphi (exp-105) probe the resolver
        as a service. Still open: the zone's second home — the delphi
        dnsmasq-front / split-DNS piece that answers `.lan` when frieren is
        down; public names are the covered half.

        Exit: a client with frieren down still resolves public names; `checks:dns:resolver-health` reproduces it.
      '';
    };
    mqtt-bus = {
      title = "MQTT bus — first publisher/subscriber";
      kind = "open";
      status = "BLOCKED";
      priority = "P1";
      date = "2026-10-19";
      links = ["exp-007" "exp-014" "exp-015"];
      summary = "The broker is declared but has no subscribers. Home Assistant needs one UI config-entry action; no YAML/import path exists.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
        tasks = ["checks:ha:mqtt"];
      };
      body = ''
        Exit: `checks:ha:mqtt` reports an established subscription. Then EXP-014/015 can follow (see `exp-014`, `exp-015`).
      '';
    };
    restic-drill-through-unit = {
      title = "Run the restore drill through its unit";
      kind = "open";
      status = "OPEN";
      priority = "P1";
      date = "2026-10-19";
      links = ["exp-111"];
      summary = "The restic drill has only ever been run by hand. A green timer run is the proof that the unit (and its credentials) work.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
      };
      body = ''
        Exit: one green `restic-drill.service` run and a snapshot id in the ledger.
      '';
    };
    sentinel-external-hosts = {
      title = "Sentinel `unit-failed` for external hosts";
      kind = "open";
      status = "DELIVERED";
      priority = "P1";
      date = "2026-10-19";
      summary = "On non-NixOS hosts the field is `absent`, which can read as success. It must never claim a unit it cannot see.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix"];
        tasks = ["ops:health"];
      };
      body = ''
        Landed 2026-11-19. The collector probes `/run/systemd/system` once per run,
        records `unit_observer` (`systemd` | `none`) in every event, and on a host
        with no manager answers `unobservable` for each watched unit while adding
        one `unit-status-unobservable` reason — `degraded`, never `ok`. `absent`
        now means only "not installed on this host" and stays neutral, which is
        what a never-run restic drill relies on. `failed_units` follows the same
        rule: `null` on a blind host rather than `[]`, because an empty list
        claims a scan that never ran.

        The probe is the directory, not `command -v systemctl`: systemd's binaries
        come from the collector's own runtimeInputs closure, so a nix-darwin or
        container host has them on PATH and only the directory proves a manager is
        there to answer.

        Gate: `task checks:host HOST=frieren` and `task checks:quick`.
      '';
    };
    semantic-search = {
      title = "Semantic search only if it earns its keep";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-04";
      summary = "BM25 is instant and good enough until measured misses say otherwise — so the lexical gate shipped (`ops:wiki:ask`, 0.62/0.38, verdict log) and the rerank was rejected on that basis: 740 MiB of closure to rerank eight candidates buys paraphrase recall, which relaxation may supply for free.";
      refs = {
        modules = ["modules/scripts/wiki-ask.py" "modules/services/kiwix.nix"];
        tasks = ["ops:wiki:ask" "dev:qmd:refresh" "checks:qmd:docs"];
      };
      body = ''
        Built 2026-11-04: `modules/scripts/wiki-ask.py` behind `task ops:wiki:ask`,
        on frieren where the ZIMs live. Benchmark = every `## Claim` in the vault
        run verbatim (141): 1 supported, 22 expand, 118 silent — 0.7%, 83 tokens
        once `expand` stopped quoting (22/22 of its passages were unrelated: a SOPS
        claim quoted "Victoria's Secret"). Specialist shelf, not an oracle.

        The index was never the problem: `wikisearch "btrfs scrub repair EIO"` returns
        one hit, F2FS, because Xapian ANDs its terms, returns ten titles and no text,
        and `kiwix-search -s` costs 6-13 s on the 19M-article ZIM. The gate is
        0.62 / 0.38 and every verdict appends to ~/.local/state/wiki-ask/verdicts.jsonl,
        so "which misses matter" is a query rather than an argument.

        NO RERANK (operator call, 2026-11-04): the tool is the lexical fan-out, not
        a model in front of it. An embedding index over 19M articles is impossible
        (19M x 384 float32 ~ 29 GB) and a local ONNX path is a 740 MiB closure plus
        90 MB of weights to rerank eight candidates — buying paraphrase recall that
        better relaxation may supply for free.

        The job is not retrieval, it is BELIEF REPAIR: an agent checks a claim it is
        confident about, and the shelf either supports it or says nothing. Silence
        is not disagreement — a frozen 2026-06 archive cannot falsify a 2026-11
        change, so only stable facts (formats, defaults, attribution, history).
        DIRECTION: structural facts calcify into `.#knowledgeGraph`; a pass that can
        only produce prose stays a tool with a kill date, never a rung to consult.

        KILL CRITERION FIRED 2026-11-19: 456 verdicts, all written on the build
        day, none in 14 days. `ops:wiki:stats` now reads that from the log (exit 1
        on an empty window); the delete itself is the operator's call.
      '';
    };
    epistemics-declared = {
      title = "Which source may settle a claim is declared, not scored";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P1";
      date = "2026-11-04";
      from = ["semantic-search"];
      summary = "A retrieval score measures word overlap, not authority. Sources now declare which claim kinds they may settle, whether a snapshot can speak about a moving fact, and who is accountable — compiled in flake/epistemics.nix, so the go/no-go costs one leaf read and no tokens.";
      refs = {
        modules = ["flake/epistemics.nix" "modules/scripts/wiki-ask.py"];
        tasks = ["ops:claim:check" "ops:wiki:ask"];
      };
      body = ''
        The 141-claim benchmark was read as a ranking failure for one turn; it is
        a category error. Those claims are `personal-method`, which no encyclopedia
        article can settle. ``nix eval --json .#epistemics.table | toon -e`` answers
        that before a search, in a document an agent can act on.

        A source is an AUTHORITY: `settles` (kinds it may settle — absence is a
        refusal, never a low score), `standing` (authored > snapshot > unvetted),
        `volatility` (may it speak about a moving fact). A ROUTE is a transport to
        it: `cost` in tokens, `offline`, `metered` (whose quota), `fanout` (may it
        be asked many times at once). Cheap first, and a search engine is a route
        to `web`, never an authority of its own — SearXNG on delphi:8447 is the
        unmetered fan-out route, one `web_search` is not.

        `spend` is a MEASURED p per (source, kind) and `ev` is
        flake/daemons.nix's Kelly expression, reused rather than restated. The
        0.7% above is now ev -242.65 against 250 tokens: the arithmetic that would
        have saved 140 runs. An unmeasured p is null, never invented.

        `persist` per kind says where a settled answer is filed, which is what
        makes the ladder cheaper over time instead of a treadmill.

        Measured: `.#epistemics.table` 0.1 s; `checks.<system>.epistemics` proves
        every `settles` entry resolves, every kind is settled and persistable,
        every route is labelled, and the Kelly sign is right in both directions.
        A permitted source that returns nothing does not falsify the claim:
        permission is not coverage.

        Open: the vault's claim schema carries `status` but no `kind`, so the
        kinds are authored per check instead of read from the zettel. Until it
        does, `ops:claim:check` asks the caller rather than guessing from text.
      '';
    };
    closure-budget-coverage = {
      title = "Closure budgets for every measured host";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-19";
      links = ["exp-110"];
      summary = "Adoption works locally and over ssh for a named set, but only frieren carries a measured baseline. The rest are blocked on the hosts being online.";
      refs = {
        modules = ["closure-budgets.toml"];
        tasks = ["dev:closure:budget:adopt" "dev:closure:budget:adopt:hosts"];
      };
      body = ''
        Exit: 11 of 11 active Nix hosts carry a measured baseline and the budget gate is green.
      '';
    };
    ci-closure-budget = {
      title = "CI closure budget gate";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-19";
      links = ["closure-budget-coverage"];
      summary = "The budget check needs a built toplevel to compare against; CI does not build one yet.";
      refs = {
        modules = [".github/workflows/nixcachix.yml" "closure-budgets.toml"];
      };
      body = ''
        Exit: the job fails when a host closure exceeds its measured baseline.
      '';
    };
    transitive-flake-drift = {
      title = "Transitive flake drift";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-19";
      summary = "A root `nix flake update` misses branch-following pins (impermanence/nixpkgs, dms/dank-qml-common). Batches with a host gate are safer than a weekly everything-update.";
      refs = {
        modules = ["flake.lock"];
        tasks = ["dev:flake:update-transitive"];
      };
      body = ''
        Exit: one PR per batch, representative host gate per chain.
      '';
    };
    mosquitto-auth = {
      title = "Mosquitto auth before the first device";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-19";
      summary = "An anonymous LAN listener is the easy version and the wrong one. When the first real device arrives, add `passwordFile` from sops.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
      };
    };
    zigbee-coordinator = {
      title = "Zigbee coordinator when the dongle exists";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-19";
      summary = "The dongle is not in the fleet. When it is, set the serial port by `/dev/serial/by-id`, never `/dev/ttyUSB*`.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
        docs = ["modules.toml"];
      };
    };
    backlog-remote-gpu = {
      title = "Backlog — remote GPU inference";
      kind = "open";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-10-19";
      links = ["exp-018"];
      summary = "Offload a burst to hosted capacity instead of buying VRAM for a desktop that idles most of the day. Depends on eisen stability and a budget line; not scheduled.";
      body = ''
        The idea is to send a burst to hosted GPU/TPU capacity instead of sizing every
        host for the worst case. Two preconditions are not true yet: eisen has to be the
        stable local baseline, and metered inference needs a budget the operator has
        agreed to. Until both exist the answer stays local. Do not wire it as a silent
        fallback in the router — a paid remote that activates on a timeout is a billing
        bug, not a feature. Nothing is scheduled.
      '';
    };
    backlog-simplex-mesh = {
      title = "Backlog — SimpleX agent mesh and message classifier";
      kind = "open";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-10-19";
      links = ["exp-049" "exp-064"];
      summary = "Inter-agent coordination exists as a skill over a single daemon; a routed mesh with a message classifier is not scheduled.";
      body = ''
        Today agents talk to one SimpleX daemon with explicit commands. The proposal
        is a mesh where each host agent can be addressed and a classifier routes an
        inbound message to the right agent. The blocker is behavioural, not transport:
        a classifier that misroutes a destructive instruction is worse than no mesh.
        It needs a labelled message set and an accuracy target before it is worth
        building. Pair it with the decision models rather than a new LLM call. Not
        scheduled.
      '';
    };
    backlog-dns-anycast = {
      title = "Backlog — DNS VRRP/anycast";
      kind = "open";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-10-19";
      links = ["exp-076" "dns-second-resolver"];
      summary = "A shared VIP or anycast address for resolvers. It only reduces failure once a second resolver exists, so it is downstream of the DNS work.";
      body = ''
        Anycast or a VRRP shared address looks like high availability but adds a
        second failure mode if there is still one real resolver behind it. The fleet
        has one always-on resolver (frieren); the failover work is blocked on a second
        node. Build anycast only after that node exists and clients already point at
        both addresses. Measured first: a VIP that fails over in 30 s is worse than a
        client list that retries in 2 s. Not scheduled.
      '';
    };
    backlog-offsite-restic = {
      title = "Backlog — offsite restic replica beyond BurgerNAS";
      kind = "open";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-10-19";
      links = ["exp-090"];
      summary = "BurgerNAS is the cold vault; a third, geographically separate replica is not scheduled.";
      body = ''
        The current backup story is frieren -> BurgerNAS (cold vault) plus a local
        repository. That covers disk loss and accidental deletion, not site loss. A
        third replica needs a destination outside the house and a key story that
        does not put both copies behind the same sops file. The cost is a recurring
        one, so it is an operator decision, not an agent one. Do not pick a provider
        before the restore drill is green (see restic-drill-through-unit). Not scheduled.
      '';
    };
    backlog-btrfs-scrub = {
      title = "Backlog — btrfs scrub throttling";
      kind = "open";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-10-19";
      links = ["exp-095"];
      summary = "Scrubs saturate the NAS for hours; throttling is only worth changing once a scrub has been measured under real load.";
      body = ''
        A monthly btrfs scrub on the 14.6 TB array is I/O-heavy and runs on the same
        host as serving. The proposal is to cap its bandwidth (cgroup io.max or
        ionice) so a scrub cannot starve restic or the media servers. The honest
        sequence is measure first: record the next scrub's duration and PSI while it
        runs, then decide whether a cap buys anything or just makes the window longer.
        No change is scheduled before that measurement.
      '';
    };
    queue-rules = {
      title = "Queue rules — how an item moves";
      kind = "handoff";
      status = "DELIVERED";
      date = "2026-10-19";
      links = ["handoff-live-host-file"];
      summary = "One outcome per note, a named blocker for `BLOCKED`, and no design prose in a queue row.";
      refs = {
        docs = [".agents/SCHEMA.md"];
      };
      body = ''
        1. One outcome per note. Two exit criteria means two notes.
        2. `BLOCKED` names the blocker (hardware, a UI action, a second node) — not "investigate".
        3. A paragraph longer than three lines is design, not queue: it goes in the note body, not the summary.
        4. Promotion: PROPOSED -> ACCEPTED -> IN FLIGHT -> DELIVERED (with a path) -> removed from the open set.
        5. The nightly host audit writes `~/HANDOFF.md`; only a human or agent promotes a finding into this file.
      '';
    };
    handoff-live-host-file = {
      title = "The live host handoff is not this file";
      kind = "handoff";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "`~/HANDOFF.md` is live host state written by `agy-nightly-*` on frieren. It is transient and local; only promoted findings belong in AGENTS.nix.";
      refs = {
        tasks = ["ops:health"];
      };
    };
    handoff-closed-2026-10 = {
      title = "Closed in the 2026-10 cycle";
      kind = "handoff";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "The queue items that landed this cycle; the xs turn log keeps the dates.";
      refs = {
        modules = ["lib/home-agents.nix" "lib/knowledge-graph.nix" "modules/profiles/nas-client.nix"];
        docs = [".agents/SCHEMA.md"];
      };
      body = ''
        - Home `AGENTS.md` -> `.#homeAgents.<host>`; activation links the store path.
        - Context plane mk2 (compiled skills, schema, graph).
        - Sentinel closed loop on frieren.
        - Doc taxonomy + budgets.
        - Restic password -> sops + BurgerNAS target.
        - NAS path governor.
        - HC-1/2/4/6/7/8 implementation wave (see docs/history/handoff-2026-10.md).
      '';
    };
    open-parakeet-hardening = {
      title = "Harden the Parakeet STT service";
      kind = "open";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-10-19";
      summary = "The STT server decodes untrusted audio as root with no sandbox, no idle stop and no start limit.";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/parakeet.nix" "hosts/eisen/parakeet-server.py" "hosts/eisen/parakeet-transcribe.py"];
        docs = [".agents/deploy/hosts/eisen.md"];
      };
      body = ''
        Found while reviewing the 2026-10-17 parakeet module (not yet in a switched generation):
        - ~1 GB stays resident while idle. The warm-up is one HTTP POST, so socket activation or an idle stop is the cheap fix.
        - The unit runs as root with no `ProtectSystem`/`PrivateTmp`/`MemoryMax`, yet hands untrusted audio to ffmpeg.
        - `Restart=always` with no `StartLimit*`: missing weights crash-loop instead of failing visibly.
        - The HTTP handler has no read timeout, so a stalled upload holds a thread.
        - `--threads 8` is deliberate for this CPU budget; do not "fix" it without a benchmark.

        Exit: a bounded unit (user, sandbox, memory cap, start limit) that still answers `POST /transcribe`
        with 200 and returns 413 above the 25 MB cap. The keep-alive body-drain fix already landed in
        `parakeet-server.py`.

        Delivered 2026-11-20 (commits 6cb73ec9 + 422ad47d; eisen woken by `infra:wol:eisen`):
        - DynamicUser + ProtectSystem=strict/PrivateTmp/MemoryMax=2G had already landed (28fe7729);
          the unit is unchanged there except `Restart=always` → `on-failure` (a clean idle exit must
          not resurrect the service) and `wantedBy` dropped — the service is socket-activated now.
        - `parakeet-stt.socket` holds 127.0.0.1:8091 (Accept=no); the server takes the inherited fd
          via LISTEN_FDS/LISTEN_PID, so a connection cold-starts the service (~50 s first hit).
        - `--idle-timeout 900` exits the service cleanly; watchdog measured by hand at 20 s.
        - Upload reads are bounded by a total 120 s deadline (a per-recv timeout alone does not
          stop a drip). `--threads 8` untouched.
        Verified live: socket-listener + dead service = 0 B resident vs 1.05 GiB before; POST
        /transcribe → 200 through the cold start; 26 MB body → 413; 200 B/s drip → 400 "timed out"
        at 120 s. Gate: `checks:host HOST=eisen` 2067 assertions; switch landed on eisen and is the
        boot default (/run/current-system = b8mn7c9…-eisen-26.11.20261116.e21fec3).
      '';
    };
    open-eisen-gpu-off-bus = {
      title = "eisen's RX 5700 is off the PCIe bus";
      kind = "open";
      status = "DELIVERED";
      priority = "P1";
      date = "2026-10-19";
      summary = "The RX 5700 dropped off the PCIe bus between poweroffs (no /dev/dri, no firmware enumeration). Fixed by a PSU cold cycle: 05:00.0 re-enumerated, greetd and gamescope are back. Not the build, not OOM.";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/configuration.nix"];
        docs = [
          ".agents/deploy/hosts/eisen.md"
          "docs/eisen-llm-architecture.md"
        ];
      };
      body = ''
        Healthy in the 2026-10-18 21:31 boot (`amdgpu 3.64.0`, DCN 2.0, 6 planes, fb0,
        50 min of greetd/gamescope) and gone from 2026-10-19 13:43 onward: firmware never
        enumerates `0000:05:00.0`, the x16 root port `0000:00:02.0` is not exposed,
        `/sys/class/drm` holds only `version`, `amdgpu` logs only `Topology: Add CPU node`.

        Not OOM and not the build: no `Out of memory`/`oom-kill` line since 2026-10-18
        20:00, and the desktop ran until the poweroff. `max-jobs = 8` is live now.

        `pci rescan` and a link retrain fail, and the x16 port has no hotplug slot
        (`Slot-`), so there is no software power cycle: the link is `Width x0` /
        `PresDet-`. Recovery is physical — PSU power off (standby keeps the rail
        latched), check the 8-pin PCIe power, reseat the card. That cold cycle at
        16:43 brought `05:00.0` back, amdgpu initialised, `/dev/dri/card1` returned,
        greetd started gamescope and Steam. Re-run the Kolibri benchmark afterwards:
        `--n-gpu-layers 99` was inert (llvmpipe) while the card was gone.

        Recurred on the 2026-10-22 21:32 boot after 22 h in S5 (again not a cold cycle).
        The x16 port moved to `0000:00:03.0`, still `LnkSta Width x0` / `DLActive-`, and
        the NIC renumbered `09:00.0 enp9s0` → `06:00.0 enp6s0`, so the name-keyed WoL
        declaration matched nothing (`Wake-on: d`). Same chain: greetd's `steam`
        autologin dies on gamescope `Failed to initialize Vulkan` with llvmpipe only,
        the greeter exits, Steam never listens, Steam Link gets no discovery reply —
        UDP/27036 arrivals were still counted, so the network path was never at fault.

        The same PSU cold cycle recovered it at 21:53 (rescan did nothing): `05:00.0` as
        NAVI10, `card1` + `HDMI-A-1` at 1920x1080, `RADV NAVI10`, Steam on UDP/TCP 27036,
        and the NIC back at `enp9s0` so `Wake-on: g` re-applied.
      '';
    };
    nix-binary-upgrade-2026-10 = {
      title = "Nix binary upgrade: stay upstream, move the pin to 2.35.3+";
      kind = "decision";
      status = "SUPERSEDED";
      priority = "P1";
      date = "2026-10-19";
      summary = "The fleet's Nix 2.35.2 was affected by the 2026-10-13 local-root advisory; the pin moved to 2.35.3. Its 'no Determinate Nix fleet-wide' clause was superseded the same day by decision-determinate-nix-fleet.";
      refs = {
        modules = ["modules/global/global.nix"];
        docs = [".agents/deploy/hosts/eisen.md"];
      };
      body = ''
        Nix 2.35.2 — what the pinned nixpkgs (`47addd76`, 2026-10-05) ships through
        `nix.package = nixVersions.latest` — is affected by the 2026-10-13 advisory: a
        heap out-of-bounds write while evaluating untrusted expressions, store-path
        repair tampering and a macOS Seatbelt escape, chainable to local root. Fixed in
        upstream 2.35.3 / Lix 2.95.4. `nix-2.35.3` is already on cache.nixos.org for
        x86_64-linux, aarch64-linux and aarch64-darwin, so the upgrade compiles nothing.

        Decision: stay upstream and move the pin to >= 2.35.3. Rejected alternatives:

        - Determinate Nix 3.23.3 (2026-10-16, LGPL-2.1, based on 2.35.3) fixes the
          advisory and adds parallel evaluation, lazy trees, `nix ps` and OTel tracing.
          Rejected for the fleet: NixOS installs it through its own module/ISO,
          `determinate-nixd` upgrades imperatively and owns `/etc/nix/nix.conf`, and its
          nix-eval-jobs is a separate fork — three things that fight a declarative fleet
          whose flake pin is the rollback unit.
        - Lix: nixpkgs still carries 2.95.3 (pre-fix), and 2.96 accepts flakes upstream
          cannot evaluate (flake validation change) — a one-way door for a repo shared
          with CI. 2.97 removes `ssh://` store URIs, which
          `scripts/task/closure-analysis.sh` uses for every `HOST=` read.

        Ruling (owner, 2026-10-19): land it as a full flake update, not a `nix.package`
        pin. A new Nix binary invalidates the store paths anyway, so the fleet should
        move to one nixpkgs instead of sitting on two.

        Superseded 2026-10-19: the pin did move (nixpkgs `f20cd90e`, Nix 2.35.3), and
        the 'stay upstream' half stands — but the Determinate Nix rejection did not
        survive its own trial. eisen ran DN 3.23.3 for a session with a 0-build switch
        and a generation rollback, which is the two things the paragraph above said
        were disqualifying. The fleet-wide ruling is now
        `decision-determinate-nix-fleet`.
      '';
    };
    open-flake-bump-2-35-3 = {
      title = "Full flake update landed: nixpkgs f20cd90 brings Nix 2.35.3";
      kind = "open";
      status = "DELIVERED";
      priority = "P1";
      date = "2026-10-19";
      summary = "The pin moved 2026-10-05 -> 2026-10-16 in one flake update; nixVersions.latest is now 2.35.3, the release with the 2026-10-13 local-root fixes. Three chain representatives evaluated on eisen, darwin unchecked (no active host).";
      refs = {
        hosts = ["eisen"];
        modules = ["modules/global/global.nix"];
        docs = [".agents/deploy/hosts/eisen.md"];
      };
      from = ["nix-binary-upgrade-2026-10"];
      body = ''
        Rehearsed and landed from eisen (24c/59 GiB), never frieren: `nix flake update`
        moved 20 input nodes — nixpkgs `aa48d347` -> `f20cd90e`, nix-darwin,
        home-manager, sops-nix, nixos-hardware, nixvim, dms/dank-greeter, llm-agents,
        zen-browser and their locked deps.

        Result: `nixVersions.latest` = 2.35.3 (12.9 s leaf eval incl. the input fetch),
        and `nix build .#hostChecks.x86_64-linux.eisen --builders ""` passes 1992
        assertions in 42.5 s. No remote builder was reachable from that command, so the
        rehearsal could not spend nixbuild.net budget.

        Landed 2026-10-19 as a full flake update (owner ruling): the lock pins nixpkgs
        `f20cd90e`, and chain representatives pass on eisen — eisen 1992 assertions,
        guckloch 1699 (13.1 s), kali's home activation drvPath (45.5 s). No active darwin
        host exists (cassini is preserved), so that chain is unchecked until CI sees it.
        `fleet-warm-cache` absorbs the closure delta on its weekly run.
      '';
    };
    decision-determinate-nix-fleet = {
      title = "Determinate Nix fleet-wide (reverses the 2026-10-19 rejection)";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P1";
      date = "2026-10-19";
      summary = "Every NixOS chain imports one Determinate Nix module: one Nix binary fleet-wide, switch by generation, DN's cache pre-trusted so nothing compiles. Supersedes the 'stay upstream' half of nix-binary-upgrade-2026-10.";
      refs = {
        modules = [
          "modules/global/determinate-nix.nix"
          "modules/global/global.nix"
          "flake/module-sets.nix"
          "flake.nix"
        ];
        docs = [".agents/deploy/README.md"];
      };
      from = ["exp-determinate-nix-trial"];
      supersedes = ["nix-binary-upgrade-2026-10"];
      body = ''
        The 2026-10-19 rejection named three disqualifiers: an imperative upgrader,
        ownership of `/etc/nix/nix.conf`, and a forked nix-eval-jobs. The trial refuted
        the ones that mattered operationally: `nix.package` stays declarative (DN's
        module sets it), our settings land in `nix.custom.conf` rather than being
        dropped, and rollback is `nixos-rebuild --rollback switch` because the store
        format is unchanged. The remaining fork is not on any fleet path.

        Shape: `modules/global/determinate-nix.nix` is imported by
        `globalModulesNixos`, `globalModulesContainers` and `globalModulesDemo` — the
        three NixOS chains — and by nothing else. `globalModulesImpermanence` inherits
        it through `globalModulesNixos`.

        Three things the module has to hold, each a trap found on eisen:
        - `nix.package`: DN defines it at priority 100, so a plain fleet definition is
          a conflict. `global.nix` uses `mkDefault`; DN wins, and a host can still opt
          out by defining it at normal priority.
        - `nix.registry.nixpkgs`: DN points it at FlakeHub weekly with `exact = true`.
          `to` is forced back to this flake's pin, because the pin is the rollback
          unit and must not drift under a rebuild.
        - `install.determinate.systems`: DN is not on cache.nixos.org. The key is in
          the module AND in the flake's `nixConfig`, so CI and the builder substitute
          DN instead of compiling 54 derivations.

        Out of scope by design: microVMs (`testvm`, `frieren-canary`) and
        `garnixMachine` build their own module lists, and the darwin/home chains are
        not NixOS hosts. Bootstrap: the first switch that adds DN must pass
        `--option substituters https://install.determinate.systems` on the command
        line, because the module's setting is only live after activation.
      '';
    };
    exp-determinate-nix-trial = {
      title = "Determinate Nix proven on eisen, then promoted fleet-wide";
      kind = "experiment";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-10-19";
      summary = "eisen switched 2026-10-19: `nix --version` is Determinate Nix 3.23.3 (2.35.3), nix-daemon runs determinate-nixd, and the Qwen endpoint answers 200 on stock llama.cpp 0.6.0 (substituted). The module left this host for modules/global.";
      refs = {
        hosts = ["eisen"];
        modules = [
          "modules/global/global.nix"
          "modules/global/determinate-nix.nix"
        ];
        docs = [".agents/deploy/hosts/eisen.md"];
      };
      links = ["decision-determinate-nix-fleet"];
      body = ''
        Without the priority fix the trial is a trap, and not for the reason first
        recorded: DN defines `nix.package` at the normal priority (100), so the old plain
        fleet definition collided with it instead of being overridden. `global.nix` now
        sets the fleet value with `lib.mkDefault`, so DN's definition wins and a host can
        still take it back by defining `nix.package` normally.

        Evaluated on eisen: `nix.package` = determinate-nix-3.23.3, `nix-daemon` ExecStart
        = `determinate-nixd daemon`, `/etc/nix/nix.conf` retargeted to `nix.custom.conf`,
        and `nix.registry.nixpkgs.to` forced back to nixpkgs `f20cd90e` because the module
        otherwise repoints it at FlakeHub weekly (mkOverride 750, `exact = true`).

        Switched 2026-10-19 18:47 (generation 26.11.20261016.f20cd90): nix is
        `Determinate Nix 3.23.3` on 2.35.3, `nix-daemon` ExecStart is determinate-nixd,
        zero failed units, and a `/v1/chat/completions` against `qwen` returned 200
        after a cold load. DN's CLI is not on cache.nixos.org; the substituter at
        `install.determinate.systems` (key `cache.flakehub.com-3`) supplied it, so the
        switch compiled nothing. Roll back by booting the previous generation.

        Models: stock `llama-cpp` with Vulkan replaced the 0.7.0 pin and both forks —
        those forced a full C++ build (~15 min) per nixpkgs bump. Kolibri and Bonsai
        are commented out, not deleted (binary, vars, fetch unit, model entry), and the
        router default moved to `qwen3.6-35b-a3b`.
      '';
    };
    open-kolibri-thread-bench = {
      title = "Kolibri thread split, measured";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "24 SMT threads lose 8% on generation (9.17 -> 8.42 t/s) but win 36% on prompt (47.41 -> 64.70); the server now splits generation (12) from batch (24).";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/llm-server.nix"];
        docs = [
          ".agents/deploy/hosts/eisen.md"
          "docs/eisen-llm-architecture.md"
        ];
      };
      body = ''
        Measured 2026-10-19 on the patched `llamaKolibri` build:
        `llama-bench -m /mnt/storage/models/Kolibri-1-Q4_K_M.gguf -t 12 -t 24 -p 256 -n 128 -r 3 -ngl 99 -ot exps=CPU`.
        The GPU had no DRM node, so this is the CPU path the service currently uses.

        | threads | pp256 t/s | tg128 t/s |
        | ---: | ---: | ---: |
        | 12 | 47.41 ± 10.11 | 9.17 ± 0.34 |
        | 24 | 64.70 ± 0.27 | 8.42 ± 0.13 |

        Generation is memory-bandwidth bound and loses with SMT; prompt processing gains.
        `mkCmd` now takes `threads` (generation) and `threadsBatch` (prompt); Kolibri runs 12/24.
        The GPU returned on 2026-10-19 16:43 (RADV NAVI10, Mesa 26.2.4), so 12/24 is a
        CPU-only result: re-run before treating it as the GPU-path optimum.
      '';
    };
    arch-measurements = {
      title = "Measurements appendix";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "The eval/route numbers the control-plane decisions are based on; rerun with `task ops:bench:evals`.";
      refs = {
        modules = ["lib/skills.nix" "lib/knowledge-graph.nix"];
        tasks = ["ops:bench:evals"];
      };
      body = ''
        | Operation | Wall |
        | :--- | ---: |
        | `nix eval .#agentSkills.count` | 0.12 s warm / 1.2 s cold |
        | `nix eval .#knowledgeGraph.graph.stats` | 9.7 s cold (reads every doc) |
        | `nix eval .#inventory.hosts.<h>.role` | 0.15 s warm |
        | `.#checks.x86_64-linux.skills-schema` | <1 s after eval |

        Never run `nix flake check` on a small host (339.78 s / 6 GiB / SIGKILL 137).
      '';
    };
    exp-001 = {
      title = "EXP-001 — Isolated guest/IoT access point (AP mode + NAT)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: managed → AP, own subnet, NAT out enp1s0. Status: not started. Highest value of the four.";
      refs = {
        hosts = ["frieren"];
        docs = ["docs/dns-failover.md"];
      };
    };
    exp-002 = {
      title = "EXP-002 — Fleet onboarding + out-of-band rescue SSID (AP/VLAN)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: a second BSSID on the same radio via AP/VLAN — one phy, two SSIDs, two subnets. Status: not started. Same implementation as EXP-001; the interesting part is the multi-BSSID surface.";
      refs = {
        hosts = ["frieren"];
        docs = ["docs/dns-failover.md"];
      };
    };
    exp-004 = {
      title = "EXP-004 — Passive RF watchdog (`monitor` mode)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: monitor, channel-hopping, passive only. Status: not started. Lowest payoff; recorded because the card supports it and the fleet has an always-on host.";
      body = ''
        **Mode:** `monitor`, channel-hopping, passive only.
        **Status:** not started. Lowest payoff; recorded because the card supports it and the fleet has an
        always-on host.

        **Use case.** A cheap wireless IDS sensor on an always-on box: watch for rogue APs, deauth floods and
        unexpected clients near the LAN, and feed alerts into the Home Assistant/MQTT stack that already
        exists rather than inventing a new alerting path.

        **Constraints to establish before it is worth building.** iwlwifi monitor-mode support is real but
        limited (no injection on some firmware revisions), channel hopping is a design choice with a
        detection-cost tradeoff, and it cannot coexist with the AP. If it cannot be a *genuine module* it does
        not graduate — this one is the likeliest to be closed as "novelty".
      '';
    };
    exp-005 = {
      title = "EXP-005 — Phone-tethered backhaul (an island that still has internet)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: AP (EXP-001/002) whose NAT egress comes from a tethered phone instead of enp1s0. Sibling of EXP-003, with a different job. Status: not started. Clearest use case of the whole file for this particular host.";
      refs = {
        hosts = ["frieren"];
        docs = ["docs/dns-failover.md"];
      };
    };
    exp-006 = {
      title = "EXP-006 — Private device subnet to harden home security";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: the EXP-001 segmentation mechanism, aimed at a different threat model — the Home Assistant device layer rather than guests. Status: not started. Depends on EXP-001 landing first.";
      refs = {
        hosts = ["frieren"];
        docs = ["docs/dns-failover.md"];
      };
    };
    exp-007 = {
      title = "EXP-007 — MQTT as the fleet bus (the broker's first publisher is the fleet, not a dongle)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: role inversion. Mosquitto stops waiting to be a device bus and becomes the fleet bus: every host is a publisher, Home Assistant is the dashboard. No new hardware, no new listener. Status: not started. Depends on a defect that is live today — see EXP-009.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
        tasks = ["checks:ha:mqtt"];
      };
    };
    exp-008 = {
      title = "EXP-008 — Monitors as code";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into fleet-monitors.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/fleet-monitors.nix"];
      };
    };
    exp-009 = {
      title = "EXP-009 — Re-adding the Zigbee/ESPHome device layer (the broker has no subscriber)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: re-introducing the device half of the stack — the half that was built first and removed second. Status: not started, and deliberately not startable without a coordinator. It does, however, surface one defect that is live today and independent of hardware.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
      };
    };
    exp-014 = {
      title = "EXP-014 — Battery-as-UPS as a real module (`services.upsTelemetry`)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: the telemetry that already exists, generalized from a frieren-shaped snippet into a module. Status: deployed on frieren only; the shape below is untested on other hosts.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix"];
      };
    };
    exp-015 = {
      title = "EXP-015 — Memory-pressure management (`services.memoryPressure`)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: the same host under a different memory policy (zram + pressure-driven tuning) instead of more swap. Status: not started; the motivating evidence is already collected.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix"];
      };
    };
    exp-016 = {
      title = "EXP-016 — Agent scheduler as a module (`services.agentScheduler`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into agent-scheduler.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/agent-scheduler.nix"];
      };
    };
    exp-017 = {
      title = "EXP-017 — Per-service network isolation (`profiles.serviceIsolation`)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: the egress half that firewall-scope.nix deliberately does not cover. Status: not started; intentionally the last of the four.";
      refs = {
        modules = ["modules/profiles/firewall-baseline.nix"];
      };
    };
    exp-018 = {
      title = "EXP-018 — Ephemeral Remote GPU/TPU Acceleration for Host Agents (`profiles.ai.remoteInference`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: dynamic remote inference bridge pairing local host agents (Hermes, crush) with ephemeral cloud accelerators (Kaggle TPU VM v3-8 / RunPod / Colab) over an ephemeral Tailscale mesh node (tailscale0), with automatic fallback to hosted APIs. Status: design study. Motivated by the analysis of cloud inference economics and agent prefill limits (see…";
      body = ''
        **Mode:** dynamic remote inference bridge pairing local host agents (Hermes, crush) with ephemeral cloud
        accelerators (Kaggle TPU VM v3-8 / RunPod / Colab) over an ephemeral Tailscale mesh node (`tailscale0`),
        with automatic fallback to hosted APIs.
        **Status:** design study. Motivated by the analysis of cloud inference economics and agent prefill limits
        (see [Investigation: Kaggle 32GB VRAM vs TPU vs Hosted](#investigation-kaggle-32gb-vram-vs-tpu-vs-hosted)).

        **Use case.** Running strong reasoning and coding models (e.g. Qwen 2.5/3 27B/32B) locally on frieren (4c/8t,
        Intel UHD 620, 11 GiB RAM) is impossible without quantization down to unusable precision and single-digit
        token speeds. Offloading inference to ephemeral cloud notebook accelerators (e.g. Kaggle's 30 free GPU/TPU
        hours/week) provides burst compute for heavy agent planning sessions.

        **The engineering analysis — what breaks in tutorial implementations:**
        Tutorials frequently promote pairing Kaggle's dual Nvidia Tesla T4 GPUs (2× 16GB = 32GB VRAM) with Ollama
        and a Cloudflare quick tunnel (`trycloudflare.com`). Ground-truth measurement reveals three fatal defects:
        1. **Layer split penalty:** Qwen 27B at 4-bit (~17 GB) exceeds one T4's 15.3 GiB usable VRAM. Ollama splits
           layers across both cards. Generation becomes an alternating relay race rather than parallel execution:
           memory bandwidth is capped at 320 GB/s, yielding only 16–18 tokens/sec.
        2. **Prefill stall vs Cloudflare 100s timeout:** Agent harnesses (Hermes, Claude Code) send massive system
           prompts and context history (15,000–30,000 tokens). On T4 compute (65 TFLOPS), prefill runs at ~325
           tokens/sec. A 30k token prompt takes **92 seconds of prefill silence**. Cloudflare Quick Tunnels enforce
           an unconfigurable **100-second request timeout** on the free tier, killing agent requests with HTTP 524.
        3. **Ephemeral URL drift & ToS:** Kaggle notebooks die on 20 min idle or 12h runtime; each restart takes
           15–30 min and issues a new random URL. Furthermore, unauthenticated Ollama over public quick tunnels
           violates Kaggle ToS and exposes an open endpoint to internet scanning.

        **The architectural alternative: Kaggle TPU VM v3-8 + Tailscale:**
        - **Accelerator:** Kaggle's free tier includes `TPU VM v3-8` (8 TPU chips, 16GB HBM each = **128 GB HBM**,
          800 GB/s per chip). With vLLM (>= 0.28.0) supporting Qwen attention via `Kaggle TPU Lab`, Qwen 27B runs
          at full FP16/BF16 (55.6 GB, 262k context):
          - Generation: ~130 tokens/sec (8× faster than dual T4).
          - Prefill: ~10,300 tokens/sec (30× faster); a 30k prompt prefills in 3s instead of 92s.
        - **Networking:** Ephemeral Tailscale auth key (`tailscale up --authkey=... --hostname=kaggle-vllm`).
          Eliminates Cloudflare tunnels entirely: zero public exposure, no 100-second timeout, and a stable
          tailnet hostname (`http://kaggle-vllm:8000/v1`).

        **Module shape.** A profile that configures Hermes and local CLI agents to probe the tailnet endpoint with
        instant fallback to commercial hosted APIs (OpenRouter / Nous) when the notebook is offline:

        ```nix
        profiles.ai.remoteInference = {
          enable = true;
          endpoint = "http://kaggle-vllm.frieren.lan:8000/v1"; # or tailnet IP/hostname
          model = "Qwen/Qwen2.5-Coder-32B-Instruct";
          apiKeyFile = config.sops.secrets.remote_llm_key.path;
          timeout = 300;
          fallbackProviders = [
            { provider = "openrouter"; model = "qwen/qwen-2.5-coder-32b-instruct"; }
            { provider = "nous"; model = "inclusionai/ling-3.0-flash-sante:free"; }
          ];
        };
        ```

        **Why it is not prod.** Running headless daemon tunnels on free-tier Kaggle accounts is a gray area under
        Kaggle's June 2025 Acceptable Use Policy; notebook lifecycle is fundamentally non-durable; and at $1.49 / 1M
        tokens on commercial endpoints (Cerebras/OpenRouter), a full week of Kaggle quota is worth ~$4.31. Exit
        criteria: an automated notebook launch script verified over Tailscale, a validated Hermes failover event
        when the notebook terminates, and authenticated endpoint tokens.
      '';
    };
    exp-021 = {
      title = "EXP-021 — Fleet Binary Cache Pre-Warming & Closure Mirror (`services.fleetCacheWarmer`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: background pre-population of frieren's Harmonia LAN cache (http://192.168.3.25:5000) for bandwidth-constrained or compute-constrained fleet nodes. Status: design study. Motivated by slow channel upgrade and build times on low-power edge nodes (moto, minyx).";
      body = ''
        **Mode:** background pre-population of frieren's Harmonia LAN cache (`http://192.168.3.25:5000`) for
        bandwidth-constrained or compute-constrained fleet nodes.
        **Status:** design study. Motivated by slow channel upgrade and build times on low-power edge nodes (`moto`, `minyx`).

        **Use case.** frieren serves as the fleet's Harmonia binary cache over LAN. However, Harmonia only serves paths
        already present in frieren's local `/nix/store`. Edge devices (laptops on Wi-Fi, low-power nodes) must fetch
        uncached paths from upstream `cache.nixos.org` over their own slow connections. frieren has a 1 Gbps wired
        uplink and idle compute. A declarative cache warmer evaluates target host flake configurations
        (`.#nixosConfigurations.<host>.config.system.build.toplevel`), queries `cache.nixos.org` during off-peak hours
        (01:00–02:30), and pulls missing store paths to frieren. When edge hosts subsequently run `nixos-rebuild`,
        they achieve 100% LAN cache hit rates at full gigabit wire speed.

        **Module shape.**

        ```nix
        services.fleetCacheWarmer = {
          enable = true;
          schedule = "*-*-* 01:30:00";
          targetHosts = [ "minyx" "moto" "deckstation" ];
          flakeUri = "github:shaoyanji/nixconfig";
          bandwidthLimit = "30M";          # prevent saturating WAN during streaming
          keepGenerations = 2;             # limit cached history to prevent disk bloat
        };
        ```

        **Evidence.** frieren already runs Harmonia on port 5000, and all fleet hosts declare `http://192.168.3.25:5000`
        in `nix.settings.substituters`. The top-level store paths for all fleet machines are evaluable on frieren via
        `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.

        **Why it is not prod.** Downloading closures for other machines increases frieren's `/nix/store` size, threatening
        frieren's 34.9 GiB closure budget enforced by `closure-budgets.toml` unless those paths are specifically tagged
        or stored in a separate cache directory. Exit criteria: a dry-run test pulling `minyx` closure paths, followed
        by an edge-node build demonstrating 0 upstream downloads and no violation of frieren's local closure budget.
      '';
    };
    exp-022 = {
      title = "EXP-022 — Declarative Btrfs Silent Corruption & Device Error Watchdog (`services.btrfsWatchdog`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into btrfs-watchdog.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/btrfs-watchdog.nix"];
      };
    };
    exp-024 = {
      title = "EXP-024 — Zero-TCP Static Documentation & Control Plane via UNIX Domain Sockets (`services.udsStaticBridge`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into uds-static-bridge.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/uds-static-bridge.nix"];
      };
    };
    exp-029 = {
      title = "EXP-029 — Hardware UPS Clean-Poweroff Simulation Drill & Telemetry Daemon (`services.upsSimulationDrill`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into ups-simulation-drill.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/ups-simulation-drill.nix"];
      };
    };
    exp-030 = {
      title = "EXP-030 — Declarative SQLite WAL Checkpoint & Integrity Dispatcher (`services.sqliteMaintenance`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into sqlite-maintenance.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/sqlite-maintenance.nix"];
      };
    };
    exp-038 = {
      title = "EXP-038 — Headless Paperless-ngx Document Ingestion Watchdog & Pipeline Health Probe (`services.paperlessWatchdog`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into paperless-watchdog.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/paperless-watchdog.nix"];
      };
    };
    exp-040 = {
      title = "EXP-040 — Autonomous Kiwix ZIM Library Integrity & Full-Text Search Health Probe (`services.kiwixWatchdog`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into kiwix-watchdog.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/kiwix-watchdog.nix"];
      };
    };
    exp-042 = {
      title = "EXP-042 — Declarative PostgreSQL Logical Backup Verification Drill (`services.postgresBackupDrill`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into postgres-backup-drill.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/postgres-backup-drill.nix"];
      };
    };
    exp-044 = {
      title = "EXP-044 — Declarative Flake Lock Drift & Security Advisory Audit Unit (`services.flakeAdvisoryAudit`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into flake-advisory-audit.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/flake-advisory-audit.nix"];
      };
    };
    exp-045 = {
      title = "EXP-045 — Autonomous PostgreSQL Vector / Chord Indexing Health & Vacuum Drill (`services.postgresPgvectorAudit`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into postgres-pgvector-audit.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/postgres-pgvector-audit.nix"];
      };
    };
    exp-046 = {
      title = "EXP-046 — Declarative SSH Bastion & Inactive Session Reaper (`services.fleetSessionReaper`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into fleet-session-reaper.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/fleet-session-reaper.nix"];
      };
    };
    exp-049 = {
      title = "EXP-049 — Declarative Inter-Host SimpleX Agent Coordination Mesh (`profiles.interAgentMesh`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: automated agent-to-agent WebSocket JSON-RPC coordination bridge across the NixOS fleet. Status: design study. Motivated by enabling autonomous peer-to-peer task dispatching between frieren, eisen, stark, and mobile nodes.";
      body = ''
        **Mode:** automated agent-to-agent WebSocket JSON-RPC coordination bridge across the NixOS fleet.
        **Status:** design study. Motivated by enabling autonomous peer-to-peer task dispatching between frieren, eisen, stark, and mobile nodes.

        **Use case.** frieren runs the fleet SimpleX SMP relay server (`:5223`) and client daemon (`:5225`). Currently, operator agents communicate
        with human operators in `#Fleet`, but cannot autonomously negotiate workloads between hosts (e.g. frieren dispatching a heavy compile job
        to `eisen` or pulling sensor telemetry from `schneeeule`). A declarative agent mesh profile standardizes the WebSocket JSON-RPC protocol
        interface across all fleet nodes: agents exchange signed, end-to-end encrypted dispatch messages over SimpleX, automatically authenticating
        peer agent identities via pre-shared public signing keys without centralized API relays or external internet dependency.

        **Module shape.**

        ```nix
        profiles.interAgentMesh = {
          enable = true;
          localDaemonPort = 5225;
          peerAgents = [
            { host = "eisen"; role = "build-accelerator"; }
            { host = "stark"; role = "gpu-inference-worker"; }
          ];
          allowedCommands = [ "ping" "build-closure" "query-telemetry" ];
          auditLog = "/var/log/agents/mesh-dispatch.log";
        };
        ```

        **Evidence.** `simplex-chat.service` is active on frieren. Inter-agent coordination skill `simplex-admin` (`simplex-rpc.py`) is already
        deployed and operational in `~/.agents/skills/simplex-admin/`.

        **Why it is not prod.** Unrestricted command dispatching between autonomous agents introduces privilege escalation risks if an edge
        node is compromised. Requires cryptographic command whitelisting and strict argument sandboxing. Exit criteria: successful automated
        ping and telemetry dispatch between frieren and a secondary node over SimpleX with 0 human intervention and full signature verification.
      '';
    };
    exp-058 = {
      title = "EXP-058 — Decision-Model Augmented Kiwix Search & Auto-Recommender (`services.decisionWikiRecommend`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Mode: non-autoregressive decision classification (Julia-1 144M & Laya 421M) for domain routing and offline knowledge recommendation with calibrated threshold gating. Status: design study & implemented prototype. Motivated by eliminating operator guesswork and providing offline technical manuals during automated system triage.";
      body = ''
        Implemented prototype — non-autoregressive decision classification with Julia-1
        (144M) and Laya (421M) for domain routing and offline knowledge recommendation.
        The realized path is the live jevdecide/Julia-1 routing line that later
        experiments (EXP-065 onward) built their classifier + synthesizer shape on.
        Closed: the experiment concluded and its descendants are recorded separately;
        nothing here remains actionable.
      '';
    };
    exp-064 = {
      title = "EXP-064 — Inter-Host SimpleX Agent Message Priority & Intent Classifier (`services.simplexMessageClassifier`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 message triage and routing integrated into the local SimpleX SMP WebSocket bridge (simplex-chat). Status: design study & architectural specification. Motivated by managing inter-agent fleet coordination (frieren, poseidon, guckloch, eisen) without human notification spam.";
      body = ''
        **Mode:** Julia-1 message triage and routing integrated into the local SimpleX SMP WebSocket bridge (`simplex-chat`).
        **Status:** design study & architectural specification. Motivated by managing inter-agent fleet coordination (`frieren`, `poseidon`, `guckloch`, `eisen`) without human notification spam.

        **Use case.** SimpleX Chat is deployed fleet-wide as the encrypted inter-agent bus. As autonomous hosts collaborate (e.g. frieren warming binary caches for poseidon, nightly backup notifications, task triage updates), agents exchange dozens of messages daily in `#Fleet`. Without semantic classification, human operators receive push notifications for every routine heartbeat and backup status line. `services.simplexMessageClassifier` acts as an inline message gateway between the local WebSocket RPC daemon (`:5225`) and the agent ingestion runtime. Julia-1 processes each incoming decrypted message across its 8k token context window, outputting structured classification tags:
        1. `FLEET_HEARTBEAT_STATUS`: silent logging in `/var/log/simplex/agent-mesh.log`.
        2. `BACKGROUND_CLOSURE_WARMED`: appended to daily summary digest.
        3. `CRITICAL_SECURITY_INCIDENT` / `HARDWARE_FAULT`: immediate high-priority push alert formatted with severity header, targeted host, and suggested remediation runbook.

        **Module shape.**

        ```nix
        services.simplexMessageClassifier = {
          enable = true;
          model = "julia-1";
          listenPort = 5225;
          monitoredGroups = [ "#Fleet" ];
          priorityThresholds = {
            silent = 0.40;
            digest = 0.70;
            immediateAlert = 0.85;
          };
        };
        ```

        **Evidence.** SimpleX SMP server is active on `*:5223` and client daemon is running on port 5225. `#Fleet` group currently connects frieren, devji, and guckloch. Python WebSocket client `simplex-rpc.py` communicates cleanly with the daemon in sub-millisecond roundtrips.

        **Why it is not prod.** Requires end-to-end testing with simulated agent messages from poseidon and frieren to verify zero message loss or classification stalls. Exit criteria: 100 test messages across varied fleet scenarios categorized with 100% precision and < 5ms processing latency per message.
      '';
    };
    exp-065 = {
      title = "EXP-065 — Declarative System 1 & System 2 Pre-Harness Diagnostic Ensemble (`services.systemEnsemblePreHarness`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Closed-loop reflex + deliberation ensemble: Julia-1 (144M) sub-millisecond anomaly detection triggering Ollama's nemotron-3-ultra:cloud to synthesize verified remediation runbooks before human escalation. Status:…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-066 = {
      title = "EXP-066 — Autonomous NixOS Flake Regression Self-Healing & Rollback Ensemble (`services.nixAutoReconcileEnsemble`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 preflight compiler error triage triggering Nemotron-3-Ultra precision Nix AST patch synthesis with nix-preflight-editor validation. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN (Generation 102,…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-067 = {
      title = "EXP-067 — Predictive Storage Failure Prognosis & Automated Btrfs Rebalance Synthesis (`services.storagePrognosisEnsemble";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 SMART attribute and NCQ timeout classification triggering Nemotron-3-Ultra to generate workload-aware Btrfs balance filters and scrub schedules. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN (Generation…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-068 = {
      title = "EXP-068 — Multi-Modal Audio/Visual Media Indexing & Semantic Metadata Enricher (`services.mediaSemanticEnricher`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 local codec & audio layout classification triggering Nemotron-3-Ultra to synthesize rich NFO metadata, chapter markers, and subtitles for unindexed recordings. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-069 = {
      title = "EXP-069 — Zero-Trust Fleet Telemetry Anomaly & Lateral Movement Classifier (`services.fleetSecurityEnsemble`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 network packet & authentication log triage paired with Nemotron-3-Ultra incident forensics and interface-scoped iptables drop-rule synthesis. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN (Generation 102,…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-070 = {
      title = "EXP-070 — Autonomous Tailscale Mesh Latency & DERP Relay Bypasser (`services.tailscalePathGovernor`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 peer latency & path status triage triggering Nemotron-3-Ultra to diagnose firewall state and generate UPnP / STUN hole-punch rules. Status: prototyped & verified live on frieren (Generation 104). Wired to…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-071 = {
      title = "EXP-071 — Predictive Memory Pressure & Early Zram Compaction Synthesizer (`services.memoryPressureGovernor`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 PSI (/proc/pressure/memory) anomaly classification triggering Nemotron-3-Ultra to synthesize dynamic watermark tuning and zram compression. Status: prototyped & verified live on frieren (Generation 104).…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-072 = {
      title = "EXP-072 — Zero-Leak Secret Rotator & SOPS Rekey Verifier (`services.sopsAutoRekeyEnsemble`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 .sops.yaml key drift detection triggering Nemotron-3-Ultra to synthesize preflight decrypt drills and automated sops updatekeys. Status: prototyped & verified live on frieren (Generation 104). Wired to…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-074 = {
      title = "EXP-074 — Continuous Declarative Kiwix ZIM Library Sync & Search Re-indexer (`services.kiwixSearchEnricher`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 ZIM library catalog audit triggering Nemotron-3-Ultra to synthesize semantic query expansions and cross-index technical manuals with a Strict Zero-Network-Download Guarantee. Status: prototyped & verified live on frieren (Generation 104). Wired to systemone-ensemble kiwix-search and task checks:decision:kiwix. Motivated by Kiwix being strictly…";
      body = ''
        Julia-1 ZIM library catalog audit triggering Nemotron-3-Ultra to synthesize
        semantic query expansions and cross-index technical manuals under a strict
        zero-network-download guarantee. Prototyped and verified live on frieren
        (generation 104); wired to systemone-ensemble kiwix-search and
        `task checks:decision:kiwix`. Never promoted to a reusable option surface.
        Closed as a completed experiment record.
      '';
    };
    exp-076 = {
      title = "EXP-076 — Fleet DNS Anycast / VRRP Health & Split-Brain Arbiter (`services.dnsHealthArbiter`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 DNS resolution latency & ARP table triage triggering Nemotron-3-Ultra to arbitrate VRRP VIP failover and prevent split-brain states. Status: proposed design study. Motivated by resolving HC-3 (DNS failover resolver gap between frieren and secondary resolver).";
      body = ''
        **Mode:** Julia-1 DNS resolution latency & ARP table triage triggering Nemotron-3-Ultra to arbitrate VRRP VIP failover and prevent split-brain states.
        **Status:** proposed design study. Motivated by resolving HC-3 (DNS failover resolver gap between frieren and secondary resolver).

        **Use case.** Frieren runs Pi-hole and Unbound as primary fleet DNS. When network interface transitions occur or when a secondary resolver comes online, keepalived VRRP VIPs can enter split-brain where two hosts answer for the same IP (`hc3-check`). `services.dnsHealthArbiter`:
        * Julia-1 runs microsecond ARP and DNS resolution probes across `enp1s0` and `wlp2s0`.
        * If two answering MACs are detected for the VIP, Nemotron-3-Ultra analyzes interface states, decides the authoritative primary node based on upstream latency, and synthesizes `arping` gratuitous ARP announcements to force clean convergence.

        **Module shape.**

        ```nix
        services.dnsHealthArbiter = {
          enable = true;
          vrrpVip = "192.168.3.10";
          resolvers = [ "127.0.0.1" "192.168.3.25" ];
          splitBrainAction = "assert-primary";
        };
        ```

        **Evidence.** `task checks:dns:failover` (HC-3) actively probes VRRP VIP for two answering MACs.

        **Why it is not prod.** Requires testing under simulated Ethernet cable disconnections and WiFi roaming. Exit criteria: simulated dual-master VRRP conflict resolved to a single authoritative resolver in < 2 seconds.
      '';
    };
    exp-081 = {
      title = "EXP-081 — Intel QuickSync VA-API Thermal Throttling & Transcode Governor (`services.vaapiThermalGovernor`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 thermal package temperature and render load triage triggering Nemotron-3-Ultra to adjust Jellyfin transcode concurrency and video downscale profiles. Status: prototyped & verified live on frieren…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-083 = {
      title = "EXP-083 — Smartd & Scrutiny Predictive HDD Drive Failure & Snapshot Arbiter (`services.diskSmartPredictor`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 SMART telemetry vector triage triggering Nemotron-3-Ultra to synthesize emergency read-only subvolume pinning and remote replication manifests. Status: prototyped & verified live on frieren (Generation…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-084 = {
      title = "EXP-084 — Ephemeral SQLite In-Memory Buffer Tuning & WAL Compactor (`services.sqliteMemoryBuffer`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 query frequency and WAL growth trajectory classification dynamically tuning PRAGMA mmapsize, PRAGMA cachesize, and checkpoint cadence across fleet SQLite instances. Status: prototyped & verified live on…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-087 = {
      title = "EXP-087 — Local Nix Binary Cache Warming & Garbage Collection Pre-Filter (`services.nixCacheWarmer`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 derivation tree analysis predicting fleet closure requirements and caching critical paths in Harmonia before running nightly garbage collection. Status: prototyped & verified live on frieren (Generation…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-088 = {
      title = "EXP-088 — Paperless Document Deduplication & OCR Confidence Scoring Pipeline (`services.paperlessOcrAuditor`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 document text density and OCR confidence triage on newly ingested PDFs triggering Nemotron-3-Ultra to synthesize metadata tags and flag illegible scans. Status: prototyped & verified live on frieren…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-090 = {
      title = "EXP-090 — Multi-Path Incremental Btrfs/ZFS Snapshot Replicator over Tailscale (`services.tailscaleBackupReplicator`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 snapshot tree and differential extent size triage triggering Nemotron-3-Ultra to calculate stream chunking, compression (zstd), and rate-limited wireguard transfer manifests. Status: proposed design study. Motivated by off-site disaster recovery between frieren's 2TB HDD pool (/Volumes/data) and remote fleet storage (poseidon).";
      body = ''
        **Mode:** Julia-1 snapshot tree and differential extent size triage triggering Nemotron-3-Ultra to calculate stream chunking, compression (zstd), and rate-limited wireguard transfer manifests.
        **Status:** proposed design study. Motivated by off-site disaster recovery between frieren's 2TB HDD pool (`/Volumes/data`) and remote fleet storage (`poseidon`).

        **Use case.** While nightly Restic backups preserve file-level state, Btrfs subvolumes (`data`, `private`, `transmission`) have extensive subvolume metadata and immutability flags. Streaming raw differential snapshots (`btrfs send -p ... | btrfs receive ...`) over Tailscale provides byte-for-byte bare-metal recovery without re-reading millions of files. `services.tailscaleBackupReplicator`:
        * Julia-1 identifies parent-child subvolume generation deltas in < 0.2 ms.
        * Nemotron-3-Ultra drafts a piped streaming manifest (`btrfs send -p @snap_prev @snap_curr | zstd -3 | pv -L 15m | ssh poseidon btrfs receive /srv/backup/frieren`), enforcing bandwidth limits during active user hours.

        **Module shape.**

        ```nix
        services.tailscaleBackupReplicator = {
          enable = true;
          sourceSubvolumes = [ "/Volumes/data" "/srv/private" ];
          remotePeer = "poseidon";
          remoteMount = "/srv/backup/frieren";
          maxBandwidthMbps = 50;
          compression = "zstd";
          schedule = "03:45:00"; # strictly within backup window
        };
        ```

        **Evidence.** Btrfs send/receive tools are in system path. Tailscale peer `poseidon` is connected.

        **Why it is not prod.** Requires testing incremental snapshot re-anchoring when a middle snapshot is pruned. Exit criteria: 50 GB differential snapshot successfully transmitted and mounted on remote peer with 0 stream checksum errors.
      '';
    };
    exp-095 = {
      title = "EXP-095 — Btrfs Asynchronous Scrub Scheduling & Cgroup IO Rate Limiter (`services.btrfsScrubThrottle`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 disk seek latency and queue depth triage triggering Nemotron-3-Ultra to modulate Btrfs scrub I/O priority via cgroups v2 io.weight. Status: proposed design study. Motivated by monthly Btrfs scrub operations on 2TB spinning HDD causing 300ms read latency spikes and media stutter.";
      body = ''
        **Mode:** Julia-1 disk seek latency and queue depth triage triggering Nemotron-3-Ultra to modulate Btrfs scrub I/O priority via cgroups v2 `io.weight`.
        **Status:** proposed design study. Motivated by monthly Btrfs scrub operations on 2TB spinning HDD causing 300ms read latency spikes and media stutter.

        **Use case.** Btrfs data integrity verification (`btrfs scrub start /Volumes/data`) reads every block on disk to assert SHA256/crc32c checksums. On spinning disks (`/dev/sda`), raw scrub reads starve concurrent NAS file shares and Jellyfin video streams. `services.btrfsScrubThrottle`:
        * Julia-1 samples `/sys/fs/cgroup/system.slice/btrfs-scrub.service/io.stat` and media playback state every 30 seconds.
        * When media playback is active, Nemotron-3-Ultra drops the scrub cgroup `io.weight` to 10 and applies `ionice -c 3`, pausing or resuming scrub dynamically to guarantee 0 dropped video frames.

        **Module shape.**

        ```nix
        services.btrfsScrubThrottle = {
          enable = true;
          pool = "/Volumes/data";
          activeMediaIoWeight = 10;
          idleIoWeight = 100;
          schedule = "Sun *-*-01 01:00:00";
        };
        ```

        **Evidence.** Btrfs watchdog is active on frieren (`services.btrfsWatchdog`). Monthly scrub is recommended practice.

        **Why it is not prod.** Requires benchmarking scrub completion time when throttled versus unthrottled. Exit criteria: full 2TB disk scrub completes within 48 hours without causing video stutter during 4K streaming.
      '';
    };
    exp-097 = {
      title = "EXP-097 — Automated Flake Input Transitive Vulnerability Scanner & Patch Proposer (`services.vulnPatchProposer`)";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 lockfile input hash audit triggering Nemotron-3-Ultra to cross-reference known CVE advisories and draft pinned input overrides. Status: approved & prototyped live on frieren (Generation 107). Wired to…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-100 = {
      title = "EXP-100 — Declarative Consolidated Fleet Governor & 3-Tier Escalation Router (`services.fleetGovernor`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into fleet-governor.nix on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/fleet-governor.nix"];
      };
    };
    exp-101 = {
      title = "EXP-101 — Structured JSON Schema Harness & Sandboxed Tool Dispatcher for System 2 (`services.nemotronSchemaHarness`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into systemone pre-harness schema on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-102 = {
      title = "EXP-102 — Ephemeral MicroVM Deployment Supervisor & Runtime Benchmark Sandbox (`hosts/microvms/frieren-canary.nix`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-13";
      summary = "Graduated into frieren-canary MicroVM on 2026-10-13; the module is the source of truth and this is the design record.";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/microvms/frieren-canary.nix"];
      };
    };
    exp-103 = {
      title = "EXP-103 — NAS Path Governor";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-14";
      summary = "Graduated into nas-client profile on 2026-10-14; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["modules/profiles/nas-client.nix"];
      };
    };
    exp-104 = {
      title = "EXP-104 — Resolver independence for clients (`profiles.dnsClient`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Mode: client-side resolver policy — a declared fallback upstream alongside the handed-out one, so a single resolver host is not also a single point of failure for clients.";
      refs = {
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
      body = ''
        Delivered 2026-11-24 as `modules/profiles/dns-client.nix`: VIP
        (192.168.3.50) + tailnet resolver (100.97.61.65) in resolved `DNS`,
        public upstreams in `FallbackDNS`, `~lan`/`~frieren.lan` pinned to the
        fleet resolvers. aristotle and diogenes' identical hand-rolled stanzas
        and eisen's bespoke list all collapse to `profiles.dnsClient.enable`.
        Options are mkDefault, so a resolver host or a roaming override still
        wins without mkForce.
      '';
    };
    exp-105 = {
      title = "EXP-105 — Resolver health probe and gate (`checks:dns:resolver-health`)";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "Mode: monitor the resolver as a service, not as a config — a probe that fails when the resolver stops answering, wired into the existing Gatus deployment and the checks: gate family.";
      refs = {
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
      body = ''
        Delivered 2026-11-24 in two places. `checks:dns:resolver-health`
        (scripts/task/dns-resolver-health.sh): live half digs the VIP for the
        zone probe and the public fallback for itself; declared half evals
        each enrolled client's `services.resolved` DNS/FallbackDNS as
        non-empty. The gatus half is delphi's "frieren resolver (tailnet)"
        `dns://` endpoint querying dns-probe.frieren.lan for 192.168.3.25 —
        `fleetMonitors.endpoints` grew a `dns` option for it.
      '';
    };
    exp-106 = {
      title = "EXP-106 — Make `network-online.target` honest on WiFi (`services.wifiBringupGuard`)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: fix a D-Bus activation race so that \"online\" means \"a route exists\", and assert it.";
      refs = {
        docs = ["docs/dns-failover.md"];
      };
    };
    exp-107 = {
      title = "EXP-107 — Build-routing guard";
      kind = "experiment";
      status = "CLOSED";
      date = "2026-10-19";
      summary = "Mode: a rule plus a gate — heavy closures are built by CI or the remote builder, never on a 2-core laptop.";
      refs = {
        hosts = ["fern"];
        modules = ["scripts/task/warm-host.sh" "flake/checks.nix"];
        tasks = ["checks:build:route" "dev:nixbuild:warm"];
      };
      body = "The rule shipped — heavy closures build via CI or the remote builder, never on a 2-core host (task checks:build:route). Closed via exp-113.";
    };
    exp-110 = {
      title = "EXP-110 — Close HC-4";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-12";
      summary = "Graduated into closure-budgets.toml on 2026-10-12; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["closure-budgets.toml"];
        tasks = ["dev:closure:budget:adopt"];
      };
    };
    exp-111 = {
      title = "EXP-111 — Close HC-2";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-12";
      summary = "Graduated into restic drill unit on 2026-10-12; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
      };
    };
    exp-112 = {
      title = "EXP-112 — Close HC-5";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: wire Home Assistant to the Mosquitto instance the stack already runs, and make extraComponents honest.";
      refs = {
        modules = ["hosts/frieren/infra-stack.nix"];
        tasks = ["checks:ha:mqtt"];
      };
    };
    exp-113 = {
      title = "EXP-113 — Close EXP-107";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-15";
      summary = "Graduated into warm-host + checks:build:route on 2026-10-15; the module is the source of truth and this is the design record.";
      refs = {
        modules = ["scripts/task/warm-host.sh"];
      };
      from = ["exp-107"];
    };
    exp-115 = {
      title = "EXP-115 — delphi as the fleet aarch64 builder";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-21";
      summary = "delphi is the fleet's only aarch64-linux host, so minyx and any mobile-nixos target have nowhere to build today; one timed closure decides whether it is a builder or a dead end.";
      refs = {
        hosts = ["delphi" "frieren" "minyx"];
        modules = ["modules/profiles/nixbuild-client.nix" "hosts/minyx/configuration.nix"];
        tasks = ["checks:host" "dev:nixbuild:plan"];
        docs = [".agents/deploy/hosts/delphi.md"];
      };
      body = ''
        **Hypothesis.** Two A1 cores and 11 GiB build an aarch64 system closure in
        a time that beats "nobody can build it", and 175 GiB free holds one target
        if the store is collected after each run.

        **Measured.** minyx evaluates here in 41 s at 1.4 GiB peak. The instance is
        at the whole Always Free A1 allowance (2 OCPU / 12 GiB / 200 GiB block),
        so there is no second instance to grow into: every idea must fit here.

        **Auth, measured.** PermitRootLogin is off on delphi, TrustedUserCAKeys is
        set, and frieren's devji already authenticates with a CA-signed cert. But
        the nix daemon opens builder ssh as root, so the design needs a
        root-readable key under /etc/nix (sops) or a dedicated builder user with
        nix.settings.trusted-users. Not devji: a builder that holds the fleet CA
        key turns a build into fleet access.

        **Two shapes.** (A) nix.buildMachines on frieren plus trusted-users on
        delphi: transparent nix build .#nixosConfigurations.minyx, but needs a key.
        (B) build on delphi over the existing CA session and push to Cachix: no new
        secrets, one task instead of a client-side config.

        **Measurement.** Build one closure with builders disabled on the far side;
        record wall time, peak RSS and store growth.

        **Exit.** A minyx closure builds on delphi and frieren substitutes it; or
        REJECTED with the wall-clock or OOM number that killed it.
      '';
    };
    exp-116 = {
      title = "EXP-116 — delphi as the fleet exit node";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-21";
      summary = "delphi measures 1.38 Gbps down and 430 Mbps up against the home link's 50/20, so routing a laptop through it is a bandwidth multiplier rather than a tunnel.";
      refs = {
        hosts = ["delphi" "frieren"];
        docs = [".agents/deploy/hosts/delphi.md"];
      };
      body = ''
        **Measured.** iperf3 over the direct WireGuard path (13 ms) gives 50 Mbps
        down and 20 Mbps up to frieren; the same VM reaches a well-connected peer
        at 172 MB/s down and 54 MB/s up. delphi already advertises itself as an
        exit node.

        **Operator state.** The split route is already configured, so this is a
        measurement, not a setup: what the laptop actually gets, and whether the
        fleet LAN stays reachable.

        **Limits.** Exit traffic is decrypted at delphi, so geographic and account
        identity become the VM's; egress counts against the free allowance; a
        missing split route silently takes LAN and tailnet peers off the fast path.

        **Exit.** A laptop records a before/after transfer number in the delphi
        runbook, and the one-liner to enable and disable the exit is documented there.
      '';
    };
    exp-117 = {
      title = "EXP-117 — delphi stages ciphertext, never plaintext";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-21";
      summary = "Backups are upload-bound and the home link uploads at 20 Mbps while delphi does 430, so staging restic/age ciphertext there turns a two-hour push into six minutes without giving the VM the key.";
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["modules/sops.nix"];
        tasks = ["infra:sops:update-keys"];
      };
      body = ''
        **Measured.** 20 GB at 20 Mbps is about 2.2 h from frieren; the same push
        from delphi at 430 Mbps is about 6 min. Upload, not capacity, is the
        constraint.

        **Shape.** frieren encrypts (restic repo password or age recipient from
        sops, never leaving the LAN), ships ciphertext to delphi, delphi pushes to
        the bucket. delphi holds only ciphertext and can burn its staging copy.

        **Not a backup target.** A single VM in one region is a worse home for the
        only copy than object storage; delphi is the pipe, the bucket is the copy.

        **Exit.** A 5 GB append is timed from frieren and from delphi to the same
        bucket, and the faster path is wired behind a task or a timer. If the
        difference is under 2x, REJECTED with the number.
      '';
    };
    exp-118 = {
      title = "EXP-118 — a signed ingest door on delphi";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-21";
      summary = "delphi already owns a public name, an ACME certificate and 430 Mbps up, so one HMAC-verified receiver there buys the fleet inbound reachability without exposing frieren.";
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["hosts/delphi/configuration.nix"];
        tasks = ["checks:host"];
        docs = [".agents/deploy/hosts/delphi.md"];
      };
      body = ''
        **What it replaces.** frieren terminates nothing inbound itself; today any
        inbound path is a tunnel someone else operates.

        **Shape.** One vhost location, one systemd unit: verify the HMAC and the
        timestamp window, then dispatch over the tailnet to frieren (a webhook that
        triggers a build, a phone-to-home drop, a cache purge). No secret in the
        URL, no shell interpolation of the payload, rate limited per source.

        **Why this host.** The certificate and the public record already exist, and
        it is the only fleet member whose ingress does not depend on the home link.

        **Exit.** A signed request lands on frieren while frieren has no public
        port, and an unsigned or replayed one is rejected in the same test run.
      '';
    };
    exp-119 = {
      title = "EXP-119 — yt-dlp prefetch for the media stack";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-21";
      summary = "A channel watcher on delphi fetches at 1.38 Gbps and drips files home, which wins on back-catalogue, retries and remote viewing but not on playback bytes.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["hosts/frieren/media-stack.nix"];
        tasks = ["data:audit"];
        docs = ["docs/storage-taxonomy.md"];
      };
      body = ''
        **Honest math.** Jellyfin plays at home, so the bytes still cross the 50 Mbps
        downlink; a cache on the VM does not make playback faster.

        **Where it wins.** A back catalogue (50 GB in about 5 min at line rate),
        retries against a flaky source, sources that rate-limit a residential IP,
        and watching over the tailnet while away from home.

        **Shape.** yt-dlp plus --download-archive on delphi, a rolling cache well
        under 175 GiB, a drip-sync into the existing media ingest door, and the
        *arr stack untouched on frieren because that is where the QSV transcode is.

        **Exit.** Ten videos are fetched both ways and the end-to-end wall clock is
        recorded; if the home path is not at least 3x slower, REJECTED with the number.

        **2026-11-04, contended line.** Single stream, done while a download held
        the uplink: googlevideo 3.3 MB/s at home against 6.2 MB/s from the relay,
        i.e. 1.9x — under this note's bar. A quiet-line run decides it.
      '';
    };
    gigabit-seams = {
      title = "Which of delphi's gigabit is a seam, and for whom";
      kind = "proposal";
      status = "PROPOSED";
      date = "2026-11-04";
      summary = "A delphi fetch only pays when the consumer is delphi itself, when the source is slower than the home line, or when the pull needs many connections; everything else is bytes moved, not bytes widened.";
      from = ["exp-119" "download-route-bulk"];
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["modules/services/media-relay.nix"];
        docs = ["docs/storage-taxonomy.md"];
      };
      body = ''
        **The rule.** The supply side is not the constraint: delphi pulls googlevideo
        at 297 MB/s and Hugging Face at 208 MB/s sustained (measured 2026-11-04 with
        `curl -r 0-… -w '%{speed_download}'`, and the same range from frieren for the
        home side: 3.3 and 5.9 MB/s, 6.2 from the relay). So a fetch here wins only if
        the consumer sits on delphi, the source is slower than the ~50 Mbps home line,
        or the pull needs many connections at once.

        **Candidates, in the order they pay.** (1) Consumers on delphi — a ZIM plus
        index, an HF weight cache, a corpus the agents query where it lands; gigabit
        with no return trip. (2) A many-connection farm — aria2 RPC on delphi
        (`modules/services/aria2-daemon.nix` exists for frieren; delphi has the binary
        only) feeding the relay vhost, which already serves Range. (3) A cold shelf
        under the relay's prune: 123 GiB free, 10 TB/month egress free. (4) Media for
        clients that are not at home, the one case where the relay is not overhead.

        **Host discipline.** Do the trying on delphi. frieren is the NAS with a shared
        line and 2 OCPU that compile nothing; NixOS makes the host irrelevant anyway —
        ssh plus `nix build .#hostChecks.<arch>.delphi` is the same edit either way.

        **Exit.** With the line quiet, 8 parallel streams fix the home ceiling; a source
        within 1.5x of it is not a seam and stays direct. First artifact: one ZIM
        queried from the sandbox microVM, which needs no home bytes at all.
      '';
    };
    exp-120 = {
      title = "EXP-120 — a tailnet gateway for System One decisions";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-21";
      summary = "System One serves the /v1/systemone envelope on delphi (loopback 8091, tailnet 8444) and `task ops:decide` is the one command for it, so a consumer asks one always-on host instead of running the engine locally.";
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["modules/services/systemone-decision.nix" "hosts/delphi/configuration.nix" "scripts/task/systemone.sh"];
        tasks = ["checks:host" "ops:decide"];
      };
      body = ''
        **Measured.** engine.py imports only the standard library (sys, json,
        hashlib, resource, argparse); its profiles describe julia-1 (144M mmBERT,
        CPU) and laya (421M ModernBERT) without loading either, so a serve mode is
        a stdlib http.server around the same query/route functions — no torch, no
        model weights at runtime.

        **Delivered.** `services.systemoneDecision.serve` answers POST
        /v1/systemone and GET /health; delphi mounts it on the tailnet at 8444
        through `services.servicePortal`, so the mount and its portal card come
        from one declaration. `scripts/task/systemone.sh` (`task ops:decide`)
        wraps the envelope with flags — `-e`, `-s`, `-q`, `-m`, `--health` — and
        the two decision skills now point at that command instead of carrying
        HTTP calls.

        **Verified (2026-10-21).** health over the tailnet: julia-1, 144M, `ok`;
        a choice question (severity of a full disk) answered in 0.32 ms with the
        documented `answers`+`usage` envelope. Uniform probabilities in that
        answer are the deterministic scorer having no signal, not a transport
        fault.

        **What it is not.** eisen's Laya is the accuracy path; this is a shape
        and routing fallback that stays up when frieren is loaded or closed. The
        CLI (`systemone-decision`) remains the offline answer.
      '';
    };
    exp-121 = {
      title = "EXP-121 — Ollama's /v1/systemone as a second decision backend";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-23";
      summary = "Nimble, tev1 and Clef answer the same typed /v1/systemone envelope Laya already serves, and poseidon declares Ollama, so the experiment is a like-for-like accuracy and latency comparison on this repo's own fixtures — not a new client.";
      refs = {
        hosts = ["poseidon"];
        modules = ["hosts/poseidon/nvidia.nix" "modules/services/systemone-decision.nix"];
        tasks = ["checks:host" "ops:decide"];
      };
      body = ''
        **What shipped.** Ollama 0.35 (2026-09-29) added POST /v1/systemone:
        named typed questions (`choice`, `noul`, `score`) answered in one
        non-autoregressive pass, 1-64 per request, with a probability per
        option. Models today: `nimble` (9B, 9.3-9.5 GB, 256K ctx, Apache 2.0,
        Bespoke Labs, fine-tuned from Qwen3.5-9B), `tev1` (4B) and `tev1:0.8b`
        (Together AI, experimental), plus `clef` (2026-10-19, Cloudflare, 27B
        multimodal from Qwen3.8-27B, 18-20 GB, 256K ctx, Apache 2.0), which needs
        Ollama 0.35.1 or later locally.

        **Why it lands here.** The pinned nixpkgs ships Ollama 0.40.4 (measured
        2026-10-23), so no flake bump is needed, and poseidon is the one active
        host that declares Ollama this week. The envelope is the one
        `services.systemoneDecision` serves and `task ops:decide` speaks, so a
        single payload can hit both backends with no glue.

        **Measurement.** The same state and question set through `nimble`,
        `tev1:0.8b` and eisen's Laya; record accuracy against Laya's 0.583
        baseline and p50 latency. Two numbers, one fixture, one client.

        **Exit.** If `nimble` beats Laya on the fixture, the router prefers it and
        this note flips to DELIVERED with the module that consumes it; if not,
        REJECTED with the delta.
      '';
    };
    exp-122 = {
      title = "EXP-122 — WiFi as a metric anchor for camera depth (Blender)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-23";
      from = ["exp-004"];
      summary = "A monocular depth map has structure but no scale; radio ranges have scale but no structure. The experiment is whether a handful of monitor-mode RSSI ranges puts a Blender-ready point cloud in real metres.";
      refs = {
        hosts = ["poseidon"];
      };
      body = ''
        **The asymmetry that makes it work.** A camera gives dense structure with
        unknown scale; radio gives sparse, noisy metric distance with no
        structure. Fusing a few ranges into a monocular depth map is the textbook
        fix for scale ambiguity — and poseidon-to-AP distance is already
        something this tree has measured, so the anchor has precedent before the
        experiment starts.

        **What the literature does.** Person-in-WiFi 3D (CVPR 2024) needs three
        receivers at the room's corners; WiFi-3D-Fusion is an open CSI-to-pose
        project; a 2026 survey covers CSI to depth fields and meshes. None of
        them is one AP plus one laptop, which is the only question worth asking
        here.

        **CSI is the hard part, not the maths.** RSSI gives range alone, through
        log-distance path loss, and drifts with orientation and furniture. CSI
        (per-subcarrier amplitude and phase) needs a NIC that exports it —
        ath9k/ath10k with the right firmware, Broadcom with nexmon, or research
        hardware; Intel iwlwifi exports none. Establish which radio is in the AP
        and in poseidon before promising a depth map: RSSI-only is a distance
        fence, not perception.

        **First artifact.** Monitor-mode capture on the OpenWrt side plus one
        camera frame, timestamped together; fit path loss per link; project the
        camera depth at that scale; write a PLY and open it in Blender.

        **Exit.** One room, one subject, depth error against a tape measure at
        1/2/3 m. If the cloud is metres off, close it REJECTED with the number.
      '';
    };
    exp-123 = {
      title = "EXP-123 — Occupancy from radio, not from phones";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-23";
      links = ["exp-004" "exp-122"];
      summary = "Home Assistant infers presence from phones and device tracking, which fails exactly when it matters — phone on a charger downstairs, person upstairs. Radio variance on a link that already exists is a second signal with no wearable.";
      refs = {
        hosts = ["frieren" "poseidon"];
        modules = ["modules/services/home-assistant.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **The signal.** Mean and variance of RSSI per link, sampled from monitor
        mode at 10 Hz: an empty room is the baseline, a body in the path shifts
        both. No CSI is required for this, which is what makes it the cheap
        rung of the RF idea — see exp-122 for the part that needs a
        subcarrier-capable NIC.

        **What it is not.** Motion artefacts and breathing need micro-Doppler and
        a second note; this one claims occupancy only, where a phone's location
        says nothing about the person holding it.

        **Exit.** A `binary_sensor` in Home Assistant fed by the capture, judged
        over seven days: false positives with the room empty, missed entries,
        latency from walking in. Seven days without manual correction is the
        bar.
      '';
    };
    nix-comment-audit = {
      title = "Prose in .nix files: categorize, then route each kind to its channel";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-21";
      summary = "4169 comment lines sit in tracked .nix files (AGENTS.nix excluded); qmd already retrieves them, so the fix is pruning narrative, not adding an index.";
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["hosts/delphi/configuration.nix" "hosts/frieren/configuration.nix" "lib/aki-site.nix"];
        tasks = ["dev:qmd:refresh"];
      };
      body = ''
        **The goal is routing, not deletion.** A comment is not slop because it
        is long; it is out of place when its kind belongs to another channel.
        Deleting it loses the reasoning that made a fix correct, which is the
        expensive thing to reconstruct.

        **Categories, and the channel that owns each.** A *policy or trap*
        ("80/443 belong to nginx", "a resolver must not resolve through the
        address it serves") goes to `flake/policies.nix` as a predicate, or to
        an option assertion; discovery is `checks.policies` failing a build. A
        *fleet fact* (addresses, roles, hardware) goes to `inventory.toml`, read
        with `task dev:inventory:feed`. A *why/history* narrative goes to an
        AGENTS.nix note, found with `ops:notes:search`. A *procedure* becomes a
        task (`taskfiles/*.yml`) or a `writeShellApplication`; the prose keeps a
        pointer. A *durable explanation* goes to `docs/`, served by the site.

        **Measured 2026-10-21** (scale, not a verdict): 4169 comment lines in
        tracked `.nix`. delphi 236/641, frieren 148/627, lib/aki-site 147/1143,
        lib/taskfile 146/653, eisen/llm-server 130/503, frieren/infra-stack
        125/992, flake/checks 113/395, netbook 109/302, frieren/dns 92/216.

        **Discovery is already solved.** qmd indexes the .nix tree (2052 files):
        `qmd search disko -c nixconfig` → `flake/host-inventory.nix` at 91 %,
        `qmd search accept-dns` → `hosts/frieren/dns.nix` at 92 %. Probe with one
        distinctive token: a quoted sentence ("disko wipes BOTH disks") returns
        `[]` while the same words hit, because BM25 matches tokens.

        **Pipeline rule, enforced.** `channels-have-a-task` asserts every channel
        still has an entry point, so a category cannot be orphaned by removing a
        task: inventory → `dev:inventory:feed`, notes → `ops:notes`, policies →
        `checks:policies`, docs → `docs:build`.
      '';
    };
    open-minyx-2611 = {
      title = "minyx reflash after the 26.11 stable release";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-10-21";
      summary = "minyx is refreshed for a reflash (NetworkManager, zram, single-job Nix, a firewall that actually admits blocky, trimmed packages) and waits on an SD card and 26.11 stable.";
      refs = {
        hosts = ["minyx"];
        modules = ["hosts/minyx/configuration.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **What changed.** The static 192.168.178.3 Wi-Fi address was a foreign
        subnet with no supplicant behind it; NetworkManager now owns both
        interfaces and the persistent connection store was already being kept.
        zram covers 1 GiB with a tmpfs root, Nix is one job and one core, the
        firewall admits 53/tcp+udp for blocky, and kubectl/helm/nodejs/compose/
        openvpn are gone from a 1 GiB device.

        **Before flashing.** minyx must be built somewhere: that is exp-115. Until
        then `checks:host HOST=minyx MODE=eval` is the only gate, and it is green on
        this tree (5.3 s / 696 MiB, 1,852 assertions); forcing the toplevel drvPath
        costs 41 s / 1.4 GiB and proves no more.

        **Exit.** The image is written, the host boots with a persisted
        /nix/persist, and `infra:deploy:host:minyx` validates; then the inventory
        entry moves off `preserved`.
      '';
    };
    gokrazy-appliance = {
      title = "Run a Go appliance (gokrazy) on the spare SD card";
      kind = "proposal";
      status = "IN FLIGHT";
      priority = "P3";
      date = "2026-10-26";
      summary = "The spare SD card runs gokrazy and receives updates pushed from any fleet host: the instance is declared in hosts/gok, the password comes from sops, breakglass keys are generated from authorized-keys.nix, and gok itself is only ever a `nix shell` instantiation.";
      refs = {
        hosts = ["gok"];
        modules = ["hosts/gok/instance.nix" "modules/services/gokrazy.nix" "scripts/task/gok.sh"];
        docs = [".agents/deploy/README.md"];
      };
      body = ''
        **Declared.** `hosts/gok/instance.nix` is the instance — hostname, the four default packages,
        breakglass keys, `Update.HTTPPassword` muted to `""`; `modules/services/gokrazy.nix` renders it, and
        `scripts/task/gok.sh` (whose header is the usage) materialises it into `~/.cache/nixconfig-gok`,
        injects `gokrazy.gok.http_password` from sops and runs `gok` from `nix shell nixpkgs#gokrazy` —
        nothing is installed. The cache exists because the runtime TLS state (`Update.CertPEM/KeyPEM`) is
        not the repo's to declare: the repo wins for declared keys, the cache keeps the rest, and `edit`
        writes back with password and TLS keys stripped.
        **Proven 2026-10-26.** `gok.sh update` from frieren pushed 41 MiB root + 71 MiB boot over HTTP and
        the device rebooted into an answering system. breakglass is installed but not started at boot by
        gokrazy's own rule, so port 2222 stays closed until it is started from the web UI.
        **The instance Hostname is the tailnet FQDN**, not bare `gok`: gok resolves it with the host's
        resolver, and systemd-resolved refuses single-label names (`resolvectl query gok` → "No
        appropriate name servers", while `dig gok.` answers) — Go's resolver takes the strict path.
        `gok.cloudforest-kardashev.ts.net` resolves through pihole's tailnet-zone forward on the LAN and
        MagicDNS on the tailnet, so one update works from any host; `--hostname=gok` keeps the tailnet node
        name short and independent of it.
        **Cost is cached, measured 2026-10-26.** GOCACHE and GOMODCACHE live under
        `~/.cache/nixconfig-gok/go/{build,mod}` beside `builddir`, so repeat pushes reuse the compiled
        tailscale: a cold build spent 4m45s compiling, the same update warm took **1m48s end to end**
        (build + push + reboot + `Device ready to use!`) — a fresh host pays the cold compile once.
        **Exit.** `gok update` works by name from any fleet host, and the flash path no longer depends on
        one machine's instance directory.
      '';
    };
    resolver-never-breaks = {
      title = "The fleet resolver survives its own host's rebuilds";
      kind = "proposal";
      status = "IN FLIGHT";
      priority = "P1";
      date = "2026-10-26";
      summary = "frieren answers DNS for the LAN and the tailnet; a local switch stopped pihole-ftl mid-activation and every client got 'Server Not Found'. A watchdog restarts it in seconds, and the switch task now refuses to build on a resolver host unless the closure comes from a builder.";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/frieren/dns.nix" "hosts/frieren/reverse-proxy.nix" "taskfiles/infra.yml"];
        docs = [".agents/deploy/hosts/frieren.md"];
        tasks = ["infra:switch:nixos"];
      };
      body = ''
        **What broke (2026-10-26).** A local `nixos-rebuild switch` on frieren was aborted by the IO
        watchdog and then failed on a stale `mnt-burgernas-peachcable.mount`; pihole-ftl had already been
        stopped for the activation, so the LAN had no resolver. Two faults surfaced with it: the portal
        vhost only listened on :80, so any unmatched `https://` name landed on the first 443 block
        (Audiobookshelf), and pihole answered NXDOMAIN for every `*.cloudforest-kardashev.ts.net` name, so
        tailnet URLs never resolved from a LAN browser.
        **Four fixes, in order of what they protect.** pihole forwards the whole tailnet zone to MagicDNS
        (`server=/cloudforest-kardashev.ts.net/100.100.100.100`), so tailnet FQDNs resolve for any client of
        the fleet resolver and follow the node. The portal owns :443 as `default_server` with the LAN
        wildcard cert, so an unknown Host (the tailnet FQDN, `vault.frieren.lan` upgraded to https) gets the
        portal instead of whichever vhost serialized first. `dns-resolver-watchdog` asks 127.0.0.1 the
        question a client asks and restarts pihole-ftl after three failed probes, standing down while a
        switch is in progress, and `pihole-ftl` itself is `Restart=always`. `infra:switch:<os>` refuses on
        a host whose `hosts/<host>/dns.nix` declares `profiles.dnsFailover` unless `REMOTE_BUILD=1` (builds
        with `max-jobs = 0`), and after any switch it proves the resolver answers before exiting 0.
        **Proven.** 15/15 portal links returned 200 through both entry points (`192.168.3.25` and
        `frieren.<tailnet>.ts.net`), each resolving through pihole; the guard refuses in 0.1 s before any
        evaluation; the watchdog has no false positives against live names and fails a nonexistent one.
        **Exit.** A rebuild of frieren is a rebuild of a peer, not of the fleet's resolver: either the
        second resolver comment in `hosts/frieren/dns.nix` becomes true (fern runs `role = "secondary"`) or
        the resolver moves off the host that also runs the storage stack.
      '';
    };
    open-frieren-offload = {
      title = "Move the movable services off frieren";
      kind = "open";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-11-20";
      summary = "Compute leaves the NAS and the NAS keeps the name and the copy: stirling (2026-10-21) then paperless, vaultwarden and anki (2026-11-02) run on delphi behind frieren's vhosts, with a nightly state mirror into its restic window; the monitor pair followed on 2026-11-04, hermes stays resident on both hosts by decision, and immich stays because its 1.4 TB is the NAS.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["hosts/frieren/infra-stack.nix" "modules/profiles/service-exposure.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **The rule.** Move what has no library and no shared logins, and keep the name and the copy behind.
        stirling-pdf went on 2026-10-21; paperless, vaultwarden and anki on 2026-11-02, over an earlier
        "paperless stays": what that rule protected was the archive and the family's habits, not the laptop.
        `docs.`, `vault.` and `anki.frieren.lan` are still frieren's vhosts, and `services.offloadBridge` mirrors
        every tree to `/srv/backup/offload` at 03:10, inside the window that already carries those copies to BurgerNAS.

        **What is left is a decision.** hermes stays resident on both hosts: each gateway polls its own bot token
        (`hermes` here, `delphi-telegram` there), so the 226 MiB in `~/.hermes` buys two agents, not a conflict. The
        monitor pair did move (2026-11-04): frieren's gatus and its empty uptime-kuma are gone, the checks run in
        delphi's `services.fleetMonitors` over the tailnet, and alerts post back to frieren's SimpleX bridge — the
        only host with an identity to deliver them. One dependency the move cannot remove: a name that lives on
        frieren needs frieren's nginx.

        **The tunnel is gone.** Frieren was deployed on 2026-11-02 with vhosts that name delphi's tailnet address;
        `offload-tunnel` was stopped first and all three names still answered with frieren holding no loopback
        listeners, so the cutover was proved before the file and its import were deleted.

        **Exit.** Each moved unit is gone from frieren's system.slice, serves from delphi over the tailnet, and
        `systemctl show -p MemoryCurrent` on frieren shows the release; the shelter copy is under
        `/srv/backup/offload` and inside a restic snapshot; the tunnel file is deleted — all met.

        **Verified 2026-11-20 (devin).** No stirling/paperless/vaultwarden/anki/gatus/uptime-kuma units exist in
        frieren's system.slice; delphi answers on the tailnet (stirling :8445 → 200, uptime-kuma :8448 → 302,
        gatus :8181 → 200) while `docs.`, `vault.` and `anki.frieren.lan` stay frieren vhosts. The 03:10 mirror
        refreshed `/srv/backup/offload/{anki,paperless,vaultwarden,vaultwarden-backup}` the same day and snapshot
        d2228859 (03:30, `restic-frieren-local`) carries the tree. Memory shed measured on delphi's units: ~1.4 GiB
        (stirling 633, paperless ~480, uptime-kuma 137, vaultwarden 58, gatus 42, anki 6 MiB). Nothing movable
        remains: the rest is library (immich, jellyfin, plex, *arr, audiobookshelf), the SimpleX identity, or
        hermes by decision.
      '';
    };
    exp-114 = {
      title = "EXP-114 — The eval-granularity defect";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: post-mortem on a verification habit, with a reproducible counter-example.";
      body = ''
        **Mode:** post-mortem on a verification habit, with a reproducible counter-example.

        **Status:** cause identified; `AGENTS.md` verification protocol rewritten accordingly.

        **Finding.** `AGENTS.md` prescribed `nix eval .#nixosConfigurations.<host>.config.networking.hostName`
        as the "quick eval smoke test". That forces **one option** and type-checks nothing else, so it cannot
        fail on a bad value anywhere else in the module tree. Paired with *"Never build without cause"*, the
        practical result was: cheap per-option evals run ritually (proving nothing) and the build that would
        have caught a real error never run.

        **Counter-example.** This is the exact error that survived evals "passing" on four hosts and only
        surfaced when a build forced the real toplevel:

        ```
        error: A definition for option `networking.networkmanager.dispatcherScripts."[definition 1-entry 1]".type'
        is not of type `one of "basic", "pre-down", "pre-up"'. Definition value: "up"
        ```

        `nas-client.nix` set `dispatcherScripts.*.type = "up"`/`"down"`. Those are NetworkManager *event*
        names; the NixOS option only accepts `basic`, `pre-up`, `pre-down` (upstream's own example filters the
        event from `$2` inside a `basic` hook). It was a hard eval failure for every host on the desktop chain.

        **Fix — the phased model now in `AGENTS.md`:**

        - **Pre-build:** `nix eval --raw .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath`
          instantiates the *whole* config — every option type — in seconds. Scoped to the hosts the change
          reaches, batched into one bash loop; whole-system sweeps are for wiring changes, not habit.
        - **Build:** once the closure changes, the build is the test — on the builder, never on the target.
        - **Size:** `dev:closure:top|size|reduce` are build *preparation* (what is big, what will be fetched),
          not verification. They read the store DB and prove nothing.

        > eval to catch a config error · build to prove a closure · size to plan a build

        **Why it is not prod.** The habit, not the tool, was the defect; no gate enforces "did you force the
        toplevel". `checks:quick` still runs four single-option evals — the cheapest available improvement
        would be to make it force those four toplevels instead, which the phase model permits because it is
        still seconds per host.
      '';
    };
    sloppiness-audit-2026-10 = {
      title = "Sloppiness audit: knowledge with two homes and no enforcement";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-20";
      summary = "Slop here is not ugly code but uncounted truth: hand-typed numbers, checks that cannot fail, and checkout paths on a 34-host fleet.";
      refs = {
        modules = [
          "taskfiles/checks.yml"
          "scripts/task/repo-paths.sh"
          "modules/services/systemone/ensemble.py"
        ];
        tasks = ["checks:repo:paths" "checks:tasks" "checks:decision:smart"];
        docs = [".agents/SCHEMA.md" ".agents/skills/correct/SKILL.md"];
      };
      body = ''
        **Finding.** Slop here is not ugly code. It is knowledge with two homes and
        no enforcement: a fact typed into prose while the compiler that knows it sits
        unused, a rule that fails only if a human reads it, a check that cannot return
        non-zero.

        Measured 2026-10-20 (the numbers drift; the command is the durable part):

        - Hand-typed counts: `task-plane` claimed 373 tasks across 17 shards (430 / 18);
          `.agents/README.md` claimed 43 skills (45); `AGENTS.md` claimed ~25 hosts (34).
        - 17 `checks:decision:*` tasks wrap `ensemble.py`, which had no `sys.exit`.
        - 39 checkout-path occurrences in 15 tracked files, on a fleet of 34.
        - 91 broken doc links (88 absolute `file:///`); 5,220 comment lines in 236 `.nix`
          files (17%), 66 banner rules, 86 dated narratives outside the turn log.

        **Landed.** `checks:repo:paths` fails on a hardcoded checkout path and runs in
        `checks:quick`; the paths it named now resolve from `git rev-parse`, `../..`, or
        `Path(__file__)`. The pstack method skills (`correct`, `no-comments`, `unslop`,
        `prove-it-works`) are installed under `.agents/skills/`.

        Every `checks:decision:*` task accepts `--fail-on-alert` and exits 1 on a
        non-nominal status, category, safety flag or error; proved on
        `checks:decision:smart` and the `sops-rekey`/`disk-smart`/`vuln-proposer` simulate
        paths. Tasks probe the flag before using the installed binary, so a stale closure
        falls back to the repo source.

        **Delivered.** `checks:docs:links` (in `checks:quick`) gates absolute and broken
        links; `checks:counts` holds registry counts to the compiled source, fixture proven.

        **Exit.** Met for the count and link gates; `refs.tasks` names both. The
        `no-comments` and `unslop` passes stay open work on their own notes.
      '';
    };
    experiments-policy = {
      title = "Experiments — what belongs and how one graduates";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-19";
      summary = "The lifecycle rule for design studies: option surface, evidence, exit criteria; graduates by becoming a module, not by staying enabled.";
      refs = {
        docs = [".agents/SCHEMA.md" ".agents/skills/agents-notes/SKILL.md"];
      };
      body = ''
        Experiments are **service-module design studies**. The deliverable is not "a thing that works on
        frieren" — it is the **option surface** of a thing that could work anywhere in the fleet, built to
        the same standard as a genuine upstream `services.*` module. Each entry records:

        - the **mode** being spun up (how the same hardware/software behaves differently),
        - the **use case** that motivates it,
        - the **module shape** it would need (concrete options, types, defaults),
        - **evidence** — what was actually observed on this hardware versus what was assumed,
        - **why it is not prod**, and the **exit criteria** that would promote it.

        Three rules keep this file useful instead of a graveyard:

        1. **No host imports these.** The moment something here is enabled on a host it is either prod (go
           write it as a module and delete the entry) or it is rot.
        2. **Evidence beats plausibility.** "iwlwifi supports AP mode" is a datasheet claim; "`iw list`
           reports `AP` on `8086:3166`" is evidence. Mark the difference explicitly — the wireless entries
           below exist precisely because the first draft of that analysis was wrong.
        3. **A mode is not an implementation detail.** If the interesting part is "run the same radio in a
           different mode", say so up front; that is the experiment.
      '';
    };
    pi-eisen-ondemand = {
      title = "Pi as the eisen-backed coding harness (on-demand inference, not a resident model)";
      kind = "proposal";
      status = "PROPOSED";
      date = "2026-10-21";
      summary = "Pi 1.3.0 is a thin harness with `models.json` and a settable agent dir; the lean fleet shape is a generated `models.json` pointing at eisen's llama-swap plus one pre-warm shim that reuses `infra:wol:eisen`. No 2.0 exists (npm latest 1.3.0, changelog newest tag 1.3.0).";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/llm-server.nix" "modules/user/ai/default.nix"];
        tasks = ["infra:wol:eisen" "infra:rebuild:home-manager"];
        docs = ["docs/pi-harness.md" ".agents/skills/eisen-status/SKILL.md"];
      };
      body = ''
        **No Pi 2.0 exists.** npm publishes 60 versions and no `2.x`; newest tag and `latest` are
        `1.3.0` (2026-10-15). The "MCP coding mode" is `codemode`, which ships in 1.x: the model writes
        JS calling `tools.*` (MCP namespaced `tools.mcp__<server>__<tool>`) and only the script's output
        reaches the model. Source material: [docs/pi-harness.md](docs/pi-harness.md) — the versions,
        codemode limits and config surfaces, so none of it needs re-fetching.

        **Three knobs.** `<agent-dir>/models.json` takes any OpenAI-compatible endpoint (`baseUrl`,
        `api: "openai-completions"`, `apiKey`, `models[].id`); `PI_CODING_AGENT_DIR` relocates the agent
        dir, so config is a store path, not a hand-edited `~/.pi/agent`; `--print`/JSON/RPC make the
        harness scriptable (`pi-chat` leans on that).

        **Shape — three layers, no new daemon.**
        1. *Data*: one `models.json` from eisen's LLM module facts (`qwen`, `http://eisen.lan/v1`,
           tailnet URL), so the endpoint cannot drift from the server it names.
        2. *Control*: a `pi-eisen` shim — probe `/v1/models` (1 s), else `task infra:wol:eisen` + poll,
           then a `max_tokens: 1` completion to force the GGUF load (2–3 min cold; `/v1/models` does
           not load weights), then `exec pi`. Per session: `!command` hooks in `models.json` run per
           request uncached, so a wake there would block every turn inside auth.
        3. *Lifecycle*: none. llama-swap idles the model out and the gaming guard stops it; waking is
           only the cold path, and nothing should auto-sleep a gaming desktop.

        **Scenarios.** LAN warm-but-unloaded (prewarm once) · off-LAN tailnet `serve` · Steam game
        running (refuses; offer a cloud model instead of hanging) · unattended/agy/CI (never eisen: the
        guard is non-deterministic and a 21 GiB reload must not gate a schedule) · two sessions (one slot).

        **Don't.** Pi's `/llama` router on eisen (duplicates declarative llama-swap); `curl | sh` (unpinned); sharing the model with a Sunshine stream.

        **Exit criteria.** `checks:host HOST=eisen MODE=eval` green with the generated files as store
        paths; one measured cold session (wake → first token); guard refusal exercised; a cloud fallback
        so no run depends on the desktop being awake.
      '';
    };

    cloud-quota-one-door = {
      title = "One authenticated door for cloud quotas, not another inference server";
      kind = "proposal";
      status = "PROPOSED";
      date = "2026-11-11";
      summary = "The Steam Link's `aichat --serve` is bound to 0.0.0.0:8000 with no auth over four provider keys, launched by a script whose `age` is not on PATH; the fleet's door is eisen's :8000 router, which forwards the caller's auth and holds no key.";
      links = ["pi-eisen-ondemand"];
      refs = {
        hosts = ["eisen"];
        modules = [
          "modules/services/llm-decision-router.nix"
          "modules/user/ai/aichat.nix"
          "hosts/eisen/llm-server.nix"
        ];
      };
      body = ''
        Measured 2026-11-11, aichat 0.30.0: `--serve` answers `GET /v1/models` with **no Authorization header**, enumerating
        every configured client, and also serves `/v1/embeddings`, `/v1/rerank`, `/playground` and `/arena`; it dispatches
        on `<client>:<model>` and 400s an unknown id, so it routes over local config rather than passing through.

        **What is installed on the Steam Link now.** `~/run-aichat.sh` is `export $(age -i key.txt -d .env.age)` then
        `exec /usr/local/bin/aichat --serve`; the config binds `serve_addr: 0.0.0.0:8000` with one client, `groq`, on
        `openai/gpt-oss-20b`. `.env.age` carries GROQ, GEMINI, COHERE and GITHUB, `~/.config/aichat/.env` keeps NVIDIA in
        plaintext, and `key.txt` (0644) is the age identity sitting beside its own ciphertext. `age` is not on PATH (it is
        `/usr/local/bin/age`), so the command substitution is empty and the service starts keyless: 401 on every request.

        **It does not remove the hop.** Groq's quota is Groq's: a proxy redistributes failures and creates no capacity, and
        with one client a 429 stays a 429. What it buys is one stable base_url for a consumer that cannot hop — a static
        config, a script, an HA `rest_command` — and one process holding the key.

        **The fleet already owns that door, on a better host.** `services.llm-decision-router` on eisen listens on
        127.0.0.1:8000 (nginx `/router/`), routes chat to llama-swap and decisions to Jev then Laya, and forwards the
        caller's auth instead of holding a key — at 0.1 ms, where the Steam Link answers in 10-1126 ms.

        **Secrets are the wrong cargo for this train.** One plane is the win, not more endpoints: write the decrypted file
        to tmpfs, `set -a; . file; set +a` so a value with a space survives, and exit non-zero when decryption fails. A key
        behind an identity stored beside it is storage protection, not host protection, and an OpenAI-compatible endpoint
        is a token-spend oracle: anything that reaches it can spend. Loopback, or an authenticating proxy, no Playground.

        **Home fit.** Good: a scheduled curator (one digest from the sentinel ledger, xs turns or the mail archive) and an
        HA `rest_command` needing a judgement rather than a model. Bad: HA Assist voice, since the house already runs
        Parakeet and Qwen locally and a cloud lane there moves the microphone off-premises for no capability gain.

        **Kill measurement.** Count client-side 429/quota errors in the journals over a week against the number of places
        the key is plumbed. Few errors and a stable key list means there is no hop to consolidate: REJECTED.
      '';
    };

    tpm-sops-planes = {
      title = "TPM sops: two rebuilds, two PATHs, and a per-session group";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-22";
      summary = "A TPM identity is a sealed handle, so the order is fixed: deploy the chip, generate the identity on the host, register + rekey, then point both planes at it. The user unit's PATH is the plugin list, not the login PATH — the fault that looks like \"not a recipient\".";
      refs = {
        hosts = ["scratch" "fern" "frieren"];
        modules = ["modules/sops.nix" "hosts/scratch/configuration.nix" "hosts/fern/configuration.nix"];
        tasks = ["infra:sops:update-keys" "infra:secrets:sync"];
        docs = ["docs/sops-rekey.md" ".agents/deploy/hosts/scratch.md"];
      };
      body = ''
        Procedure is `docs/sops-rekey.md` § *TPM-sealed identity* (the skill that
        duplicated it was deleted: `agent-prose-budget`). Three facts a reconstruction
        gets wrong:

        1. **Two rebuilds.** Rebuild A installs `security.tpm2`, `tss` and `age-plugin-tpm` and must not
           reference the identity; rebuild B points `sops.age.keyFile` at it. Referencing a file that
           does not exist yet fails activation and reads as a config bug.
        2. **`sops.age.plugins` on both planes.** sops-nix sets the user unit's `Environment=PATH=` to
           exactly that list, so a TPM host without it runs `sops-nix.service` with an empty PATH and
           dies on `0 successful groups required, got 0`. `home.packages` does not reach the unit.
        3. **`tss` is per session.** The deploy that adds the user to the group does not change the
           running `systemd --user` manager, so the first user-plane start still fails until a reboot.
        4. **Verify the store copy, not a checkout.** The unit executes
           `sops-install-secrets … <manifest>.json`, which names `/nix/store/<hash>-secrets.yaml`; that
           path is what activation reads. Decrypting a working-tree copy proves the wrong thing on a host
           where `~/Documents/nixconfig` is a home-manager store symlink (`git rev-parse` there answers
           about the active generation, and it cannot be pulled — scratch's real clone was `~/nixconfig`,
           2768 commits behind). Pair the decrypt with a `SOPS_AGE_KEY_FILE=/nonexistent` control that
           must fail, or a stale `keys.txt` passes the test the chip was supposed to pass.

        Verified on scratch 2026-10-22: `hashedPassword` installed, user unit `Result=success` with
        `Environment=PATH=<age-plugin-tpm>`, CA key present, `switch-to-configuration` exit 0. After a
        genuine pull (`a1b56c8d`, submodule `7a35ad4` matching frieren byte-for-byte) the store file
        decrypts on both planes to the same digest as the checkout and the mirror (sha256 `5042298e…`
        encrypted, `436f477d…` plaintext), with the no-identity control at exit 128. Upstream's `p256tag
        unsupported` report is stale for sops 3.13.3 / age 1.3.2: encrypt, `updatekeys` and decrypt all
        accept `age1tag1…`.
      '';
    };

    poseidon-tpm-luks-dock = {
      title = "Poseidon: chip-sealed sops identity plus TPM unlock for both LUKS volumes";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-23";
      summary = "The same chip now unseals the user sops identity and both LUKS volumes, with the passphrase keyslot and host SSH key left as the recovery doors. The dock's missing display was an unbuilt evdi module, not a config flag.";
      from = ["tpm-sops-planes"];
      refs = {
        hosts = ["poseidon"];
        modules = [
          "hosts/poseidon/configuration.nix"
          "modules/sops.nix"
          "modules/profiles/dell-dock.nix"
        ];
        tasks = ["checks:host"];
        docs = ["docs/sops-rekey.md"];
      };
      body = ''
        The sops half is the documented two-rebuild order; what is load-bearing here:

        1. **PCR 7, not the boot chain.** Secure Boot is off on this laptop, so PCR 7
           keeps the token valid across kernel and NixOS updates but does not attest
           the boot path. The passphrase keyslot stays enrolled for that reason.
        2. **The initrd is the proof, not the running system.** Its crypttab carries
           `tpm2-device=auto` on both volumes, it ships `systemd-cryptsetup` and
           `tpm2-tss`, and `tpm_crb` is built into the kernel — no module list is
           needed for the chip to exist in stage 1. The reboot journal containing no
           "Please enter" event is the exit criterion.
        3. **The dock's display was a missing module.** `evdi` in `boot.kernelModules`
           alone yields "Failed to find module 'evdi'": the package must also be in
           `boot.extraModulePackages`. `card0-DVI-I-1` appearing is the signal.
        4. **The dock NIC stays unmanaged on a host whose Wi-Fi owns the subnet.**
           Managing it put a second interface on `192.168.3.0/24`; the resulting ARP
           flux (either NIC answering for the other's address) killed live SSH
           sessions, and a managed profile added its own failure mode: when
           `interface-name` is unset NetworkManager binds by rewriting the profile,
           leaving a UUID-named copy beside the declarative one so activation then
           fails against the duplicate. `ensureProfiles` also writes to
           `/run/NetworkManager/system-connections`, so an old copy persisted in
           `/etc` shadows it and must be removed. Display/USB work with the port
           unmanaged; one uplink per subnet.

        Remaining limit: DHCP is the Huawei router (`192.168.3.1`; frieren's dnsmasq is
        proxy-only PXE), so a reservation for the dock's MAC (`9c:eb:e8:d2:ea:bc`) is
        a router-side action, not a repo change.
      '';
    };

    taskfile-plane-handmade = {
      title = "The $HOME task plane is a hand-made shim, and it fails where it exists";
      kind = "open";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-10-22";
      summary = "`~/Taskfile.yml` is hand-made and untracked, and `task` from $HOME fails on both hosts checked: 203 on frieren (duplicate `load-env` under a flattened include) and 100 on scratch (no file). Working forms are `task -t <repo>/Taskfile.yml` or running inside the clone.";
      refs = {
        hosts = ["frieren" "scratch"];
        modules = ["Taskfile.yml"];
        tasks = ["checks:tasks"];
        docs = ["AGENTS.md" "docs/task-control-plane.md"];
      };
      body = ''
        Measured 2026-10-22, not inferred: `cd ~ && task --list` exits **203** on frieren with
        `Found multiple tasks (load-env) included by "nixconfig"`, because `~/Taskfile.yml` defines
        `load-env` while `Taskfile.yml:301` does too and the include uses `flatten: true`. On scratch the
        file is absent, so `task` and `task -g` both exit **100** (`No Taskfile found`).

        Why it went unnoticed: nothing writes the file. `git ls-files` has no home-level Taskfile and no
        `.nix` module emits one, so it exists only where someone made it by hand — and the two working
        paths (`task -t ~/Documents/nixconfig/Taskfile.yml`, or running inside the clone) kept the shim
        out of daily use. `AGENTS.md` described it as an invariant anyway; that section is now corrected.

        A declarative version has to clear three things, which is why this is open: `dir:` must be the
        host's *actual* checkout (`~/Documents/nixconfig` is a home-manager store symlink on scratch,
        read-only), it must not redefine a flattened name such as `load-env` (use a prefixed/namespace
        include instead of `flatten: true`), and it needs a gate that runs `task --list` in `$HOME` so a
        collision cannot ship. Exit criteria: that gate passes on every active host the module serves.

        Delivered 2026-11-20: `modules/user/task-shim.nix` emits `~/Taskfile.yml`
        through `home.file` (fleetHost-gated like AGENTS.md) from the single
        source `modules/user/task-shim.yml`, and `checks:task-shim:test` proves
        `task --list` exits 0 in a temp $HOME and that a duplicate flattened
        include exits 203. `flatten: true` stays — the contract is unprefixed
        task names — and the root file defines no tasks, so it cannot shadow.
      '';
    };

    rice-fork-not-patch = {
      title = "Changing the compositor means forking the userland, not disabling it";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-22";
      summary = "scratch ran dwl on top of base-desktop-environment with niri force-disabled: the session changed and everything it opened did not. Enforced by [[flake/policies.nix#desktop-fork-not-disable]]; port the mechanism a binding needs, not just the chord.";
      refs = {
        hosts = ["scratch"];
        modules = ["hosts/scratch/configuration.nix" "modules/global/nixos.nix" "modules/config/dwl/config.h"];
        tasks = ["checks:policies"];
        docs = ["flake/policies.nix"];
      };
      body = ''
        Three failures, one shape: inheriting an appearance instead of the behaviour.

        1. **WM swap, userland inherited.** `programs.niri.enable = mkForce false` inside the profile that
           installed niri, DMS, zen, nautilus and the portal/keyring stack. The operator sees dwl; the
           closure is the fleet desktop. Now an assert (`desktop-fork-not-disable`) rather than a review
           note: drop the profile, declare the modules, and fork HM through `fleet.hmUserModules` —
           `imports` is a module argument, so it cannot be `mkForce`d at the call site.
        2. **Table ported, mechanism lost.** niri's chords went into config.h, but `Mod+A` ran
           `wmenu-run`, which walks `$PATH` and cannot see `.desktop` files: the 55 appimage entries in
           `~/.local/share/applications` vanished while the keymap looked correct. `j4-dmenu-desktop`
           feeds those entries to wmenu. For every binding, port what it opens, not only its keys.
        3. **Infrastructure was in the profile being dropped.** `tailscaled` and the NAS automount came
           from `desktop-client.nix`, so forking took the host off the tailnet and left the canonical
           `~/Documents/nixconfig` symlink dangling at its NAS target (the mapping is stated once, in
           `.agents/SCHEMA.md` §7). A fork must list what it keeps: reachability and the
           canonical path are not rice.

        Documentation rule that came with this: rationale goes here or in a policy, not into comment
        blocks in `.nix` files — the body-comment essays this run produced are what the
        `agent-prose-budget` squeeze caught (a duplicated `tpm-sops` SKILL went so
        `docs/sops-rekey.md` stays the single home).
      '';
    };

    netbook-desktop-phase-2 = {
      title = "The netbook's session is the fleet's; the rice it runs is still hers";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P1";
      date = "2026-10-27";
      summary = "The session is the fleet's (programs.dwl via profiles.dwlDesktop) and so is her userland: the six cards and every ~/.dotfiles helper were ported to fnott, wmenu, foot and waylock in one deploy, and mako, fuzzel, alacritty and swaylock left the closure. Mapping and losses: docs/netbook-rice-port.md.";
      refs = {
        hosts = ["netbook"];
        modules = [
          "hosts/netbook/configuration.nix"
          "hosts/netbook/dwl-keybinds.h"
          "modules/profiles/dwl-desktop.nix"
          "modules/config/dwl/config.h"
        ];
        tasks = ["infra:apply:host:netbook" "checks:host"];
        docs = [
          ".agents/deploy/hosts/netbook.md"
          "docs/netbook-rice-port.md"
        ];
      };
      from = ["rice-fork-not-patch"];
      body = ''
        **Delivered 2026-10-27: the session is the fleet's.** tty1 autologins and the login
        shell execs `/etc/xdg/dwl-session` — NixOS's `programs.dwl`, driven by this
        profile's `package` (spliced keymap) and `extraSessionCommands`, so the compositor
        is `lib.getExe cfg.package` and no PATH shadows it. niri, waybar, greetd and
        gnome-keyring left the closure; her layer is `hosts/netbook/dwl-keybinds.h`,
        spliced *first* because dwl takes the first match. Two defects came from that
        deploy: it ran stock dwl for one deploy — a wrapper listed `pkgs.dwl`
        beside the keymap build, and a wrapper's PATH wins inside the session — then its
        clients raced a socket FILE a killed session left behind.

        **Delivered 2026-10-27: her userland runs the session it is in.** The six cards and
        every `~/.dotfiles` helper were ported in place and committed in her two repos;
        `mako`, `fuzzel`, `alacritty` and `swaylock` left the bridge block, so the closure
        carries fnott (112 MiB, was mako 326) and the profile ships
        `/etc/xdg/fnott/fnott.ini`. Three rules carry it: a card identifies itself by a
        unique *summary* (`fnottctl list` → `id: <summary>`; makofetch gained one), bodies
        pass through `strip_span` because fnott draws `<span>` literally, and menus/lock
        are `wmenu -p/-l/-P` and `waylock -fork-on-lock`. Losses and mapping:
        `docs/netbook-rice-port.md`.

        **Proven.** fnott owns the bus name, a synthetic Notify reads back through
        `fnottctl list`, `📊 makotop` toggles on the same chord, and a grim capture of the
        Mod+Alt+Backspace card shows its table and italic footer with no literal markup.
        That capture caught what the first pass missed — makokill sends `body` and `footer`
        as one argument, so neither was filtered; every Notify body now filters at its own
        call site. Exit met: bridge block gone, bind targets resolve on the session PATH,
        `checks:host HOST=netbook` green, deploy 3m24s / 0 failed units. Firefox stays.
      '';
    };

    zen-profile-extensions = {
      title = "Zen's declarative extensions arrive disabled, and it is a pref, not an install bug";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-22";
      summary = "`extensions.packages` writes XPIs into the app-profile scope; Firefox's default `extensions.autoDisableScopes` (15) then disables each on discovery, so every add-on shows `userDisabled: true`. Set the pref to 0, keep `enabledScopes` 15 — and expect existing entries to stay disabled until reset.";
      refs = {
        hosts = ["scratch" "frieren"];
        modules = ["modules/zen.nix"];
        docs = ["docs/history/audit-2026-11.md"];
      };
      body = ''
        Measured on scratch 2026-10-22: 31 add-ons in `extensions.json`, 9 active, 22 `userDisabled`,
        `autoDisableScopes` absent from `user.js`/`prefs.js`. One HM-installed extension (uBlock0) was
        active with a `path` under `~/.zen/...`, which proves the profile path — and the `.zen` →
        `.config/zen` symlink — resolves; the install was never the problem.

        The fix is two prefs in `modules/zen.nix`: `extensions.autoDisableScopes = 0` stops the
        auto-disable, `extensions.enabledScopes = 15` keeps every scope enabled. It only governs future
        discovery: entries already marked `userDisabled` stay off until toggled in `about:addons` or
        `extensions.json` is reset (back it up; the browser must be closed).
      '';
    };

    portable-library = {
      title = "The tool library is a portability set, so static linkage is the admission rule";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-22";
      summary = "`/Volumes/data/{bin-x86,bin-aarch64,bin-script,appimages}` is executed by NON-Nix machines (pentest targets, research boxes), so arch + glibc floor decide whether a file works, not its size. Fetches are non-interactive and static-only [[flake/policies.nix#library-fetch-is-static]]; the tree mirrors to BurgerNAS [[flake/policies.nix#library-crosses-the-wire]].";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/frieren/infra-stack.nix" "scripts/task/library-audit.sh" "scripts/task/library-fetch.sh"];
        tasks = ["data:library" "data:library:index" "data:library:fetch"];
        docs = ["AGENTS.md"];
      };
      body = ''
        Measured 2026-10-22 on frieren: 178 files, 9.5 GiB. bin-x86 38/52 static (glibc floor 2.39),
        bin-aarch64 33/43 (2.39), bin-script 18/18 scripts, appimages 65 (runtime static, payload
        unavailable). Two byte-identical pairs (11 MiB) and two eget re-fetch residues (`*.1`, 90 MiB).

        1. **eget prompts unless it can narrow the release.** `--asset` is required in the wrapper;
           without it a scheduled or remote run blocks on a picker. Two more traps: `find -newer`
           cannot detect the write (eget writes immediately, so a marker created afterwards is always
           newer — the wrapper diffs a directory snapshot), and `readelf` is not installed on every
           host that runs the audit, so the linkage probe reads the ELF header bytes and greps
           `GLIBC_` instead of shelling out to binutils.
        2. **Compression is the wrong lever.** AppImages are squashfs+zstd inside: `zstd -3` returns
           ratio 0.99 for ~5 s/472 MiB. Raw binaries do compress (0.36 at -3, 0.32 at -9) but every
           run then pays a decompress, which is the opposite of what a pentest toolkit wants.
        3. **A libc fork is a compatibility set, not duplication.** The four `simplex-chat` builds
           differ by target (22.04 / 24.04 / static musl); pruning them breaks the boxes that need
           exactly one. Byte-identical copies are the only safe prune.
        4. **Provenance cannot be derived from the file.** `.library.tsv` records sha256, repo,
           resolved tag, asset and date; the audit reports every file with no record, so an
           unattributed 100 MiB binary is visible instead of plausible.
      '';
    };
    exp-124 = {
      title = "EXP-124 — The public edge is a registry, not a vhost";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-24";
      priority = "P1";
      links = ["exp-118" "exp-116"];
      from = ["microvm-guests"];
      summary = "Stirling was six edits in six places — nginx location, tailnet gate, socket-proxyd, sshd Match, principals file, docs page — and the second tenant already retyped the gate. One `fleet.exposure` row should compile all six, and `edge:verify` should prove the row from both vantage points.";
      refs = {
        hosts = ["delphi"];
        modules = ["hosts/delphi/configuration.nix" "hosts/microvms/frieren-canary.nix" "modules/profiles/microvm-host.nix"];
        tasks = ["microvm:start" "checks:host"];
        docs = ["hosts/microvms/README.md" ".agents/deploy/hosts/delphi.md"];
      };
      body = ''
        **What exists.** delphi carries every public surface itself: the ACME vhost, `tailnetOnly`,
        `/microvm/*`, `/microvm/stirling/*`, `/slideshow/*`, the 2222 socket-proxyd, the `slides`
        hop account with its principals file, and the 302 that sends a public client to the
        tailnet name. Stirling was that list, once.

        **Why it does not scale.** Each tenant repeats the same decisions in a different place,
        and nothing checks that they agree. A third service typed from memory drops the gate or
        the redirect and still looks healthy from the machine that built it.

        **Shape.** `fleet.exposure.<name> = { guest, port, transport, path, audience }` in one
        module that emits the location and its gate, the socket unit, the `Match` block and
        principals file for a hop, the public redirect, the `data/services.json` card and the docs
        row. `audience` — `tailnet`, `public`, `cert-only` — is the only knob that decides who
        may reach it.

        **The part that makes it real.** `task edge:verify` walks the registry: every row from the
        public IP and from the tailnet, a spoofed `Host` from the public side must get 403/302, and
        a stopped guest must turn the row red in gatus within one scrape. Exposure that cannot be
        proved is a comment.

        **Boundary.** v1 admits only tenants co-located with the edge: a guest on frieren's brlan
        is not routable from delphi, and crossing that is EXP-118's signed door, not this.

        **Exit.** stirling and the deck are rows; a third tenant is one row plus one import;
        deleting a row removes every artifact in a single `systemctl --diff`; `edge:verify` green.
      '';
    };
    exp-125 = {
      title = "EXP-125 — Services stop being daemons: restore a guest, do not boot one";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-24";
      priority = "P2";
      links = ["exp-124"];
      from = ["microvm-guests"];
      summary = "Stirling costs minutes of emulated boot and holds 1.2 GiB of heap all day for a tool used twice a week. A snapshot of the booted guest turns start into a restore that keeps the volume, the store share and the identity, and gives the RAM back between uses.";
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["hosts/microvms/frieren-canary.nix" "hosts/microvms/base.nix" "modules/profiles/microvm-host.nix"];
        tasks = ["microvm:start" "microvm:stop"];
        docs = ["hosts/microvms/README.md"];
      };
      body = ''
        **The cost being paid.** Stirling is a JVM inside an emulated guest: minutes from
        `systemctl start` to first byte, and its heap held all day on a host that has 11 GiB.
        Idle tenants are the price of never booting them twice.

        **Shape.** Boot once with the volumes mounted, snapshot RAM plus device state to the state
        root, stop. The socket unit starts the guest on first connection and it resumes instead of
        booting. cloud-hypervisor does this over the API socket microvm.nix already exposes
        (`control.socket`); the qemu path on delphi uses `savevm`/`loadvm` on the same disk.

        **Named risks, not surprises.** virtiofs shares and the shared store must survive a
        restore (the host path is unchanged, which is the argument that they will); the ext4
        volume must be quiesced before the snapshot or fsck runs on resume; and a guest the
        bridge re-registers may come back without a route.

        **What this buys.** A service tier without resident cost: ten tenants stopped, one
        resumed. It is also the only way a TCG host serves something interactive on demand, since
        boot is the expensive part and the snapshot removes it from the request path.

        **Exit.** First byte under 2 s from a stopped state on delphi and on KVM; host RSS returns
        when it stops; five snapshot/restore cycles with no fs corruption; `microvm:snapshot`
        refuses while a volume write is in flight.
      '';
    };
    exp-126 = {
      title = "EXP-126 — A guest per gate: the memory rule becomes a cgroup, not a refusal";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-24";
      priority = "P2";
      links = ["exp-107" "exp-114" "exp-124"];
      from = ["microvm-guests"];
      summary = "`checks:flake` refuses below 16 GiB because a fleet eval once reached 6078 MiB and died at 137, and `oom-guard.sh` watches pressure around that absence of isolation. A microVM with a declared cap is the same gate with the blast radius removed — and it is the `sandbox:run` primitive underneath.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["flake/checks.nix" "hosts/microvms/base.nix" "hosts/microvms/frieren-canary.nix"];
        tasks = ["checks:host" "checks:flake"];
        docs = ["docs/ci-pipeline.md" "docs/nix-patterns.md"];
      };
      body = ''
        **The rule being worked around.** `nix flake check` was measured at 339.78 s / 6078.5 MiB /
        SIGKILL 137 here, so the task refuses under 16384 MiB, runs one host per process, and
        `oom-guard.sh` polls PSI and kills. All three exist because a gate shares a kernel and a
        memory pool with a live host.

        **Shape.** `GUEST=1` for `checks:host` and `checks:flake`: the same task in a microVM with
        declared `vcpu`/`mem`, the host store over virtiofs so nothing is copied, the result
        returned as the check's store path plus its journal. On frieren that is a KVM guest at
        native speed under a hard cap; on delphi it is TCG, which is still worth it for a keyless
        aarch64 gate that has no local alternative.

        **Generalise once.** Same runner, `task sandbox:run CMD=... MEM=8G`: boot, run, collect,
        destroy. The gate is the first customer; the second is untrusted agent output (`npx`,
        `pip install`, a fetched script) which today runs on the host because there is nowhere
        else to put it.

        **What it replaces.** Not the guard — a host without `/dev/kvm` keeps the script — but the
        refusal. The cap becomes a property of the run instead of a judgement about the machine.

        **Exit.** A deliberately memory-hungry command OOMs the guest and leaves the host's
        MemAvailable unchanged; `checks:host HOST=<h> GUEST=1` returns the same verdict as the
        local run on the same commit; cold start measured on both hypervisors and written down.
      '';
    };

    exp-127 = {
      title = "EXP-127 — A menu is a directory listing, never a library read";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-10-28";
      links = ["portable-library"];
      summary = "A login+hourly timer opened every AppImage in /Volumes/data/appimages with unsquashfs/readelf to write .desktop entries. On the netbook that was ~300 MB of NFS reads inside four minutes of boot on a Celeron over wifi; on frieren, 61 images and 50 CPU-seconds per run. It is deleted and gated: a launch is the only thing that may touch a library's bytes.";
      refs = {
        hosts = ["netbook" "frieren"];
        modules = ["modules/scripts/appimage-menu.nix" "modules/user/desktop/appimage-menu.nix" "flake/policies.nix" "modules/profiles/burgernas-client.nix"];
        tasks = ["checks:host" "checks:tasks"];
      };
      body = ''
        **What was wrong.** A launcher menu derived its names, comments and icons by opening each
        image's squashfs. That made a menu refresh a bulk read of a 6.9 GB library over NFS —
        automatic, hourly, and on every client that mounted it. Nobody sees a menu job; everyone
        sees the LAN and the TV stutter.

        **What replaced it.** `appimage-menu`: a glob of `*.AppImage`, a picker (fuzzel, else
        wmenu), `appimage-run` on the pick. No metadata, no cache, no timer. A stale icon cannot
        exist because no icon is written; a launch reads the image it launches.

        **The gate, not the deletion.** `#library-content-is-not-scheduled` fails the build when any
        script pairs a network mount with `unsquashfs`/`readelf`, when any **systemd** file names
        such a script, or when a `systemd.paths` watcher points at a library. Operator audits may
        still hash and extract — a scheduled unit may not.

        **Same shape, second instance.** `mnt-burgernas-peachcable.mount` sat in `activating` for
        30 min 1.47 s against a sleeping NAS: `x-systemd.mount-timeout` bounds mount(8), not the
        unit. The profile now sets `TimeoutStartSec = "10s"` on the unit itself.

        **Learning.** A timer that reads a shared mount is a bandwidth decision made by whoever
        wrote the unit, paid by every client on the LAN. Scheduled work may stat a library; only a
        user action may read it.

        **Exit.** Delivered: the unit is gone, `checks:host` is green on netbook/scratch/frieren,
        and the netbook's idle rx dropped from 974 KB/s to 59 KB/s.
      '';
    };

    open-129 = {
      title = "The Google grant's seven-day expiry tracks the exchange path, not just the app";
      kind = "open";
      status = "OPEN";
      date = "2026-11-15";
      priority = "P2";
      summary = "A consent driven through a real browser returned a refresh token with no expiry, where the same app minutes earlier returned 604799 s through a hand-made code exchange. Publishing the consent screen is now a recommendation, not the only cure; the claim holds if the grant is still permanent on 2026-11-22.";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/calendar.nix"];
        tasks = ["checks:gcal"];
        docs = [".agents/skills/calendar/SKILL.md"];
      };
      body = ''
        **What the number means.** The grant re-consented on 2026-11-15 22:20 carries
        `refresh_token_expires_in` = 604799, seven days minus a second. The grant that broke on
        13 Nov carried the same field as 52 s: the same seven-day window, consented inside its
        last minute. So the token was never merely stale — it had a birth defect with a known
        date. vdirsyncer is not at fault; `google.py` already asks for `access_type=offline`.

        **Why it cost three days.** When the window closes, every collection logs "Server
        disconnected" and the reason appears once per run as `(invalid_grant)`. 1616 error lines
        got read as a network fault. `checks:gcal` now puts the fact in one request and prints the
        moment the grant stops working, so the next death is read rather than inferred.

        **What the browser consent changed.** 2026-11-15 22:45, a consent driven through real
        Chromium under Xvfb returned a token with no `refresh_token_expires_in` at all, and
        `checks:gcal` reads it as a permanent grant. The same app, forty minutes earlier, produced
        604799 s through a hand-built code exchange — so the seven-day cap tracked the exchange
        path, not the publishing status alone. Publishing the consent screen stays a sensible
        recommendation; it is no longer the only cure, and `calendar-auth.sh` still refuses a
        time-based grant at consent time.

        **For the next re-consent.** `--headless=new` is refused ("This browser or app may not be
        secure"); the same binary under `xvfb-run` is not, driven by CDP over node's `WebSocket`.
        This account answers with a passkey, so one phone approval is required, and the TOTP comes
        from `cloak view google`. Keep the `--user-data-dir` profile at
        `~/.local/state/cdp-prof-headed` — a Google session is a cookie jar, so the profile is the
        credential and `/tmp` was the wrong home for it. Method recorded in the `calendar` skill.

        Exit: `task checks:gcal` still reports a permanent grant on 2026-11-22, one week after this
        consent, with no `invalid_grant` in the journal. If it has reverted, the cap is real and
        the console publish becomes the cure again.
      '';
    };

    exp-128 = {
      title = "EXP-128 — A mail manager on a 121M-param router, gated by trust rather than confidence";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-11-02";
      links = ["exp-115"];
      summary = "Needle 3 routes plain-English mail commands to himalaya on delphi: 10/11 on the shipped battery, one model call per bulk candidate at ~40 ms. Its confidence head does not separate a good archive from a bad one, so the nightly sweep archives only from a declared sender allowlist and holds everything else.";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/services/mail-agent.nix" "modules/services/mail-agent.py" "modules/scripts/needle-model.nix" "hosts/delphi/configuration.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **What was built.** `mail-agent` on delphi: a sentence in, a himalaya action out, dispatched
        by the needle3 binary the host already ran. Three tools — `search_mail`, `archive_mail`,
        `mark_read` — and a 06:30 user timer that sweeps bulk mail. Engine and weights moved to
        `modules/scripts/needle-model.nix` so the pinned hash has one home.

        **The candidates.** neverest+pimdir fits a large corpus and not this one: Gmail answers
        `envelope search` server-side in ~1 s at this volume, so a sync daemon and a store would be a
        moving part bought before the need. mxr is unpackaged and owns the same index role.
        mailbox-autopilot was rejected as a service and copied as a policy (dry run, audit log,
        reversible actions). himalaya-mcp adds a Node runtime and a listening surface for what a CLI
        plus a timer already does. needle3 adopted; himalaya 2.2.1 as-is.

        **Two findings shaped it.** A `trash_mail` tool was never selected — "delete the spam" went
        to `mark_read` twice out of two — so delete was removed from the schema rather than gated.
        And a dry run approved 13 messages including a Dropbox "connected a new app", a GitHub "new
        SSH key", a Stripe "unrecognized device" and a real classifieds inquiry, at 0.22–0.47. No
        threshold admitting honest newsletters excludes those, so the sweep fails closed against
        `sweep.trustedSenders` (six marketing senders, each earned in a dry run) and prints why every
        held message was held.

        **Needle is a tool caller, not a classifier.** Verb-first one-line descriptions lifted the
        dispatch battery from 7/11 to 10/11; the miss is a read-only search. A label is a decision and
        is not its job: a keep/archive battery scored needle3, julia-1 and laya at 3/10 each (nine of
        ten archive), so that tool schema is deleted and the sweep decides by rule. Mutations are
        dry-run until `--apply`, and a caller the router merely *suppressed* also needs `--force`.

        **Evidence.** `--self-test` 10/11; the unit ran 2.6 s / 86 MB peak and archived 7, all seven
        left the inbox, one restored from All Mail on demand. The audit stores `message-id`, not the
        uid, because Gmail reassigns uids per mailbox (310172 in INBOX, 621165 in All Mail).
        Operations: docs/mail-agent.md. Open: neverest stays deferred, revisit past ~1k envelopes.
      '';
    };

    exp-129 = {
      title = "EXP-129 — Quotient closures: a per-feature fanout probe and a CA cutoff demo";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-11-19";
      refs = {
        hosts = ["delphi"];
        modules = ["lib/cache-policy.nix"];
        tasks = ["dev:closure:native"];
        docs = ["docs/nix-patterns.md"];
      };
      summary = "Measured on delphi: 19,034 drvs per toplevel, 28-29 s and 3.0 GiB to instantiate. Feature files are nested imports of configuration.nix, and disabledModules is a no-op even with the key read from the module graph, so per-feature fanout needs an import rewrite. Both delphi registries now guard on option presence, and CA early cutoff is demonstrated by drv hashes.";
      body = ''
        **Question.** Split a host closure into an invariant core and per-feature deltas?
        The numeration system is a red herring: a cryptographic hash avalanches
        regardless, so the split has to be structural (which key is hashed) and the
        invariant half must be a *content* address.

        **Cost, measured (delphi, 2026-11-19).** Toplevel: 19,034 drvs, 28-29 s
        and 3.0 GiB peak, so ~30 s per feature — not a gate. Rebuilding the host
        from its own assembly reproduces the real drv exactly, which is the
        baseline an import rewrite can stand on.

        **Removal is not a list operation.** Delphi's module list has 15 entries;
        its feature files are `imports` *inside* configuration.nix. And
        `disabledModules` is no better: with the exact key from the module graph
        `extendModules` returns a byte-identical drv, as do relative, absolute and
        path-value keys — a clean 0%, so no probe was registered.

        **Removability, paid for.** Both delphi registries read each port from the
        option that owns it, so a removed module failed the host eval; a row now
        exists only while the option does (`lib.optionalAttrs (lib.hasAttr …`).
        `checks:host delphi` passes and every mount is still listed.

        **Early cutoff, measured.** ca-derivations is off daemon-side; a rooted
        store with it on builds the demo. Two derivations, identical output,
        different env: distinct drv hashes (54j0…, 85i2…), one output (wsapf…);
        the dependent resolves to the same output (kzp6…) and is not rebuilt.

        **Exit.** A fanout instrument that rewrites the host file's own imports,
        proves the unfiltered rebuild equals `.#nixosConfigurations`, and collects
        from one source copy. Then one row per feature says whether any feature
        owns more than a rounding error of the graph.
      '';
    };

    triage-remote-second-opinion = {
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-19";
      title = "Mail triage asks a remote model about the envelope, never the body";
      summary = "The mail second pass can ask deepseek-v4-flash-0731:free through llm.onerouter.pro, on the envelope only, because julia-1 (144M) files marketing as a person and laya (421M) parks it in review. Bodies never leave the host; the module default stays local and a host opts in.";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/services/email-triage.py"];
        tasks = ["agents:mail:triage"];
        docs = ["docs/email-archive.md"];
      };
      body = ''
        Measured 2026-11-19 on delphi's 26-row human queue:
        - julia-1 called a 30%-off marketing send `person` (0.39) and laya left
          the Freebuff, OpenRouter and Craft sends in `review`; both tiers sit in
          front of a person, which is the one queue a model may not pad.
        - The remote pass over the same envelopes produced 12 digest/robot
          verdicts that closed, one human reply kept as `person`, and every
          `action` row untouched. It overrides the local pair in both
          directions under the same protected-signal gate.
        - It posts sender, subject and labels, never a body. The route is a third
          party, so the content of a mailbox is not the classifier's to send.
        - The key is read by name from `ai-services-shared-env`, so the unit's
          environment carries no other key. `secondBackend = "systemone"` stays
          the default and delphi sets `openai`.
      '';
    };

    nix-cache-edge = {
      title = "NIX-CACHE-EDGE — a third cache tier that reads, and never signs";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-11-02";
      refs = {
        docs = ["docs/nix-cache-edge.md"];
        tasks = ["dev:nixcache:check" "dev:nixcache:deploy" "dev:nixcache:push" "dev:nixcache:gc" "dev:nixcache:size" "dev:nixcache:sync" "checks:nixcache:probe" "checks:nixcache:fleet" "checks:invalidation"];
        hosts = ["delphi" "frieren"];
      };
      summary = "harmonia stays the LAN cache and cachix the 5 GB WAN cache; delphi adds a 10 GiB R2 bucket behind a GET-only Worker, registered after cachix. A push asks every non-LAN substituter in the registry first and uploads only what none of them has, then refuses the run if it would cross the budget — a buffer for the fleet's delta, not a mirror of nixpkgs and not a store for system closures.";
      body = ''
        **Why a third tier.** CI refuses the LAN cache by design, so a runner cannot substitute what
        frieren or delphi built. R2 charges no egress; 10 GiB is the free tier.
        **The edge never signs.** narinfo is signed by the pusher (`secret-key=`), so a Worker key would
        reimplement Nix's fingerprint; `CACHE_AUTH_TOKEN` was refused because `nix copy` has no `--header`.
        **A buffer, not a mirror.** Each path is HEADed against every non-LAN cache in the registry
        (cachix, the bucket, cache.nixos.org, numtide, nix-community, nix-gaming, determinate); only
        misses upload, and a push crossing 10 GiB is refused before writing, naming its five largest
        paths — hence the entry sits immediately after `cachix` in every order.
        **A closure is never stored; a delta is.** Delphi's closure is 2728 paths / 18.48 GiB; of the 570
        cache.nixos.org lacks, 167 are on cachix, 11 on nix-community, and 27 — 1.40 GiB, the llm-agents
        tools (`dsh` 685 MiB, `antigravity-cli`, `hermes-agent`, `freebuff`) — on `cache.numtide.com`,
        leaving 365 paths / 771 MiB unique: 10 GiB holds ~13 systems where a hardcoded three-cache dedupe
        would have uploaded 2.39 GiB of the same closure. So the edge is not self-contained — a client
        substituting a system needs the rest of the registry (`lib/cache-registry.nix`).
        **Evidence.** Live at `https://nix-cache-edge.jisifu.workers.dev` (key `delphi.edge-1`), where a
        `hello.drv` closure reported `2/342 unique` and `nix path-info --store <edge>` accepts the signature.
        **Traps, measured.** `nix copy` is recursive by default; `--no-recursive` needs valid references
        (stubs fix that and are never uploaded); `nix copy --to s3://` wrote nothing against a fresh bucket
        and exited 0; `rclone purge` deletes the bucket; a 404 seen before a push needs `--refresh`.
        **Retention.** `dev:nixcache:gc` collects in cachix's shape (oldest first until under 75 %, 50 paths
        a run, never a narinfo without its nar); the R2 lifecycle rule is a backstop at **365 days**, not
        cachix's 90 — age-on-upload is a proxy, since the Worker never sees a cached request.
        **Scheduled, routed by arch.** `dev:nixcache:sync` builds **active** hosts only, natively where the
        arch owns the official caches (delphi compiles aarch64, itself and minyx), else `--max-jobs 0`
        against `/etc/nix/machines`, printing SKIPPED rather than compiling x86_64 on 2 OCPU;
        `nixcache-sync.timer` (user unit: keys decrypt with the operator's age key) then syncs
        `delphi,minyx`, and `checks:nixcache:fleet` holds the enablement line.
        **A microfix has a price.** `checks:invalidation` scopes a diff to the hosts it can reach and counts
        what `nix build --dry-run --builders ""` would compile (1–3 a fix, hundreds an overlay change),
        failing over `MAX_BUILDS` and naming the derivations.
      '';
    };

    agent-contract = {
      title = "AGENT-CONTRACT — done is an exit predicate, not a sentence";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-11-02";
      refs = {
        docs = ["docs/agent-contract.md"];
        tasks = ["checks:host"];
      };
      summary = "One exit predicate per kind of change, one evidence record per predicate: FEATURE is checks:host plus the behaviour exercised, DEBLOAT is no consumers plus a negative closure delta, DESLOP is format and lint unchanged, INVESTIGATE is a graph path plus an evaluated attribute. Task citations on the page are gated against the compiled graph.";
      body = ''
        **Adopted.** `docs/agent-contract.md` names the predicate that makes a turn
        finished, because "done" in prose drifts within twenty turns. The page is a
        normative doc, so its `[[flake/policies.nix#…]]` citations are checked, and
        `checks:tasks` fails any `task <name>` it names that the graph does not have
        (wildcards resolve by prefix).

        **Refused, with the instrument that replaces each.** A `nix flake check`
        exit is the memory-gated force on an 11 GiB host, so DEBLOAT ends at
        `checks:host` plus `dev:closure:diff`. A sha256 of `config` as the DESLOP
        predicate is the whole-toplevel force (>120 s with swap), so DESLOP ends at
        the format and lint gates plus `checks:host` before and after. A `nix:eval`
        catch-all task was refused too: it is the shortest path to both of the
        above, and the ladder in `task-plane` says eval the attribute you need.

        **No deny hooks.** A `PreToolUse` hook on grep/cat binds one client and no
        other, and this tree has none; the durable form is the read rule scoped to
        *structure* (graph and evaluation, not prose) plus a gate. `prove:*` was not
        created either — every predicate above already has a `checks:*` task, and a
        second namespace would be a second home.

        **Frames stay as they are.** xs has `outcome` (`done`/`in_progress`/`blocked:`
        /`failed:`) and `claims`, and no update or delete route: a live claim is read
        from the tail, never mutated. A role/status machine on top is a service change,
        not a doc change.
      '';
    };

    appwrite-dragon-court-abandoned = {
      title = "An abandoned hosted backend is allowed to die, not restored";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-11-03";
      summary = "Appwrite project \"dragon court\" (org bountystash, created 2024-04-21, id 6624819f34aa833c8925) expires 2026-11-17 and was left to go: no file in this tree, no shaoyanji or Bountystash repo and no sops key mentions Appwrite, so there is no consumer to break, and restoring only re-arms the inactivity timer that produced the warning.";
      body = ''
        **What it was.** A Cloud project in the `bountystash` organisation, created
        2024-04-21 from its id timestamp and never wired to anything after the trial.
        The one local thing called `dragoncourt` is a Neocities site whose `site/` is
        the artifact (`projects/neocities-dragoncourt`), with no fetch and no backend.

        **Evidence of no dependency (the reason this is a decision, not a guess).**
        `grep -rni appwrite` over `.nix`/`.md`/`.toml`/`.yml`/`.py`/`.sh` returns
        nothing; `gh search code appwrite --owner shaoyanji` and `--owner Bountystash`
        both return `[]`; `sops -d modules/secrets.yaml | yq -r 'keys[]' | grep -i
        appwrite` returns nothing. A backend with no caller, no key and no CI job has
        no blast radius when it goes.

        **Why not restore.** Restoring stops the clock, not the question: the project
        pauses again on inactivity and mails the same 14-day warning, so the record
        would keep a decision that was only deferred. Look-then-decide (restore,
        browse databases and storage, export, then delete) was offered and declined.

        **What would reopen it.** A new Appwrite-backed project starts as a module
        that names the project and a task that reaches it, never as a resurrection of
        this id: an account nobody can point at from the tree is not a host.
      '';
    };

    open-manual-steam-fill = {
      title = "The nightly prefill window is redundant once fills are operator-driven";
      kind = "open";
      status = "OPEN";
      date = "2026-10-28";
      priority = "P3";
      links = ["exp-127"];
      summary = "`steam-cache.prefill` fills the LAN cache at 02:00 by default (5 h cap), while the operator now fills by hand against the same cache. Two owners of one download window compete for the line.";
      refs = {
        hosts = ["frieren"];
        modules = ["modules/services/steam-cache.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **Decision pending.** The operator fills Dota (and the next title) manually, watching the
        line; the timer then only adds a second unattended window against the same WAN.

        **Exit.** Either delete the timer (`prefill.enable = false` and the calendar) once manual
        fills are the habit, or keep it and record why the unattended window still earns its
        bandwidth. Not both: the measured cost of two fills racing is the Dota accept failure of
        2026-10-28.
      '';
    };

    open-steam-dns-steer-run = {
      title = "The CDN steering allowlist is on, with no observed client download yet";
      kind = "open";
      status = "OPEN";
      date = "2026-11-09";
      priority = "P3";
      links = ["open-manual-steam-fill"];
      summary = "`steamCache.dnsSteer` is deployed as `content` since 2026-11-09: the 2026-10-28 matchmaking failure was the *zone* record catching `cm-01-fra1`, a sibling of the download names, not steering itself. The allowlist cannot match `cm-*`, so it is on; what is still unproven is that real chunk traffic lands on the four `cdn.steampipe` names.";
      refs = {
        hosts = ["frieren"];
        modules = ["modules/services/steam-cache.nix" "hosts/frieren/dns.nix"];
        docs = ["docs/steam-cache.md"];
        tasks = ["checks:host"];
      };
      body = ''
        **What is built.** `content` emits exactly `cdn.steampipe.steamcontent.com`,
        `lancache.steamcontent.com`, `steamcdn-a.akamaihd.net`, plus `dnsSteerDomains`; every other
        name in the zone, matchmaking included, resolves publicly by construction. `zone` refuses
        without `dnsSteerZoneAcknowledged`.

        **Why it is on (2026-11-09).** The 2026-10-28 failure was diagnosed as the zone record, not
        the cache: `address=/steamcontent.com/` also swallowed `cm-01-fra1.steamcontent.com`, the
        EU-West connection manager, and match accepts stopped. `content` emits only the download
        CDNs, the detection name and the installer CDN, so `cm-*` resolves publicly by construction.
        It ships with `dnsSteerDomains = ["cache9-fra1.steamcontent.com"]`, the one observed download
        host not under `*.cdn.steampipe`, added by exact name and never by suffix.

        **Exit.** One client download shows a HIT at the front (`X-Steam-Cache` or
        `tier_growth_bytes`) and a Dota match still accepts — then this note is DELIVERED. If the
        observed download set differs from the allowlist, the missing name is added by exact name.
      '';
    };

    gemini-capsule = {
      title = "fleet.frieren.lan answers over Gemini on 1965, from the same markdown";
      kind = "open";
      status = "DELIVERED";
      date = "2026-10-29";
      priority = "P3";
      summary = "molly-brown serves the fleet docs as gemtext on `gemini.frieren.lan:1965`, projected by `lib/gemtext.nix` from the same markdown the HTTP site renders; CGI runs through a relative `CGIPaths` entry, so `/cgi-bin` executes inside the capsule store path.";
      refs = {
        hosts = ["frieren"];
        modules = [
          "hosts/frieren/gemini.nix"
          "lib/gemtext.nix"
          "overlays/molly-brown.nix"
        ];
        docs = ["docs/frieren-access.md"];
      };
      body = ''
        **Upstream has no releases.** `tildegit.org/solderpunk/molly-brown` publishes zero tags and
        zero releases, so `overlays/molly-brown.nix` pins master (`9627852`, 2026-05-25). The go module
        set is unchanged from nixpkgs' 2023 pin, so only `src` and `version` move.

        **`CGIPaths` must be relative.** `config.go` joins a relative entry to `DocBase` and leaves an
        absolute one alone, then compares it against a resolved filesystem path — `/cgi-bin` can never
        match a path under `DocBase`; `cgi-bin` does. Cost one smoke test to find.

        **Projection, not a second tree.** `lib/gemtext.nix` converts `docs.generatedPages` plus the
        repo's own markdown into `.gmi`, rewriting internal links to absolute capsule paths. md2gemini
        is marked broken on python 3.14 in this nixpkgs, hence `lib/gemtext/md2gemtext.py`.        **Exit.** A client that verifies against `modules/config/tls/frieren-lan-ca.pem` gets
        `20 text/gemini` from `/`, `20` with the echoed query from `/cgi-bin/hello?x=1`, `51` for
        a missing page and `53` for a foreign host.
      '';
    };

    gemini-mail-reader = {
      title = "The email archive answers over Gemini on delphi's tailnet capsule";
      kind = "open";
      status = "DELIVERED";
      date = "2026-11-08";
      priority = "P3";
      links = ["gemini-capsule"];
      summary = "`gemini://delphi.cloudforest-kardashev.ts.net:1966/mail/` searches and reads the archive: one CGI program in three modes (`email`, `latest`, `read`) querying the loopback API, mounted as a fragment on the tailnet capsule only, so the internet-facing 1965 cannot reach it.";
      refs = {
        hosts = ["delphi"];
        modules = [
          "hosts/delphi/gemini.nix"
          "lib/gemini-mail.nix"
          "lib/gemini-mail/mail.py"
          "lib/gemini-portal.nix"
        ];
        docs = [
          ".agents/deploy/hosts/delphi.md"
          "docs/email-archive.md"
        ];
        tasks = ["infra:deploy:host:delphi"];
      };
      body = ''
        **A page cannot be generated.** Mail arrives hourly, so a capsule compiled at deploy
        time answers yesterday's archive. The reader is CGI for that reason, and the fragment
        exists only to carry `cgi-bin/` into the capsule.

        **The fragment is copied, never symlinked.** molly-brown resolves a CGI's filesystem
        path before matching `CGIPaths`; a symlink-joined fragment resolves outside `DocBase`
        and the script is never executed. `cp -r` onto the base capsule is the fix.

        **The public port stays untouched on purpose.** 1965 keeps the portfolio with no
        `CGIPaths` and no mail tree, so a request there cannot reach the archive even though both
        instances share the archive on loopback.

        **Exit.** Met on 2026-11-08, over TLS on 1966: `/mail/` `20`; `/cgi-bin/email` `10` with
        no query and 13 hits for `invoice`; `/cgi-bin/latest` 30 links; `/cgi-bin/read?<id>` `20`
        with two fences; `51` for an unknown id; `40` with the API unreachable. And on 1965,
        `/mail/` and every `/cgi-bin/*` path `51` while `/` still serves `20`.
      '';
    };

    gemini-turns-reader = {
      title = "The agent turn log answers over Gemini beside the mail reader";
      kind = "open";
      status = "DELIVERED";
      date = "2026-11-08";
      priority = "P3";
      links = ["gemini-capsule" "gemini-mail-reader"];
      summary = "`gemini://delphi.cloudforest-kardashev.ts.net:1966/turns/` shows the newest turns, a word search and the open claims from the same shim the agents write through — four wrappers over one program, linked from the portfolio index beside `/mail/`, on the tailnet instance only.";
      refs = {
        hosts = ["delphi"];
        modules = [
          "hosts/delphi/gemini.nix"
          "lib/gemini-turns.nix"
          "lib/gemini-turns/turns.py"
        ];
        docs = [
          "docs/gemini-turns.md"
          "docs/agent-turns.md"
          ".agents/deploy/hosts/delphi.md"
        ];
        tasks = ["infra:deploy:host:delphi"];
      };
      body = ''
        **A CGI gets no environment.** molly-brown sets `cmd.Env = []string{}` before exec,
        so a unit's `EnvironmentFile` never reaches a capsule script — the obvious answer
        does not work. The token is a sops template rendered to root:gemini 0440 under
        `/run/secrets/rendered` (0751, so the group can traverse), and the wrapper carries
        the path. The capsule's store path stays value-free; the cost is that it holds the
        fleet token, which can append, because the shim has no read-only scope.

        **Attachments stay unserved, by decision.** The mail page names an attachment and
        never serves it: the archive holds the file, and a capsule copy would be a second
        home for storage that does not belong in a store path.

        **Exit.** Met on 2026-11-08 on 1966: `/turns/` 20 with the landing page;
        `/cgi-bin/turns` 10 with no query and 12 hits for `gemini`; `turns-latest` and
        `turns-live` (3 open claims) 20; `/cgi-bin/turn?<id>` 20 with its rationale in two
        fences; 51 for an unknown id. On 1965 `/turns/` and `/cgi-bin/turns` answer 51 while
        `/mail/` still serves 20 and the index links both readers.
      '';
    };

    open-pihole-admin-path = {
      title = "`/admin` on the Pi-hole vhost is a 404, and every old link points there";
      kind = "open";
      status = "DELIVERED";
      date = "2026-10-29";
      priority = "P3";
      links = ["resolver-never-breaks"];
      summary = "FTL 6 serves its UI at `/`, so the vhost rewrites `/admin[/…]` onto it rather than moving webhome (FTL's own redirect would emit an absolute URL and leak the loopback bind). `/admin`, `/admin/`, `/admin/queries` and `/admin/groups` answer 200; FTL stays on 127.0.0.1:8080.";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/frieren/reverse-proxy.nix"];
        docs = ["docs/frieren-access.md"];
        tasks = ["checks:host"];
      };
      body = ''
        **Measured 2026-10-29 (core 6.4.2, web 6.6, FTL 6.7.1).** `/admin` is a 404 straight from FTL
        (`webhome = "/"`) while `/` is 200 and `/api/info/version` answers — a path bug, not the
        resolver.

        **Landed.** A prefix location rewrites `/admin[/…]` to the UI's own routes before `proxyPass`,
        so a deep link lands where the UI itself would have linked (`/admin/queries` → `/queries`).
        A path FTL does not serve (`/settings` on 6.7.1) stays a 404: no rewrite can invent a route.
        The listener is unchanged — FTL keeps `127.0.0.1:8080`, and nothing widens the bind.

        **Prove it.** `for p in /admin /admin/ /admin/queries; do curl -sk -o /dev/null -w "%{http_code} "
        https://pihole.frieren.lan$p; done` prints        `200 200 200`.
      '';
    };
    lfm3-shell-project = {
      title = "lfm3-shell — a fine-tune measured up to the GPU and no further";
      kind = "open";
      status = "BLOCKED";
      priority = "P2";
      date = "2026-10-30";
      summary = "A nushell next-command fine-tune in `~/work/lfm3-shell` on delphi: dataset, baselines, QLoRA and GGUF pipeline all run and measured, and the one missing piece is GPU time — every GPU limit reads 0 on this trial tenancy.";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/sops.nix"];
        docs = ["docs/sops-rekey.md"];
      };
      body = ''
        **Where.** `~/work/lfm3-shell` on delphi, and deliberately not a git repo yet: the
        artifact is the measurement, so the status is this note rather than a commit.

        **Built and run.** `build_dataset.py` (atuin → 6,147 train / 300 eval300, redacted),
        `run_score.sh` + `compare.py` (each model's own chat template, 300 held-out items),
        `train_qlora.py --dry-run` (data path checked without torch), `make_gguf.sh`,
        `orchestrate.sh` (launch → transfer → train → stop box → score here), `oci-gpu.sh`.

        **What the numbers already settle.** LFM3-1.7B is the wrong base: 1.3 % exact against
        4.0 % for a 0.5B Qwen2.5-Coder, at 1.8x the latency. A fine-tune has to clear 8.7 %
        acceptable (the 0.5B base); under 4.7 % it loses to a BM25 `grep`.

        **Blocker, named.** `oci limits value list` reports 0 for every GPU shape while
        `standard-a1-core-count` reads 41, so the API answers and the quota is absent — no
        trial tenancy rents a GPU. The A1 fallback measured 4 tok/s → 47 h/epoch, which makes
        CPU a non-option rather than a slow one. Either the account upgrades to PAYG (an
        operator UI action, not a code change) or the box is rented elsewhere.

        **Exit.** A tuned Q4_K_M scored here on eval300 and reported next to base
        (`./run_score.sh tuned-q4 … && python3 compare.py out/qwen05-base.json out/tuned-q4.json`);
        if it lands under 8.7 % acceptable, set REJECTED with that number.
      '';
    };
    llm-agents-toolbox = {
      title = "Agent CLIs come from llm-agents.nix — installed on the full tier, one nix shell away everywhere else";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-10-30";
      summary = "`pkgs.llm-agents.<name>` (agent-browser, qmd, toon, pdfvision, reasonix, parallel-cli) is the source for agent tooling, installed only on the `full` AI tier because agent-browser drags in a ~700 MiB Chromium. \"Not installed\" is not \"not available\": the flake is prebuilt on cache.numtide.com, so `nix shell github:numtide/llm-agents.nix#<name>` is ~17 s cold and instant warm.";
      refs = {
        modules = ["modules/user/ai/default.nix" "flake/module-sets.nix"];
        docs = [".agents/skills/agent-browser/SKILL.md"];
      };
      body = ''
        The overlay is wired in `flake/module-sets.nix`; consumers name the package
        `pkgs.llm-agents.<name>`, and `modules/user/ai/default.nix` gates the heavy half of the
        suite on `profiles.ai.tier == "full"` so mobile clients (aristotle) keep the light set.

        What that means for an agent, and the reason this note exists: a skill naming a tool is
        not evidence the tool is on PATH. Check first, then run it from the flake instead of
        substituting hand-rolled curl for the tool's own job — measured 2026-10-30, when
        agent-browser was absent on this host but available in ~17 s (`agent-browser 0.41.0`).

        ```bash
        nix shell --option builders "" github:numtide/llm-agents.nix#agent-browser \
          -c agent-browser open https://example.com
        ```

        `--option builders ""` matters: a cache hit is free, but the same command without it
        can dispatch a compile to nixbuild.net and spend the month's budget.

        The repo does not re-export the packages — `packages.<system>` is
        `{artifacts, cli, servers, sites}` — so there is no `.#llm-agents.*` shortcut; ad-hoc
        runs use the `github:` form while the `llm-agents` flake input keeps host closures on
        the same revision. Tool procedures live in one skill each (`agent-browser` covers the
        on-demand shell and the Basic-auth header, because Chrome drops credentials in a URL).
      '';
    };
    agent-turns-xs-endpoint = {
      title = "agent.turns on delphi — a tailnet-only xs log the shim keeps append-only";
      kind = "decision";
      status = "DELIVERED";
      date = "2026-10-30";
      summary = "cablehead xs 0.14.2 on delphi, Unix socket only, behind a bearer-authenticated shim that owns dedup and forbids update/delete, mounted on the tailnet at 8449 so agents can check claims and base commits before they edit.";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/services/agent-turns.nix" "modules/services/agent-turns/shim" "hosts/delphi/configuration.nix"];
        docs = ["docs/agent-turns.md" "AGENTS.md"];
        tasks = ["infra:xs:export" "checks:host"];
      };
      body = ''
        **Why a shim and not xs directly.** xs 0.14.2 documents no Authorization
        header and no 401, and it ships DELETE and `/import` on the same socket, so
        an exposed xs would be a network-reachable erase. The shim is the only
        surface: POST /v1/events and GET /v1/events, bearer token from sops, no
        update or delete route at all (405), and the store is owner-only so no
        local user can bypass it either.

        **Dedup is ours.** xs generates frame ids and documents no client-UUID
        key, so the shim keeps `uuid → frame id` in sqlite next to the store: a
        retried post returns the stored id with 200 instead of a second entry.

        **Schema.** `agent.turns` holds one small entry per turn, keyed by
        filename `<repo>:<task-id>` in `subject` so `?repo=` filters without
        scanning values; unknown keys are rejected, which is what keeps a
        transcript out. Nothing about it changes merge authority.
      '';
    };
    turns-fusion-plane = {
      title = "Postgres, the turn ledger and AGENTS.nix fuse as a projection, each answering what it is compiled for";
      kind = "proposal";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-11-18";
      summary = "Frieren's postgres gains a turn and note projection built from the turn dump it already receives, keyed by repo path, so SQL joins what the ledger, the app databases and AGENTS.nix each answer best; dissemination follows .#epistemics.table and nothing writes back upstream.";
      refs = {
        hosts = ["delphi" "frieren"];
        modules = ["modules/services/agent-turns.nix" "modules/services/turns-dashboard/web/graph.html" "modules/services/email-archive.nix"];
        docs = ["docs/agent-turns.md"];
        tasks = ["infra:xs:export"];
      };
      body = ''
        **Three stores, three jobs.** Postgres on frieren holds rows that are
        *updated* — the mail archive, the vector tables, the app databases — so it
        is the only one that aggregates, joins and retains. The xs ledger on delphi
        holds events that are never updated, so it answers "who touched this, and
        what is open now". `AGENTS.nix` holds authored claims with validated refs,
        so it answers "why is this the way it is, and what is the exit".

        **Fusion is a projection, not a fourth store.** Frieren already receives
        the 03:05 `frames.jsonl` dump, so a timer loads it into `turn` and
        `turn_claim` and loads `.#agentsNotes.index` into `note`. The join key is
        the repo path in `claims[]` against `refs.modules`, not a title — the same
        edge `.#knowledgeGraph` draws, now queryable at scale.

        **Dissemination follows the epistemics table.** `.#epistemics.table` names
        which source settles which claim, so the loader copies and never merges: a
        turn is not rewritten into a note, a note is not a transcript, and nothing
        writes back upstream.

        **Exit.** A `checks:fusion` gate that counts the three sides — frames, rows,
        notes — and fails when the projection is behind, plus one routing line per
        claim kind naming the store that answers it.
      '';
    };
    agent-turns-backup-cadence = {
      title = "agent.turns backup — the export hook exists, the cadence is Joiu's call";
      kind = "open";
      status = "OPEN";
      date = "2026-10-30";
      summary = "`task infra:xs:export OUT=<dir>` writes frames.jsonl plus cas/ from the agent-turn store, the dump shape `xs import` restores; how often it runs and where it lands is undecided on purpose.";
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/xs-agent-turns-export.sh" "taskfiles/infra.yml"];
        tasks = ["infra:xs:export"];
      };
      body = ''
        The hook is callable and documented; it schedules nothing and picks no
        target, because a guessed cadence is a promise nobody measured. OUT must
        not exist, so a run can never overwrite an earlier export.

        **Exit.** Either a timer with a target host, or a recorded REJECTED if the
        store is deemed reproducible enough not to back up. `xs cat` needs a pipe
        and `xs import` takes one frame per call — the restore loop is in the
        script header.
      '';
    };
    codespace-mode = {
      title = "A codespace is a mode: the gh-cs traps live in tasks, not in a session log";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-02";
      summary = "Working in a GitHub Codespace cost four failed attempts — `ssh -q`, `gh cs cp`, `git push` inside the clone, and a poll for a state that does not exist. They are now `codespace:*` tasks over one script, so the next session starts from the trap list instead of rediscovering it.";
      refs = {
        modules = ["taskfiles/codespace.yml" "scripts/task/codespace.sh"];
        tasks = ["codespace:exec" "codespace:put" "codespace:push" "codespace:stop"];
        docs = [".agents/skills/codespace/SKILL.md"];
      };
      body = ''
        The mode is not fleet infrastructure: a codespace is absent from
        `inventory.toml`, nothing here configures it, and GitHub deletes its disk
        on a retention window. So the note keeps the transport decisions and the
        skill keeps the procedure.

        The load-bearing ones: files cross as base64 over the ssh channel because
        `gh codespace cp` failed in both directions; a commit leaves as a bundle
        and is pushed from the clone whose origin matches the codespace's
        repository, because that clone had no credential helper of its own; and
        `stop` polls for `Shutdown`, the only terminal state `gh codespace list`
        reports. A stale codespace clone is a hazard after an upstream rewrite,
        not just stale — it still holds the purged objects.

        **Exit.** `checks:tasks` names all nine tasks and `skills-schema` passes.
        A later session that needs another flag adds it to the script, never to a
        transcript.
      '';
    };

    needle3-resident-at-login = {
      title = "The edge caller works at login and is still off: its win case is a loss";
      kind = "decision";
      status = "REJECTED";
      date = "2026-11-02";
      summary = "Built, activated on delphi and switched off the same day: `programs.edgeCaller` works and `checks:edge:resident` answers 11/11 with nothing started by the check, but `flake/daemons.nix` scores it ev = -1.1 s against the agent naming the pattern itself, and the Kelly gate refuses a resident helper whose best case is a loss.";
      refs = {
        modules = ["modules/user/edge-caller.nix" "scripts/task/edge-serve.sh" "scripts/task/edge-sidecar.sh" "scripts/task/edge-check.sh"];
        hosts = ["delphi"];
        tasks = ["checks:edge" "checks:edge:resident"];
        docs = ["docs/agent-contract.md"];
      };
      body = ''
        The unit works: enabled at login, it owns the daemon's lifecycle, and
        `checks:edge:resident` answers 11/11 with nothing started by the check. It is
        off anyway, and the arithmetic is why.

        **The gate that decided it.** `flake/daemons.nix` scores a resident helper
        ev = p*save - (1-p)*cost against what the agent would do instead, at 50 tok/s:

          p 0.5   save -1.0 s   cost 1.2 s   ev -1.1 s

        `save` is negative because the dispatcher's call is 54 B generated against 40,
        its answer 605 B read against 217, and its round trip 1073 ms against 145 — the
        WIN case is a loss. No accuracy rescues that; the single-tool experiment
        (needle3-single-tool-surface) is the measurement of why accuracy does not
        matter here.

        **What the diagnosis cost, and what it found.** Activation failed twice for
        real reasons — the flake path is CWD-relative and systemd starts in $HOME, and
        the surface cache pruned with `xargs`, which the unit's bounded PATH lacks —
        and then the gate read 1/11: `*-needle-[0-9]*` matched a leftover needle-2, so
        the one-shot half of the comparison ran a different model than the unit.
        Pinned to `*-needle-3`, 11/11.

        **What survives.** `edge-serve.sh`, `EDGE_REQUIRE_UP=1`, `checks:edge:resident`
        and the module stay: the pipeline path (`agents:call:batch`) has no alternative
        to NL→lookup, and the Pareto refusal gate is model-free. Enabling it for an
        agent would need `ev > 0`, which this arithmetic cannot reach while the typed
        task exists.
      '';
    };

    needle3-single-tool-surface = {
      title = "One generic graph tool buys 50 ms and costs the specific description";
      kind = "experiment";
      status = "REJECTED";
      date = "2026-11-02";
      summary = "Rejected on the build the tree actually pins: needle-3 scores the same on both surfaces (top-1 8/11, model-exact 3/6) and costs 50 ms more for six tools, so the 4x saving and the 1-of-6 collapse that motivated this were both measured on a leftover needle-2.";
      refs = {
        modules = ["scripts/task/toolcall.sh"];
        tasks = ["checks:toolcall"];
        docs = ["docs/agent-contract.md"];
      };
      body = ''
        Measured 2026-11-02 on delphi, on the build `modules/scripts/needle-model.nix`
        pins. `TOOLCALL_SINGLE=1` reproduces:

          surface           engine    top-1   model-exact   answered
          six typed tools   223 ms    8/11    3/6           6/6
          one entity tool   171 ms    8/11    3/6           6/6

        **The first run said something else, and it was the wrong engine.** Those
        numbers were needle-2: 861 ms for six tools, and one tool returning an EMPTY
        call list for two of three prompts. `*-needle-[0-9]*` matched both builds and
        `tail -1` picked needle-2, so the rejection was first recorded against a model
        the tree does not pin.

        **On needle-3 there is nothing to reject.** Both surfaces score the same, and
        the 4x advantage goes with it: six schemas cost ~50 ms more, not 650. The typed
        surface still wins on one property the battery cannot see — each tool describes
        a specific lookup, so the caller's choice is inspectable, while
        `graph_lookup(entity)` leaves the pattern to the graph.

        Six tools stay. The lesson worth keeping is not about the surface: a
        measurement is only as good as the binary it ran, and this one ran a stale one.
        See needle3-resident-at-login for the gate that made it visible.

        `TOOLCALL_SINGLE=1` stays, off by default, as this measurement's recipe.
      '';
    };

    daemon-earns-it-by-compression = {
      title = "A winning daemon replaces an 18 KB read, not a 145 ms question";
      kind = "proposal";
      status = "CLOSED";
      priority = "P2";
      date = "2026-11-02";
      summary = "The Kelly break-even is p* = cost/(save+cost), so a daemon wins by making `save` big: naming an argument saves ~3 tokens and needs p > 0.88, while not reading an 18 KB blast listing needs p > 0.29. Design: NL to a schema-checked query object over compiled registries, answered in <=80 tokens with pointers, refusing on invalid or empty.";
      refs = {
        modules = ["flake/daemons.nix" "scripts/task/toolcall.sh" "scripts/task/q.sh"];
        tasks = ["ops:ask" "ops:q" "ops:q:sidecar" "checks:toolcall" "checks:selector" "checks:selector:sidecar"];
        docs = ["docs/nix-patterns.md" "docs/selector-daemon-predesign.md"];
      };
      body = "The Kelly analysis delivered its verdict through the needle3 rejections (flake/daemons.nix scores resident helpers, ev gate). Closed — conclusion reached.";
    };

    jobby-cli-consolidation = {
      title = "One jobby CLI over the two halves of the application pipeline";
      kind = "proposal";
      status = "IN FLIGHT";
      priority = "P2";
      date = "2026-11-09";
      summary = "jobby and appflow do one job in two languages and neither is a tool. Since the Postgres cutover (86bdb73b) the archive API is the writer, so this plan reads and writes rows instead of rebuilding from applications.json. M0 (13 packages green) and M1 (lossless JSON, 40/40 statuses) are delivered; one Go binary with `jobby tui` and `jobby <verb>` owns JD intake, the packet and derived actions.";
      refs = {
        modules = ["modules/config/nu/jobby.nu" "taskfiles/apps.yml" "flake/cli.nix" "modules/nixoshmsymlinks.nix"];
        tasks = ["apps:list" "apps:update" "apps:export"];
        docs = ["docs/job-cold-email.md" "docs/NUSHELL.md"];
      };
      body = ''
        **Why one binary.** jobby is Go with a pdfcpu layout compiler and capsules; appflow is
        10,090 lines of Python over JSON truth, a triggerless SQLite cache and Typst packets.
        Neither composes with the other, and neither is a tool.

        **The rule.** The archive database is the only writer since 86bdb73b (2026-11-03):
        `applications.json` is an export, and jobby must not rebuild the table from it — a copy
        frozen in the workflow checkout would revert rows the mail hub discovered. A SQLite
        trigger dies at the next sync; `jobby tick` derives due actions into an append-only ledger
        and writes through `/api/application-update`, and a second run changes nothing.

        **Delivered.** M0 hydrated the clone 4a637e6 -> a5107bf with build, vet and tests green
        over 13 packages. M1 added `internal/apps` and `cmd/jobby`: the encoder reproduces
        Python's bytes (sha256 `5224f960…`), the rebuild matches the deployed cache row for row
        (141-row file, 0 diff; Postgres held 157), all 40 statuses classify, `jobby set` rewrites one.

        **M2 measured.** Six lens/language renders at budget 2 fit 2 pages at 10.0pt (56-60
        lines on page 1; each letter 1 page, 19 lines). The 54 Typst packets compile to 108
        documents, all PASS the three rules: verdicts agree, coverage does not — the audit reads
        `dist/` alone, 2 of 108. One page needs 9.0pt and still leaves 11 lines on page 2.

        **Remaining.** M3 radar over `himalaya envelope list` with a measured agreement rate
        before any send; M4 `jobby tick` idempotence; M5 TUI over the same verbs; M6
        `taskfiles/apps.yml` calls jobby under the same task names.

        **No auth layer.** himalaya, the llm wrapper and the Jev router hold every credential;
        jobby stores none and prints none.

        **Open.** Which resume is canonical; when the workflow checkout is archived; where the
        timer runs; whether DuckDB analytics and the dashboard (`services.appflowBoard`) survive.
      '';
    };

    idle-service-modules = {
      title = "An idle daemon retires to its module, not out of the tree";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-09";
      summary = "The 2026-11-09 audit retired Mosquitto, InfluxDB and ModemManager from frieren's runtime while keeping every module: the host sets the option false and records the measurement that retired it, so a future project re-enables an option instead of rebuilding the wiring.";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/frieren/configuration.nix" "hosts/frieren/infra-stack.nix" "modules/services/home-assistant.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **The rule.** `enable = false` in the host module, next to the number that
        retired it. The module stays registered in `modules.toml`, so the surface is
        still documented and one option restores the unit.

        **What the audit measured on frieren, 2026-11-09.**
        - Mosquitto: zero `new client connected` lines in seven days, while the
          journal held only "Saving in-memory database" every 30 minutes. Home
          Assistant's telemetry is `command_line` sensors, so no feed was lost.
        - InfluxDB: `/var/lib/influxdb2` at 200 KB with one file touched in 14 days,
          while Scrutiny's weekly collector ran. Scrutiny keeps its own store.
        - ModemManager: enabled, inactive, no `/dev/cdc-wdm*`, no `/dev/ttyUSB*`.

        **What looked idle and is not.** `pihole-ftl` is the primary resolver and PXE
        proxyDHCP (2.6 M queries imported); `thermald` earns its place on an Intel
        host with DPTF tables; `nixos-upgrade` and `fleet-classification-gate` ledger
        non-successes cluster into two incidents, not chronic failure.

        **Reclassification is a habit, not a sweep.** Candidates come from the
        sentinel ledger and the journal — no client, no write, or a condition never
        met — never from the module's own description.
      '';
    };

    selector-model-plane = {
      title = "A model daemon is hot-swappable, and an absent artifact is a skip, not a loop";
      kind = "proposal";
      status = "IN FLIGHT";
      priority = "P2";
      date = "2026-11-09";
      summary = "`selector.service` now guards on the model file as well as the script and takes its path from `programs.selectorDaemon.model`, so a host with no artifact skips the start instead of restarting forever. Measured before the fix on frieren: 3,140 restarts and 51,241 journal lines in six days.";
      refs = {
        modules = ["modules/user/selector-daemon.nix" "scripts/task/selector-sidecar.sh" "flake/daemons.nix"];
        tasks = ["checks:selector:sidecar" "checks:host"];
        docs = ["docs/selector-daemon-predesign.md"];
      };
      body = ''
        **What was broken.** The unit conditioned on `tools/selector/serve.py`, which
        always exists, so the missing artifact surfaced as ExecStart exit 1 under
        `Restart=on-failure` with a 10 s delay. `q.sh --question` falls back to the
        interpreter, so nothing was gained by the loop either.

        **What landed.** `ConditionPathExists` covers the script and the model;
        `StartLimitBurst = 3` in 300 s bounds a genuinely broken artifact; `Q_MODEL`
        and the guard read one value, the option. A new artifact is an option change
        and a restart, with no edit to the unit.

        **Hermes as the next candidate.** The hypothesis is that a larger model serves
        the same closed-vocabulary query object behind the same socket, so the daemon
        is the stable part and the model is the swapped part. What would settle it is
        `checks:selector:sidecar` (byte-identical to the interpreter) plus the Kelly
        entry in flake/daemons.nix still clearing at the new model's latency — and
        refusal still under 100 ms, because a slow refusal is a loss on its own.
      '';
    };

    needle3-surface-widening = {
      title = "Put the read-only lookups an agent actually makes on the tool surface";
      kind = "proposal";
      status = "PROPOSED";
      priority = "P3";
      date = "2026-11-02";
      summary = "Six graph lookups are callable while notes, blast radius, closure size and the ledger are not, so the most common questions still go back to a shell and a reasoning round.";
      refs = {
        modules = ["scripts/task/toolcall.sh" "scripts/task/toolcall-battery.jsonl"];
        tasks = ["checks:toolcall" "checks:edge"];
        docs = ["docs/agent-contract.md"];
      };
      body = ''
        The surface is a regex over the compiled task graph, so widening is one line
        plus battery cases. The heavy exclusion keeps anything that builds off it by
        construction, which is why `checks:host` cannot appear by accident.

        Candidates, each one lookup and read-only: `ops:notes:show`,
        `ops:kg:blast`, `dev:closure:size`, `ops:ledger`.

        A tool that fans out or needs a human choice stays off the surface — the
        quadrant rule, not a taste judgement.

        **Exit.** `checks:toolcall` covers at least 15 prompts with unsafe 0, and
        `checks:edge` still reports same-call parity for every one of them.
      '';
    };
    hermes-tier3-never-ran = {
      title = "The cascade's Tier 3 never ran — a flag in the wrong parser";
      kind = "experiment";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-05";
      summary = "Tier 3 ran `hermes -q … --oneshot`; `-q` is a `hermes chat` option, so argparse exited 2 before any model call and every job that reached Tier 3 fell through to Tier 4. Fixed in both hosts, with a token-free gate that reads the CLI's own help.";
      refs = {
        modules = [
          "hosts/frieren/infra-stack.nix"
          "hosts/delphi/infra-stack.nix"
          "scripts/task/hermes-check.sh"
          "scripts/task/hermes-env-sync.sh"
          "modules/user/ai/hermes-user.nix"
          "modules/user/ai/hermes-persona/config.yaml"
        ];
        tasks = ["checks:hermes"];
        docs = [".agents/skills/frieren-offload/SKILL.md"];
      };
      body = ''
        Tier 3 logged the same WARN line as a tier that was never needed, so nothing
        showed it had never made a model call.

        **Wrong form.** Both host cascades ran `hermes -q "$prompt" --oneshot`; the
        top-level parser has no `-q`, so hermes exited 2 ("is not a `hermes` command")
        before any call. Measured on 0.22.5, trivial prompt, frieren: old form exit 2
        in 0.0 s; `hermes chat -q … --oneshot` exit 0 in 30.3 s; `… -Q --run-budget
        600` exit 0 in 21.4 s. Fixed Tier 3 ran end to end in 33.4 s.

        **Deployed 2026-11-06.** frieren `infra:rebuild:nixos` (08:34, runner
        `j3v4h1…` line 87) and delphi `nixos-rebuild switch --refresh --flake
        github:shaoyanji/nixconfig#delphi` (08:23, runner `51gy7r…` line 78). Live
        Tier 3 on delphi: exit 0 in 20 s, produced `TIER3_LIVE_OK`. delphi's deploy
        ran that command by hand because `activate-host.sh` gates on the *toplevel*
        being in a substituter and nothing caches a cloud host's own toplevel.

        **Two more bugs surfaced on the way.** `hermes-env-sync` could not create
        `~/.hermes/.env` from scratch — `grep -oE … file` exits 1 on no match and
        `pipefail` made that the whole diff's status — which failed home-manager
        activation on delphi (`4/NOPERMISSION`); `92b200e6` fixes that plus a swapped
        `comm` (added and dropped printed the same list) and two `NR == FNR` guards.
        The triage counters had the same shape (`grep … | wc -l || echo 0`, `||`
        binding to `wc`), now `( … || true) | wc -l`.

        **Gate.** `task checks:hermes` fails any top-level call site using a flag
        `hermes --help` does not publish (it caught both hosts before the fix), the
        gateway's `needs_attention`, rendered-env KEY NAMES against `.env`, and
        `hermes doctor` on the persona config — 5 s, no model call, no ssh.
      '';
    };

    nightly-timer-boot-catchup = {
      title = "A power cut caught the nightly audit up into its own boot";
      kind = "experiment";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-06";
      summary = "Both agent timers are Persistent, so the 06 Nov power cut fired them 30 s into boot: the handoff lost the shared flock and failed silently, and the audit judged services that were still starting — every Gatus row at its 10 s timeout, the 05:00 dispatch refused. Contention is a logged skip now and the audit waits out a boot settle.";
      refs = {
        hosts = ["frieren"];
        modules = [
          "hosts/frieren/infra-stack.nix"
          "modules/services/agent-scheduler.nix"
        ];
      };
      body = ''
        The laptop was off from 00:19 to 07:53, so the 03:00 handoff and the 05:00
        audit both missed their slot and both caught up in the same second of boot —
        `Persistent=true` working as designed. What each did with that second is not.

        **Handoff: a silent failure.** `flock -w 60` exits 1 and prints nothing when it
        cannot get `/tmp/agent-scheduler.lock`, which the audit had just taken; 61 s in,
        the unit was "Failed to start". A failed user unit is itself a trigger for the
        next audit, so the outage became a repair run.

        **Audit: judging a host mid-boot.** At 07:53:47 every frieren Gatus row was UP at
        10000 ms — its own timeout — fleet sentinel was DOWN, and the dispatch died on
        `[Errno 111]` to 127.0.0.1:5225 because simplex-chat was not listening yet. The
        cascade then restarted pihole-ftl, tailscale-cert and fleet-sentinel: units that
        were still legitimately activating.

        **Fix (c83c5a18).** `modules/services/agent-scheduler.nix` runs jobs through a
        wrapper that maps flock's conflict code to a logged skip (exit 0) and passes any
        other status through untouched; the audit runner waits for 600 s of uptime
        before Step 1. A normal 05:00 run is hours past boot and waits not at all.

        **Measured.** Gate: 120 s uptime waits the exact 2 s delta to 122, 90000 s waits
        0 ms. Lock: job status 7 → 7, held lock → logged skip, exit 0, job not run (the
        old form: exit 1, silent). Deployed 09:47 (`9y7m7akh`, runner `fmvr394`, wrapper
        `ww3hi46`); the live run at 09:48 saw all 11 services NOMINAL, dispatched the 05:00
        scorecard to #Fleet and took the quiet gate for 0 tokens.
      '';
    };

    clanker-offload-fixture = {
      title = "clanker: the offload VM, and what may live there";
      kind = "proposal";
      status = "IN FLIGHT";
      date = "2026-11-06";
      priority = "P3";
      links = ["exp-021" "exp-115"];
      summary = "A 4 vCPU / 8 GiB Instabox VM is permanent as of 2026-11-06, so work measured in minutes — a closure build, a Go binary, a tool trial — moves off the host that asked for it, and the monthly cache diff gains a machine that can compute it.";
      refs = {
        hosts = ["clanker"];
        modules = ["hosts/clanker.nix" "modules/roles/lean.nix" "scripts/task/clanker.sh"];
        tasks = ["clanker:profile" "clanker:nix" "clanker:job" "clanker:wait"];
        docs = [".agents/skills/instabox/SKILL.md"];
      };
      body = ''
        **What it is.** Instabox VM: 4 vCPU, 8 GiB, `/data` 20 GiB, 120 min per run,
        suspend after 30 idle. Not a host — the image owns boot, kernel and accounts; we
        own `~/.nix-profile` and `/data`, registered `kind = "home"` with `role:lean`.

        **Tiers.** Always-on services stay on delphi and frieren (dsh-web is delphi's
        unit); clanker is the burst tier — browser work, authenticated sessions, artifact
        compilation, a tool tried before it reaches a host's closure. A job is a directory
        (`cmd.sh`, `log`, `exit`), so it survives the channel that started it and
        "running" means no `exit` yet.

        **Measured 2026-11-06.** `clanker:devshell` sent the tree and ran
        `templates/agent-shell`: agent-browser 0.41.2 substituted from `cache.numtide.com`,
        opened example.com, returned its accessibility snapshot with refs. `page-check`
        wrote a verdict and a 1280x633 PNG, fetched back with `clanker:result`. A tmux
        service reached only by `ssh -L` answered HTTP 200 with nothing published; dsh
        runs there and answers its auth fence through the tunnel (its token exchange is
        the open gap, not the reach).

        **What may not.** State: no sops or age key, no cache write key, nothing that must
        answer. The cache trial (extends exp-021) is the deliberate exception — a monthly
        `nix flake update` diff built here into R2's 10 GiB against the box's 20, so a
        laptop fetches a diff.

        **Pinwheel profiles.** Each flake devShell is a disposable environment — new tree,
        new shell, nothing installed on the host, `nix flake init -t .#agent-shell` for
        the next box. With `gh` and a wasm toolchain this tier compiles what the fleet
        cannot afford locally.
        **Exit.** Three months with no babysat job, a cache diff a laptop substituted
        from, and one authenticated session (LinkedIn, Gmail) read back as a snapshot.
      '';
    };
    go-for-python-services = {
      title = "Long-running services go to Go; timers and model servers stay Python";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-07";
      summary = "Three runtimes were built for the turns read path and measured at 1000 SSE readers; Go won on the edit loop (42 ms warm rebuild) and the idle process (12.6 MB), and the turns shim followed it off Python. The rule that falls out: a long-running service with I/O the fleet owns is a Go port; a timer-sized one-shot or a model server is not.";
      refs = {
        hosts = ["delphi" "eisen" "frieren"];
        modules = [
          "modules/services/agent-turns.nix"
          "modules/services/agent-turns/shim"
          "modules/services/turns-dashboard"
          "modules/services/zettel-graph.nix"
          "modules/services/mataroa-console.nix"
          "modules/services/mataroa-console/server"
        ];
        docs = ["docs/agent-turns.md" "docs/turns-dashboard.md" "docs/mataroa-console.md" "docs/zettel-graph.md" "tools/turns-runtime/README.md"];
        tasks = ["checks:host" "clanker:devshell"];
      };
      body = ''
        **Measured 2026-11-07 on clanker, 1000 SSE readers, 20 000 frames.** Go 42 ms
        warm build / 12.6 MB idle; Rust 2 186 ms / 6.4 MB with 67 crates; Elixir
        553 ms / 181.8 MB. p50 10.7-11.8 ms and p99 20.2-21.7 ms across all three, so
        the stream does not separate them and the stream is not what chooses. Table,
        method and every other server: `tools/turns-runtime/README.md`.

        **What chooses:** the warm rebuild (50x apart, the loop a person lives in),
        the idle process (a viewer idles most of the day), and pins. Rust's 2.1 MB
        binary and 6.4 MB resident are real and still lose to a 2.2 s edit loop on a
        read-only view.

        **The rule.** Port when all three hold: long-running, I/O the fleet owns (a
        store, a vault, a mail archive), and a Python cost paid continuously. Stdlib
        Go unless the read path is hard enough to be worth a benchmark. Not a
        timer-sized one-shot (the interpreter is a rounding error on the job) and
        not a model server (torch and transformers are the work).

        **Closed the same day:** `mataroa-console` (29.2 -> 6.8 MB idle, 2.38 ->
        0.68 ms ledger p50, 299 -> 1753 rps) and `zettel-graph` (26.1 MB / 44 ms ->
        8.8 MB / 0.23 ms) are Go; everything else was measured and stayed, with its
        reason in the same README.

        **Gated by:** a byte-compatible wire contract, tests ported before the
        handler, the legacy state file opening as-is, `checks:host`, then a live
        smoke before the old implementation is frozen.
      '';
    };
    image-daily-queue = {
      title = "The 100-image day runs itself: a queue with a freshness promise, agy as judge";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-11-10";
      summary = "A brief bank with an `every` per entry, a ledger row per generation attempt, and an agy judge turning the daily allowance into assets: nothing publishes that a judge has not passed. Four capped slots against the 25/hour burst limit; Cloudinary plus a tagged manifest frontend. Delivered 2026-11-16.";
      refs = {
        hosts = ["frieren"];
        modules = [
          "scripts/task/image-daily.sh"
          "scripts/task/cloudinary.sh"
          "lib/image-daily/briefs.json"
          "lib/image-daily/site/index.html"
          "hosts/frieren/infra-stack.nix"
        ];
        tasks = ["images:plan" "images:status" "images:publish" "images:post" "images:gc"];
      };
      body = ''
        **The queue is a file with a promise.** Each brief carries `every` days and is
        due when the ledger's last accepted row for that id is older, so the rota
        refreshes itself and nobody edits a schedule.

        **Nothing publishes that a judge has not passed.** `agy` reads the PNG and
        answers keep/reroll/reject plus one named defect; a reroll spends one image
        with that defect, and a failed judge leaves the plate `unjudged`.

        **Four slots, not one.** 01:10, 07:00, 13:20 and 21:20 hold 20/15/10/0 images
        back for ad-hoc requests and cap the pass at 20/20/20/40; a missed slot is not
        caught up.

        **Published 2026-11-10.** Fifteen blog banners sit on Cloudinary with the crop
        in the URL; `images:publish` deploys `index.html` and a tagged manifest, and
        `images:status` exits 1 when a lane is older than `max_age_days`.

        **The wall prompts were the defect.** `4k, realistic, neumorphism` named no
        subject and named a UI surface language, so eight character briefs answered
        with a frosted emblem and the judge kept them. Every brief now names a scene
        and carries `expect`; `rev: 2` retires the plates the old sentences made.

        **Parked, not re-rolled forever.** Three images without a keep parks a brief for
        a week (`PARK_AFTER`/`PARK_DAYS`) and `status` counts the set. Eight never-kept
        briefs used to be due every slot — 16 to 20 plates a slot — while an older wall
        keep kept `status` green. Each attempt is now its own ledger row with its
        prompt.

        **Measured 2026-11-10.** Motoko, Guts and 2B rendered from four words; a named
        subject renders, not the quality tokens, and a name with no scene gave an emblem.

      '';
    };
    wall-prompt-family = {
      title = "A wall plate comes from the brief bank, never a sentence written at the call site";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-10";
      summary = "Every wall brief names its subject and its scene. The family's shared `4k, realistic, neumorphism` tail was retired the same day: it named no subject and named a UI surface language, and the plates came back as emblems. A requested wallpaper is a new brief in the bank, never a prompt written at the call site.";
      refs = {
        hosts = ["frieren"];
        modules = ["lib/image-daily/briefs.json" "scripts/task/image-daily.sh"];
        tasks = ["images:plan" "images:publish"];
      };
      body = ''
        **What happened.** Asked for three Frieren-character wallpapers, this agent wrote
        its own long neumorphism brief ("one soft monochrome surface, extruded soft-UI
        shapes, deep inset shadows…") without opening `briefs.json`, whose six wall
        briefs all use the family line. Three images were spent: one plate reached disk
        off-family and was deleted, two never rendered. That is an AI tell as much as a
        bug — a confident invented style where a stored one was one `jq` away.

        **Then the family itself was the defect.** `<subject>, 4k, realistic,
        neumorphism.` named the character and then described a UI surface; the eight
        character briefs answered with frosted emblems, and the judge kept every one
        because the lane intent asked for neumorphism and only eight briefs said what
        the plate had to show. The lane intent now asks for an illustrated scene, every
        brief names a scene and carries `expect`, and `rev: 2` on the rewritten wall
        briefs stops the emblem plates from counting as fresh.

        **The rule.** A requested wallpaper is added to `briefs.json` as a brief with a
        named subject, a scene and its own `every`, so the queue owns it afterwards and
        the judge can hold the plate against it. `cpg image` by hand is for a one-off
        that is not a wallpaper and will not join the bank.

        **Exit.** `jq -r '.briefs[] | select(.lane == "wall") | .prompt'`
        `lib/image-daily/briefs.json` prints one scene per wall brief and no shared style
        tail; the note gates and `checks:prose` stay green.
      '';
    };
    wall-plate-rounds = {
      title = "A plate round holds refused rows, caps one row's wait and keeps the render it replaces";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-16";
      from = ["image-daily-queue"];
      summary = "An `images:plates` round spends the standing roster: a row the provider refuses is held with its reason, one row's burst wait caps the round instead of holding the lock, and a re-render archives the plate it replaces so `images:variants` can put it back.";
      refs = {
        hosts = ["frieren"];
        modules = [
          "scripts/task/image-daily.sh"
          "lib/image-daily/plates.txt"
          "lib/image-daily/archetypes.tsv"
        ];
        tasks = ["images:plates" "images:variants"];
      };
      body = ''
        **A refusal is held, not deleted.** Seven live-action and comic rows answered
        `VALIDATION_FAILED` about the character's identity on 2026-11-16; softening the
        sentence and changing the archetype changed nothing. The row becomes
        `hold: <reason> :: <the row as it was>`, `plates` prints it and skips it, and
        `roster_pending` stops counting it. Re-casting means rewriting the row and
        dropping the prefix; the engine never releases a hold on its own.

        **One stuck row must not spend the round.** `RATE_TRIES` with a 900 s ceiling
        held the run lock for two hours while twenty rows waited. A row now has
        `RATE_WAIT_TOTAL` (420 s default); spending it closes the burst window for the
        whole round, because the next row would probe the same closed bucket.

        **A re-render keeps what it replaces.** `attempt` copies the existing plate to
        `variants/<lane>/<day>/<slug>.<stamp>[-n].png` before the generator writes the
        path, with a counter because two archives can land in the same second.
        `images:variants` lists them and `VARIANT=<path>` puts one back, drops its
        `urls.tsv` row so publish uploads it again, and archives the plate it took out.

        **The record.** A refused row reads `hold:` in `plates.txt` and never reaches
        the generator; the superseded render is a file on disk, not a delivery URL.
      '';
    };
    agent-lane-plane = {
      title = "A lane primitive routes intent to a deterministic plane before any model";
      kind = "experiment";
      status = "DELIVERED";
      date = "2026-11-21";
      summary = "jev-decide classifies intent to the plane that answers it (kg pattern, notes, qmd, eval, ledger) — selected dispatches without a model, needs_review is the residue that earns one. scripts/task/agent-lane.sh behind `agents:lane`, 80% selected on natural questions.";
      from = ["turns-fusion-plane"];
      refs = {
        hosts = ["eisen"];
        modules = ["taskfiles/agents.yml" "scripts/task/toon-io.sh" "scripts/task/agent-lane.sh" "scripts/task/fusion-check.sh"];
        tasks = ["agents:call" "agents:lane" "agents:lane:corpus" "checks:fusion"];
        docs = ["docs/agent-turns.md"];
      };
      body = ''
        The shape is already agreed: compiled Nix and the graph answer
        deterministically, xs carries coordination, postgres joins retained
        state (turns-fusion-plane), and a model generates only the residue.
        Missing is the front door — the same kind of shared contract toon_emit
        is for output, but for routing: one step that picks the answering lane.

        Hypothesis: `jev-decide classify` over six lane labels routes ≥80% of
        real agent intents `selected`. ~1 s + ~400 input tokens per call vs a
        full turn; Laya (512 tokens) is the fallback when Jev is unreachable,
        Kev-4B only past that. Jev picks a lane, never a provider — that hook
        does not exist and does not need to.

        Join measurement for the sibling plane, taken 2026-11-21 on
        lib/agent-turns/turns.json (200 turns, 43 unique claim paths) against
        .#agentsNotes.index refs (322): 6 exact + 6 prefix path joins — ~28% of
        all claims, ~half of repo-local ones. jq, not memory — re-run it.
        Under ~10% on a bigger corpus the path key, and the plane, fails.

        Exit: a `lane`/`agents:call` answer to a corpus question with no model
        call and the needs_review rate printed, or REJECTED with the rate.

        Landed 2026-11-21: `agents:lane` answers a corpus question with no
        model call; measured selected rate 8/10 (80%) on natural questions —
        hypothesis met exactly. The honest caveat the instrument found: xs
        subjects are coordination labels, not intents — 0/15 select on
        `agents:lane:corpus`, which is the classifier correctly refusing to
        guess. checks:fusion gates the sibling projection: fresh, lag ~1.7 h
        inside the timer pad, 629 turns/236 notes projected on frieren.
      '';
    };
    agent-tools-called-not-declared = {
      title = "Agent CLIs are called through nix, never declared in a closure";
      kind = "decision";
      status = "ACCEPTED";
      date = "2026-11-21";
      summary = "llm-agents tools (agy, qmd, toon, ai-memory, agent-browser, dsh, …) resolve through scripts/task/nix-tool.sh — PATH first, then a FRESH fetch off cache.numtide.com. The category rides upstream HEAD; the flake.lock pin is deliberately not honored.";
      refs = {
        modules = ["scripts/task/nix-tool.sh" "scripts/task/toon-io.sh" "scripts/task/qmd-docs-index.sh" "flake/cli.nix"];
        tasks = ["agents:agy" "agents:lane" "dev:qmd:refresh" "checks:qmd:docs"];
        docs = ["docs/agent-turns.md"];
      };
      body = ''
        The complaint that forced it: closures for llm-agents.nix were baked
        into host packages while taskfiles only needed the binary callable.
        cache.numtide.com serves the whole category prebuilt, so fetching is a
        substituter hit and pinning is dead weight — these tools change faster
        than the lock should chase them.

        The contract (nix-tool.sh): `resolve <name>` prints the binary — PATH
        wins, else `nix build github:numtide/llm-agents.nix#<attr>` once into
        a GC-rooted link under ~/.cache/nixconfig-tools/. `run` execs it.
        `registry` maps called-name to attr and binary (agy -> antigravity-cli
        is the alias this whole thing was asked for). toon_emit, the qmd
        indexer, and the lane all resolve through it — a taskfile never
        requires the tool in a closure again.

        The boundary: call sites resolve lazily; SERVICES still bake.
        frieren's hermes-agent/freebuff/dsh and delphi's agent fleet are
        daemons — a unit cannot resolve at exec time, so they keep their
        closures. user.ai's light/full knob sheds the interactive half
        per host whenever a rebuild wants it.

        Side finding same day: no elixir in the devshell — tools/kg-engine
        and kg-sidecar are gone, and the only Elixir left is the
        turns-runtime benchmark's own nested flake. .envrc corrected.
      '';
    };
    outreach-dossier-redaction = {
      title = "The consultancy dossier names targets, never the people who staff them";
      kind = "decision";
      status = "ACCEPTED";
      date = "2026-11-22";
      summary = "Commit 6a233ed9 replaced the last third-party contact details in the outreach dossier with [NAME]/[CONTACT]/[PHONE] slots; only target companies, their public sites and Matt's own signature stay. The file is .agents/outreach/nix-consultancy-outreach.md, not docs/, and the pre-redaction blob is still in history.";
      refs = {
        modules = ["scripts/task/docs-budget.sh" "lib/matt-site.nix"];
        tasks = ["matt:cv:check" "apps:list" "ops:docs:budget"];
        docs = [".agents/outreach/nix-consultancy-outreach.md" "docs/cv-ats-compliance.md"];
      };
      body = ''
        Landed 2026-11-22 in 6a233ed9, `docs(outreach): finish redacting the
        consultancy dossier's contacts`: the last names, profile slugs and
        personal URLs became `[NAME]` (20), `[CONTACT]` (6) and `[PHONE]`
        (1), with `[REDACTED]` (0) left. Target companies, their public sites
        and Matt's own signature/links stay — they are who it is about.

        Two things a future reader would otherwise get wrong:
        - The file is `.agents/outreach/`, a 400-line runbook that sat at
          exactly 400: the convention is three header lines, and every edit
          pays the budget through `scripts/task/docs-budget.sh`.
        - `[PHONE]` was never data. The dossier forbids phones by policy and
          never carried one; the slot keeps the rule visible.

        State after the pass: the CV corpus is reconciled in `lib/matt`,
        `matt:build` green — five PDFs, 2/2/1/1/1 pages, ATS-clean — and the
        packets live under the appflow state dir, never in the tree: that path
        was untracked on 2026-11-22 and the pre-commit hook now refuses it.

        Open, and not silently closed:
        - History: blob 92de6243 still serves the unredacted text, profile
          URLs included. Scrubbing needs `git filter-repo` and a force-push
          on a shared remote — unauthorised, so redaction is HEAD-only.
        - The Adyen CV still scores 0 on Helm, Argo, MCP, vLLM, LiteLLM and
          RAG: a corpus gap, not a redaction one.

        Exit: the placeholder grep and `matt:cv:check` both stay clean and
        green on the next pass over the dossier.
      '';
    };
    delphi-postgres-19-upgrade = {
      title = "Upgrade delphi's PostgreSQL 17 → 19 at the next nixpkgs epoch";
      kind = "open";
      status = "OPEN";
      priority = "P4";
      date = "2026-11-22";
      summary = "Delphi runs PG 17 for the email archive, miniflux, umami, zettel-graph and mataroa. The upgrade procedure is written and committed; execution is gated on the fleet moving to a nixpkgs pin that carries postgresql_19 final (unstable has only 19rc2 today).";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/services/email-archive.nix"];
        tasks = ["checks:host"];
        docs = ["docs/ops/postgres-19-upgrade-plan.md"];
      };
      body = ''
        Preconditions, all in docs/ops/postgres-19-upgrade-plan.md: the fleet
        pin must carry postgresql_19 at 19.0 final (not rc2), pgvector must be
        compatible, and a pg_dumpall plus postgres-backup-drill restore test
        must pass before the pin flips `services.postgresql.package` in
        email-archive.nix.

        NixOS does not run pg_upgrade for you; the doc weighs pg_upgrade
        against dump/restore. Post-migration: ANALYZE, pgvector loadable in
        every consumer database, and all five services reconnecting.

        Exit: `task checks:host HOST=delphi` passes on the new generation and
        the xs turn SUBJECT=delphi:postgres-19-upgrade posts OUTCOME=done.
      '';
    };

    delphi-ops-traps = {
      title = "Delphi's measured traps: nginx, port namespace, systemd lifecycle, ARM";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-22";
      summary = "One record for every trap hosts/delphi/configuration.nix comments used to carry, so the comments become pointers.";
      refs = {
        hosts = ["delphi"];
        modules = ["hosts/delphi/configuration.nix" "hosts/delphi/dsh-web.shadow.nix" "hosts/delphi/agy-daemon-web.shadow.nix"];
        tasks = ["checks:host"];
        docs = [".agents/deploy/hosts/delphi.md" "docs/delphi-install.md"];
      };
      body = ''
        Consolidated 2026-11-22 (nix-comment-audit routing). Comments now carry
        `Trap:`/`Story:`/`Rule:` pointers here.

        nginx: the generator splits a {8} quantifier across lines and rejects
        it — spell out eight hex classes. enableACME+forceSSL emit both the :80
        and :443 halves; a manual `listen 443` orphans HTTP-01 → renewal 404s.
        Unanchored ^/ rewrites ate every 404 (2026-11-08) — anchor to /.
        One virtualHosts definition per host; TLS overlays with //. SSE needs
        proxy_buffering off. nixpkgs-nginx pinned for CVE-2026-123007/123633.

        Ports: mounts are a sequential namespace (8451 reserved for the archive
        benchmark; 8453/8454 zettel+mataroa). Collisions: :53 resolved-stub vs
        crab-hole; 8093 agent-turns shim took it from miniflux (EADDRINUSE
        2026-11-06); NOT-8094 for umami — media-relay owns it, the collision
        killed every vhost (2026-11-07); 8091 ≠ 8090 (eisen's Laya).

        systemd: ExecStartPre runs as User= — root-owned 0400 breaks renders.
        Read-only / + root-owned state → RuntimeDirectory (died 2026-11-06).
        DynamicUser cannot take a sops secret. AuthorizedPrincipalsFile under
        /var/lib — an /etc store symlink fails StrictModes and the list
        silently empties. The agent-turns turn dies MISSING_CREDENTIAL.

        ARM/OCI: A1 has no KVM — TCG-only guests; sntrup761 KEX ~1min → SSH
        handshake timeouts. Stirling went native→guest→native in a week for
        it. Ingress admits only 22/80/443. aarch64 CI keeps doCheck off (60min
        cap hit twice). sopsFile must be in the TRACKED flake — an untracked
        apikeys.yaml is absent from the github: tarball. Plain `github:` — the
        tarball fetcher rejects submodules=1. Vaultwarden has no prelogin port
        — crab-hole answers its name with frieren's tailnet IP. Retirements:
        dsh-web, agy-daemon-web → shadow files, one-uncomment revival.
      '';
    };

    frieren-ops-history = {
      title = "Frieren retirements and measurements behind the surviving config";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-22";
      summary = "The retirement dates, measured numbers and restored settings hosts/frieren/configuration.nix comments used to carry.";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/frieren/configuration.nix" "hosts/frieren/reverse-proxy.nix" "hosts/frieren/dns.nix"];
        tasks = ["checks:host"];
        docs = [".agents/deploy/hosts/frieren.md"];
      };
      body = ''
        Consolidated 2026-11-22 (nix-comment-audit routing). Comments now carry
        `Story:`/`Trap:`/`Rule:` pointers here.

        Retirements: uptime-kuma off 2026-11-04 (zero monitors — gatus lives on
        delphi); mosquitto off 2026-11-09 (zero clients in a week of journal;
        ESP32/Zigbee in [[exp-009]]); ESPHome 2026-10 (6052 closed); ZeroClaw
        2026-09 (42617 closed); the pihole-ftl overlay once upstream took the
        fix. `RESTORED` markers mean a cleanup sweep deleted the setting once,
        not that it is new.

        Measurements: auto-cpufreq held all four cores at 3.4GHz for +0.47W
        idle vs the fixed powersave governor. nixos-upgrade --upgrade unpacked
        a channel ~2.5min at 04:02 (no-op on flakes). A prefill's own hit% is
        not evidence — it serves its new chunks first.

        Traps: BT soft-block (Fn+F8) persists in the EC — sysfs write after
        systemd-rfkill. Never fight the 03:00–05:30 window — Conflicts stops
        the unit. The audit unit exits 0 on failure; gatus reads the outcome
        FILE. Kernel chain degrades to nixpkgs default when an LTS leaves the
        tree, never pin-miss. One aria2 RPC on :6800. Telegram tokens are
        per-host — two pollers conflict. Transmission owns 51413. NFS pins
        conventional v3 RPC ports so checks:ports can declare them. frieren.lan
        claims 192.168.3.25 — a duplicate server_name is ignored and shadowed
        the portal (reverse-proxy assertion). Atuin signup is closed — an open
        signup lets any vhost visitor write the history db.
      '';
    };

    aki-site-design = {
      title = "Fleet site: retired-design record and the traps behind the pointers";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-22";
      summary = "The narratives lib/aki-site.nix comments used to carry — typed-prose incidents, retired render paths, the shadow trap — consolidated so the comments become pointers.";
      refs = {
        modules = ["lib/aki-site.nix" "lib/knowledge-graph.nix"];
        tasks = ["checks:kg:canvas"];
      };
      body = ''
        Consolidated 2026-11-22 (nix-comment-audit routing). lib/aki-site.nix
        comments now carry `Story:`/`Trap:` pointers here.

        Retired designs: the overview body renders twice (no-JS document and
        data/overview.json transition) as ONE expression — two copies is how
        the old page drifted from the data it described. Note slices carry the
        note's own text because the old page reached a note only through one
        hardcoded forge URL. The static live.json fallback is nulls: the old
        file invented "generation: booted", "uptime: nominal", "load: 0.0" and
        the page displayed them as measured. Host rows omit unknown fields —
        "Generic", "DHCP", "Integrated" were typed prose. The closures page
        replaced a hand-written attribution rollup ("15.4 GiB exclusive (46%)",
        "~703 MiB" for one generation of one host): unproducible and wrong
        within a week; closure-budgets.toml is rewritten by a measurement.

        Traps: the template values attrset must not name attrs after the
        let-bindings they read (`t.devices`, never `t.totalHosts`) — a shadowed
        name recurses forever, silently. kg.js's interaction contract (click
        navigates, hover inspects, pan/zoom never) was the TODO exit
        criterion; TODO.md is now a pointer stub, so the contract lives here.
        "Gap B"/"Gap D" in comments number a retired feature-gap list.
      '';
    };
  };
}
