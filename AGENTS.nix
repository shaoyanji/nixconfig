# AGENTS.nix — the repo's narrative knowledge as data.
{
  schemaVersion = 1;
  notes = {
    kg-zeck-cache = {
      title = "Measure an epoch-scoped incremental graph cache";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-11-19";
      summary = "Opt-in one-shot Elixir fragments preserve the Nix graph across doc edits. Latest VM timings including startup: 589 ms incremental versus 562 ms HEAD+diff miss; 761 ms hit versus 35 ms baseline hit. No daemon; default stays unchanged because this sample does not clear the Kelly gate.";
      from = ["d4-no-neo4j"];
      refs = {
        modules = ["tools/kg-zeck/kg_zeck.exs" "scripts/task/lib/kg-graph.sh"];
        tasks = ["ops:kg:zeck" "checks:kg:zeck"];
        docs = ["docs/nix-patterns.md"];
      };
      body = ''
        Hypothesis: doc-only misses can avoid a full graph eval without changing
        graph semantics. Cache fragments in greedy Fibonacci blocks within an
        epoch; all other tracked content and citation-set changes rebuild core.
        Measured on the Ubuntu VM, including BEAM startup: cold leap 2618 ms,
        incremental doc edit 589 ms, warm hit 761 ms. HEAD+diff was 562 ms on
        that edit and 35 ms on a hit. An earlier run saved 286 ms per doc-only
        miss but cost 358 ms warm. The latest run saves nothing on either read.
        Exit: checks:kg:zeck stays green, measure the doc-only miss fraction p
        and end-to-end saved ms per dirty-tree read against HEAD+diff on the
        intended machine. Use flake/daemons.nix's Kelly expression: require
        save > 0 and ev > 0, including epoch amortisation. The latest sample
        fails save > 0, so no p clears it. Keep KG_BACKEND=zeck opt-in
        until that measurement clears; reject it if startup erases the saving.
      '';
    };
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
    firecrawl-local-dragoncourt = {
      title = "firecrawl-local remote egress on dragoncourt (alwaysdata) — plain-HTTP scrape service";
      kind = "decision";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-25";
      summary = "A firecrawl-local instance is live on dragoncourt at http://services-dragoncourt.alwaysdata.net:8330, serving the v2 API (/v2/scrape, /v2/map, /v2/crawl) behind a bearer token. Verified end to end: a real scrape and a map call both worked through the public URL.";
      refs = {
        modules = [
          "modules/user/ai/hermes-user.nix"
        ];
        tasks = ["dragoncourt:services"];
      };
      body = ''
        Remote egress alternative to frieren's loopback firecrawl-local (port 3002, which has Chrome and
        renders JS). The alwaysdata instance has no Chrome, so JavaScript-rendered pages return
        header-only or empty. Use it when the loopback is down or for plain-HTML targets.

        Plain HTTP only (no TLS on alwaysdata), plain HTML only. Token also at
        ~/firecrawl-local/token on the server; runbook in alwaysdata's ~/AGENTS.md.

        The bearer token is not stored in the repo: it lives on the server and was communicated out
        of band. The alwaysdata API token was used once to provision the service and is in the vault.

        To use it as a hermes extract backend, set FIRECRAWL_API_URL to the URL above and pass the
        token in the Authorization header. No host rebuild needed, since it is a remote service.
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
        Shape is Stapelberg's ("Coding Agent VMs on NixOS with microvm.nix", 2026-02-01): a shared
        read-only store over virtiofs, explicit shares, ephemeral by default. Two tiers, declared:
        frieren's guests are ephemeral tooling, delphi's sandbox is a service tier (`autostart = true`,
        4096 MiB, Stirling PDF), and its state is a named volume found by filesystem **label**.
        `DefaultDeviceTimeoutSec = 600` only under TCG, where udev met the 90 s timeout. In: `ssh
        sandbox` on delphi (the bridge subnet is host-local), or `task microvm:ssh NAME=sandbox`.
        The markdown deck is off: abandoned TUIs cost the box's CPU under TCG, and turning it back on
        needs the three forced-command traps in `hosts/microvms/README.md`.
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
    eisen-llm-stack = {
      title = "eisen LLM stack — trap and retirement record";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-22";
      summary = "The llama.cpp-to-Strata stack on eisen: the tailscaled-readiness trap both serve units carry, and what retired llama-swap, the fork builds, and Kev-4B.";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/llm-server.nix"];
        tasks = ["checks:host"];
        docs = [
          "docs/eisen-llm-architecture.md"
          ".agents/deploy/hosts/eisen.md"
          "hosts/eisen/MANUAL.md"
        ];
      };
      body = ''
        Trap — After=tailscaled is ordering, not readiness. A unit ordered after
        tailscaled.service can still exec while the backend is NoState. Measured
        twice on eisen:
        - tailscale-serve (nixpkgs oneshot): `serve set-config` exited 1 once at
          boot 2026-10-19 13:44 and stayed failed with no retry; the tailnet serve
          config was not applied until a manual restart.
        - tailscale-serve-node: same race on a tailscaled restart — dies with
          "unexpected state: NoState".
        Fix shape: ExecStartPre waits for `tailscale status --json` BackendState
        == "Running" (<=120 s), and TimeoutStartSec raised so the wait fits the
        unit's start window. Both serve units in llm-server.nix carry it.

        Retirements:
        - llama-swap :8080 superseded by Strata MoE :8085 (2026-10-21);
          open-strata-eisen-rx5700 is the delivery record.
        - The 0.7.0 pin and the PrismML/Kolibri fork builds each forced a full
          C++ build on eisen (~15 min) every nixpkgs bump — the energy cost that
          retired them (2026-10-19). Dormant blocks stay in the file for revive.
        - Kev-4B-Q8_0.gguf: tested 2026-10-17, no endpoint — kept on disk for
          direct tests, never served, never routed.
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
      status = "DELIVERED";
      priority = "P0";
      date = "2026-11-27";
      summary = "`minyx`'s `boot.kernelPackages` collision is fixed (`mkOverride 1200`). `cassini`'s darwin chain is repaired: the last fault was tailscale-policy testing only `services.tailscale`, not its Linux-only `extraSetFlags` leaf; both dormant hosts now pass eval.";
      refs = {
        hosts = ["minyx" "cassini"];
        modules = ["modules/global/macos.nix" "modules/global/linux-systemd.nix" "modules/global/global.nix" "modules/global/tailscale-policy.nix" "flake/module-sets.nix" "modules/roles/home.nix" "modules/profiles/base-node.nix" "modules/user/ai/freebuff-remote.nix"];
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

        Final fault, 2026-11-27: nix-darwin has `services.tailscale` but not the
        Linux module's `extraSetFlags` suboption. `tailscale-policy.nix` now tests
        that leaf before emitting the definition. `optionalAttrs` is required:
        `mkIf` is pushed down before the missing-option check, so it cannot hide a
        definition from the module system.

        Gates: `checks:host HOST=netbook` green in 10.2 s after the Linux-option
        split; `ALLOW_PRESERVED=1 task checks:host HOST=cassini MODE=eval` green
        with 585 assertions after the tailscale leaf fix. `zeno`, `mtfuji`,
        `deckstation` and `applevalley` also pass the same eval gate.

        Exit: delivered — both named dormant hosts have a green module-system eval;
        re-open only if the owner revives the hardware and the real switch fails.
      '';
    };
    kernel-collision-gate = {
      title = "checks:kernel:collision — a tied boot.kernelPackages merge now fails a leaf gate, not a host eval";
      kind = "open";
      status = "DELIVERED";
      priority = "P4";
      date = "2026-11-25";
      from = ["dormant-host-gates"];
      summary = "New leaf gate sweeps every nixosConfiguration's boot.kernelPackages merge (~14 s at xargs -P4 over a warmed flake source, one host per oom-guard'd nix process). The tied-definition class that broke minyx and eisen now fails checks:quick; the fixture proves the gate refuses 45dde4c9^ — eisen COLLIDEs, minyx stays clean.";
      refs = {
        hosts = ["minyx" "eisen"];
        modules = ["scripts/task/kernel-collision-check.sh" "tests/kernel-collision/run.sh" "modules/profiles/base-node.nix" "flake/check-inventory.nix"];
        tasks = ["checks:kernel:collision" "checks:kernel:collision:test" "checks:quick" "check:leaf"];
      };
      body = ''
        The class: two definitions tied at the winning priority with
        different values are a hard "defined multiple times" error that
        kills the whole configuration's eval. base-node.nix carried it
        twice — `mkOverride 1500` tied the option default and broke every
        baseline host (eisen until 2026-10-19), and an earlier baseline
        tied raspberry-pi/3's `mkDefault` for minyx. `mkOverride 1200`
        sits strictly between and survives both directions.

        The gate forces `kernelPackages.kernel.version` per host — the
        merge itself, ~1.3 s each, `xargs -P4` over a warmed flake source
        (~14 s; without the warm eval the 25 git+file fetches serialize on
        the store and parallelism gains nothing). A preserved host's
        unrelated eval break is a warning, an active one is cannot-tell.
        Exits 0/1/2 per the scripted-checks convention. `REV=`/`HOSTS=`
        envs serve the fixture: at `45dde4c9^` eisen COLLIDEs naming
        kernel.nix and base-node.nix while minyx stays clean — `mkDefault`
        wins outright, so the gate flags ties, not weaker definitions.
        checks:quick's summary was updated honestly: it is the first dep
        to force a nixosConfiguration attribute; ~50–80 s measured on
        frieren (the tail is build/sops/site work, not this gate).

        Exit: gate live in checks:quick, `check:leaf
        NAME=checks:kernel:collision` resolves, check:verify 137/137,
        fixture green both directions.
      '';
    };
    quick-fixture-audit = {
      title = "checks:quick fixture sweep — every leaf gate now fails on a real or seeded mistake before it may pass";
      kind = "open";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-11-25";
      from = ["kernel-collision-gate"];
      summary = "Every checks:quick leaf gate now has a fail-on-real-mistake proof: 14 tests/<name>/run.sh fixtures (4 real-tree replays, 10 worktree-seeded or crafted), the toon plane closed in round 2. checks:entry stays unfixtured — a timing budget has no mistake; infron/kg/tasks/toon self-fixture inside their scripts.";
      refs = {
        modules = ["tests/shell-inputs/run.sh" "tests/repo-paths/run.sh" "tests/images-check/run.sh" "flake/check-inventory.nix" "taskfiles/checks.yml"];
        tasks = ["checks:quick" "check:verify" "checks:shell-inputs:test" "checks:sops:drift:test"];
      };
      body = ''
        The audit split the uncovered gates in two. Replayable past
        mistakes got worktree fixtures: repo:paths at 7059c0a2^ (five
        files spelled checkout paths), shell-inputs at 0e46552e (the
        xs-notify awk 127, checker copied into the old tree), and
        images against a synthesized IMAGES_ROOT carrying the real
        2026-11-26 session-gated URL row. The rest seed the class on a
        HEAD worktree: a dangling `task` cite, a path-edge import, a
        prose tell (`delve`), three desc-restating skill rows (the
        >=3 hard-verdict threshold, a lone row is WARN by design), a
        malformed workflow yaml, a deadnix unused formal, a
        shell-expansion-in-indented-string interpolation, a dropped
        check-inventory row, and a dropped sops age recipient.

        Two traps: check:verify:test must not carry an inventory row —
        the gate only sees checks:* names (check:verify is rowless
        itself), and a taskfile summary may not spell
        modules/secrets*.yaml on a `sops` line — the secrets-path
        policy grep counts summary text as code. checks:entry stays
        unfixtured: a timing budget has no mistake to seed.

        Round 2 closed the toon plane: toon:tasks:test seeds a bare
        `toon -e` cmd and a hand-cased FORMAT in a worktree;
        toon:surfaces:test crafts a bare `nix eval --json` line (the
        script's file-args exist for negative control); checks:toon
        needs no fixture — it self-seeds under/over-count and refusal
        cases every run, and infron/kg/tasks self-fixture the same
        way. The sweep is complete.

        Exit: checks:quick green (~82 s), check:verify 151/151,
        checks:tasks clean, every fixture refuses then passes HEAD.
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
        **The TV.** Philips 65OLED759/12 at 192.168.3.26, Titan OS: jointSPACE 1925, `_philipstv_s_rpc._tcp` 1926,
        secure-mqtt 8883 — no Cast receiver, no DIAL, nothing on 8008/8009, and SSDP M-SEARCH gets zero replies,
        so discovery tools conclude there is no renderer. Port **49152** is the way in.

        **Any local file, via DLNA.** `curl http://192.168.3.26:49152/description.xml` returns MediaRenderer:1
        (DMR-1.50) with AVTransport at `/avt_control`. Verified 2026-11-11: browse Jellyfin's ContentDirectory
        (library `arr`), take the item's `res` URL, SOAP SetAVTransportURI + Play — transport PLAYING, dur=1:38:40.
        Serving from frieren on a new port fails: the firewall drops it, the set retries to STOPPED.

        **Casting.** `ytcast -pair <code>` redeems the TV code through the lounge pairing API and caches a screen
        id; playback is cloud-relayed via bind, port 8009 never touched.

        **What wedges it.** A live stream (2026-11-11, jfKfPfyJRdk): the app dropped to ambient mode and answered
        nothing afterwards — even VOD vanished with exit 0, because Lounge accepts what the TV never hears.
        Recovery needs a physical key press: `/6/input/key`, `/6/powerstate`, `/6/pair/request` all return 403,
        and the Steam Link's cecmanager has no CLI and is not running.

        **Rule.** VOD only, one cast at a time, opening the YouTube app is the last step — a cast is queued, not
        raised (Bloomberg TV stayed on screen; the video played when the app was opened by hand). Stopping the DMR
        restores the previous input, which is what makes `media:stop` bring the channel back. The `ytcast` task
        allows only not_live/was_live and refuses what it cannot classify — the first guard failed open on
        jfKfPfyJRdk, where yt-dlp errors instead of reporting is_live. Pair again when a cast goes silent.
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
      status = "DELIVERED";
      priority = "P3";
      date = "2026-11-23";
      links = ["closure-budget-coverage"];
      summary = "Closure budget runs as the local gate checks:closure:budget; the CI step that copied it was removed — runners cannot reach a host's store.";
      refs = {
        modules = [".github/workflows/nixcachix.yml" "closure-budgets.toml" "scripts/task/closure-analysis.sh"];
      };
      body = ''
        Landed 2026-11-22, removed 2026-11-23: the build-machines step ran
        `closure-analysis.sh --host <h> budget $result`, and `--host` means
        "SSH-resolve /run/current-system on the live host" — a GitHub runner
        has no host SSH, so the step failed with `could not resolve`, not
        with a budget verdict. The check's real home is local:
        `task checks:closure:budget` measures the deployed closure the same
        way and adopting a baseline stays the operator's deliberate act.
      '';
    };
    one-os-cli = {
      title = "One CLI of the operating system, not a go.mod per domain";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-24";
      summary = "The shell burn-down must not end in a tools/ sprawl of one module per domain. Ports land as internal/<domain> packages inside a single Go binary — a CLI of the operating system — while .#cli.<family>.<tool> and the task names stay the contract callers see. The ledger, the tools/os umbrella (internal/image + internal/serve) and the .#servers.static-serve surface are landed.";
      from = ["jobby-cli-consolidation"];
      links = ["p4-taskfiles-to-evals" "agent-tools-called-not-declared"];
      refs = {
        modules = ["flake/cli.nix" "flake/policies.nix" "tests/policies/run.sh" "tools/os/main.go"];
        tasks = ["checks:policies:fixtures" "checks:tasks"];
        docs = ["docs/task-control-plane.md"];
      };
      body = ''
        **The rule.** The one-OS-CLI path ends at Go, but "a Go
        CLI" per domain is how `tools/` becomes the next `scripts/` — six
        tool dirs today, forty by the time the ledger is empty. The port
        target is one binary — a CLI of the operating system — with
        `internal/<domain>` packages and a `<os> <family> <verb>` surface.
        The binary is `os` (`tools/os`, argv[0] aliases back to the tool
        names); `internal/image` is the first folded domain.

        **The surface stays.** `flake/cli.nix` already keys
        `.#cli.<family>.<tool>`; the one binary backs every family through
        argv[0]/alias dispatch (the busybox shape), so `cli.image.daily`,
        `image_daily_cli` and frieren's slot closures keep resolving while
        there is one module to build, vet and vendor. Taskfiles keep their
        task names — they exec the binary, same contract (jobby M6).

        **What does not fold in.** `tools/turns-runtime` is a benchmark with
        its own nested flake, `tools/selector` and `tools/kg-zeck` are
        one-language experiments — foreign trees, not the task surface.
        `scripts/task/*.sh` retire domain by domain in the budget's
        burn-down order; Python check helpers shrink toward evals per
        `p4-taskfiles-to-evals`, they are not CLI verbs.

        **Landed** `tools-go-modules-are-recorded` (a new `tools/*/go.mod`
        fails unrecorded) and the `tools/os` umbrella: `internal/image`,
        `internal/serve`, `bin/image-daily` and `bin/static-serve` argv[0]
        aliases, `.#servers.static-serve` served by the same derivation.

        Exit: one go.mod under `tools/` serves the task surface — a second
        module fails the policies gate; the ledger keeps shrinking.
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
        Found on the 2026-10-17 module: ~1 GB resident while idle, a root unit with no
        `ProtectSystem`/`PrivateTmp`/`MemoryMax` decoding untrusted audio with ffmpeg, `Restart=always`
        without `StartLimit*` crash-looping on missing weights, no read timeout on the HTTP handler, and
        `--threads 8` deliberate for this CPU budget.

        Delivered 2026-11-20 (6cb73ec9 + 422ad47d, eisen woken by `infra:wol:eisen`): socket activation
        on 127.0.0.1:8091 (`Accept=no`, inherited fd), `--idle-timeout 900`, a 120 s total upload
        deadline, `Restart=on-failure`, and no `wantedBy`. Verified live: 0 B resident while idle (was
        1.05 GiB), 200 through a cold start, 413 at 26 MB, 400 on a 200 B/s drip; `checks:host
        HOST=eisen` 2067 assertions, and the switch is the boot default.
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
        Frieren (4c/8t, UHD 620, 11 GiB) cannot run Qwen 27B/32B at usable precision, so burst inference comes
        from free cloud accelerator hours over an ephemeral tailnet node, with fallback to hosted APIs.

        **Why tutorial implementations break (measured):**
        1. Layer split: Qwen 27B 4-bit (~17 GB) exceeds one T4's 15.3 GiB usable VRAM; Ollama splits layers
           across both cards and generation relay-races at 320 GB/s — 16-18 tok/s.
        2. Prefill stall vs Cloudflare's unconfigurable 100 s free-tier timeout: a 30k-token agent prompt
           prefills in 92 s at T4's ~325 tok/s — requests die as HTTP 524.
        3. Kaggle notebooks die on 20 min idle / 12 h runtime, reissue random URLs per restart, and
           unauthenticated Ollama on public quick tunnels violates Kaggle ToS.

        **The alternative: Kaggle TPU VM v3-8 + Tailscale.** 8 chips x 16 GB HBM = 128 GB at 800 GB/s per
        chip; vLLM (>= 0.28.0, Kaggle TPU Lab) runs Qwen 27B at full FP16/BF16 (55.6 GB, 262k context):
        ~130 tok/s generation (8x), ~10,300 tok/s prefill (30x — 30k prompt in 3 s). An ephemeral Tailscale
        auth key replaces tunnels entirely: zero public exposure, no timeout, stable tailnet hostname.

        **Why not prod.** Headless daemon tunnels on free-tier Kaggle are gray-area under the June 2025 AUP;
        the notebook lifecycle is non-durable; a week of Kaggle quota is worth ~$4.31 at $1.49/1M tokens on
        commercial endpoints. Exit: automated notebook launch verified over Tailscale, a validated Hermes
        failover event on notebook termination, authenticated endpoint tokens.
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
        SimpleX is already the fleet's encrypted bus: SMP on frieren `:5223`, the client daemon on `:5225`.
        What is missing is a declarative way for agents to dispatch work between hosts —
        frieren handing a compile to `eisen`, or pulling telemetry from `schneeeule` — without a central relay.

        **Shape.** A profile standardising the WebSocket JSON-RPC dispatch protocol across nodes: a peer list
        with roles, an allowed-command set (`ping`, `build-closure`, `query-telemetry`) and an audit log, with
        peers authenticated by pre-shared signing keys and messages carried end-to-end encrypted over SimpleX.

        **Evidence.** `simplex-chat.service` runs on frieren and `simplex-rpc.py` already exists in the
        `simplex-admin` skill, so only the profile and its policy are missing.

        **Why not prod.** Unrestricted dispatch between autonomous agents is privilege escalation if one edge
        node is compromised. Exit: a ping and a telemetry dispatch between frieren and a second node with no
        human intervention and full signature verification.
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
        SimpleX Chat is the encrypted inter-agent bus; autonomous hosts exchange dozens of `#Fleet` messages
        daily, and without semantic classification the operator gets push notifications for every routine
        heartbeat. `services.simplexMessageClassifier` is an inline gateway between the WebSocket RPC daemon
        (:5225) and the agent ingestion runtime: Julia-1 classifies each decrypted message in its 8k context
        into FLEET_HEARTBEAT_STATUS (silent log), BACKGROUND_CLOSURE_WARMED (daily digest), or
        CRITICAL_SECURITY_INCIDENT / HARDWARE_FAULT (immediate push with severity, host, runbook).

        **Module shape.** `services.simplexMessageClassifier` = { enable; model = "julia-1"; listenPort = 5225;
        monitoredGroups = [ "#Fleet" ]; priorityThresholds = { silent = 0.40; digest = 0.70; immediateAlert = 0.85; }; }

        **Evidence.** SMP server on *:5223, client daemon on 5225, `#Fleet` connects frieren/devji/guckloch, and
        `simplex-rpc.py` talks to the daemon in sub-millisecond roundtrips.

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
        frieren runs the fleet resolver, and a VRRP VIP can go split-brain — two hosts answering the same
        address — during interface transitions or when a secondary resolver returns (`hc3-check`).

        **Shape.** Microsecond ARP and DNS probes across both interfaces, a decision on which node is primary
        from upstream latency, and gratuitous ARP to force convergence, driven by the resolver's own state
        rather than by a human.

        **Evidence.** `task checks:dns:failover` (HC-3) already probes the VIP for two answering MACs, so the
        detector exists; the arbiter and its action do not.

        **Why not prod.** Untested under cable disconnection and WiFi roaming. Exit: a simulated dual-master
        conflict resolves to one authoritative resolver in under 2 seconds.
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
        Restic keeps file-level state, but bare-metal recovery from frieren's Btrfs subvolumes (`data`,
        `private`, `transmission`) wants `btrfs send -p | btrfs receive` over the tailnet, which moves extents
        rather than rereading millions of files.

        **Shape.** A service that walks the subvolume parent-child generations, streams a differential to a
        remote peer (`btrfs send -p @prev @curr | zstd -3 | pv -L 15m | ssh poseidon btrfs receive ...`) and
        rate-limits the wire during user hours, with a schedule confined to the backup window.

        **Evidence.** `btrfs send`/`receive` are on the system path and `poseidon` is a connected tailnet peer.

        **Why not prod.** Re-anchoring when a middle snapshot is pruned is untested. Exit: a 50 GB
        differential transmitted and mounted on the peer with zero checksum errors.
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
    egress-lanes-research = {
      title = "Three egress lanes: delphi for bulk, frieren for identity, lumi for US geo";
      kind = "proposal";
      status = "IN FLIGHT";
      date = "2026-11-27";
      summary = "Route each research fetch by what its link is good at — delphi's own line for bulk, frieren's residential IP for hostile sources, lumi's US address for geography — through one fetch broker, so a crawl is charged to the tailnet once and the home line spends trust rather than bytes.";
      from = ["gigabit-seams"];
      refs = {
        hosts = ["delphi" "frieren" "lumi"];
        modules = [
          "modules/services/fetchcache/fetchcache.go"
          "modules/services/fetch-broker.nix"
          "modules/services/tailnet-forward-proxy.nix"
          "modules/services/link-vault.nix"
          "modules/services/job-db-scraper.nix"
          "modules/services/private-deals.nix"
          "hosts/delphi/configuration.nix"
          "hosts/lumi.nix"
          "modules/net/dns/tailnet-address.nix"
        ];
        tasks = ["checks:ports" "checks:host" "ops:notes"];
        docs = ["docs/media-relay.md" "docs/storage-taxonomy.md"];
      };
      body = ''
        **Seen live.** delphi 92.5.115.103 AS31898, frieren 79.215.107.59 AS3320
        direct, lumi DERP-only (dfw), so 93.127.139.146 stays a lookup.

        **Built, ranked (Jev 1.14.0).** Cache then broker: a page comes from
        `fetchcache`, only a miss spends a lane — cache 57%, broker 30%, sink 7%,
        both 61% at 0.52.

        **Measured (2026-11-28, delphi, 20 URLs, twice).** Cold p50 154 then 152 ms,
        p95 823 then 726, 1.40 MB upstream; warm p50 46 then 41 ms, 0.085 MB — 94%
        fewer bytes, 3.3-3.7x faster; direct p50 165 then 256 ms.

        **Throughput (2026-11-28, 4-6 MiB, cache off, p50).** Mbps: bulk 52 then
        51, `us` 34 then 38, `local` 18.3 then 18.6; four streams give 51, 41, 18,
        so the lane is the ceiling. Two mirrors from delphi's own NIC hold 43-52
        at one and at four streams: bulk is a ~50 Mbps line, not gigabit.
      '';
    };
    egress-architecture = {
      title = "Egress is one broker on delphi, three lane exits, a validator before any lane";
      kind = "reference";
      status = "DELIVERED";
      date = "2026-11-28";
      summary = "A scrape enters at delphi:8469, a stored validator answers before a lane is spent, and a miss leaves by bulk (delphi direct), us (lumi) or local (frieren) — so trust and geography belong to the exit, never to the caller.";
      from = ["egress-lanes-research"];
      refs = {
        hosts = ["delphi" "frieren" "lumi"];
        modules = [
          "modules/services/fetch-broker.nix"
          "modules/services/fetchcache/fetchcache.go"
          "modules/services/tailnet-forward-proxy.nix"
          "hosts/delphi/configuration.nix"
          "hosts/lumi.nix"
        ];
        tasks = ["checks:ports" "checks:host"];
        docs = ["docs/media-relay.md"];
      };
      body = ''
        **Placement.** One door: `fetch-broker` on delphi, loopback 8107, published
        tailnet-only at :8469 by the servicePortal mount — no firewall port, so a
        crawl is charged to the tailnet once. Delphi owns it: its bytes are cheapest
        and its datacenter address may be spent; the lanes are peers, not tunnels.

        **Lanes.** `bulk` is delphi's own NIC with no proxy hop; `us` is lumi's
        tinyproxy at :8470 (four clients), `local` is frieren's at :8471 (sixteen).
        Each binds `tailscale ip -4` and allows only 100.64.0.0/10, so a lane is a
        tailnet address that can be retired. MagicDNS is off here, so the broker
        resolves them from `inventory.toml` and delphi asserts both keys exist.

        **Policy.** Identity before bandwidth. `bulk` for sources that answer a
        datacenter (RSS, sitemaps, HF, GitHub, corpora), `us` for US geography,
        `local` for sources that trust only a residential IP and for the render door
        at 127.0.0.1:3002. The one retry is `us` -> `bulk`, reported as
        `fallback: true`; nothing retries `local`, because a blocklist hit is a fact
        about the exit and repeating it spends the one address the fleet cannot
        replace.

        **Order.** Validator, then lane. `fetchcache` keys by SHA-256 of the
        normalized URL, stores body, status, headers, ETag, Last-Modified and
        fetched-at per lane, and revalidates with `If-None-Match` — a 304 is the only
        zero-upstream-byte hit, and there is no TTL. The broker consults it before a
        lane is touched; `cache: false` is the one bypass. A repeat therefore costs
        no lane bytes and no blocklist budget.

        **Latency (2026-11-28, delphi:8469, five probes, cache off).** Warm p50:
        `bulk` 138 ms, `us` 194, `local` 159 — and each exit IP is its own lane:
        92.5.115.103 delphi, 93.127.139.146 lumi:8470, 79.215.107.59 frieren:8471.
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
      status = "CLOSED";
      priority = "P3";
      date = "2026-11-25";
      summary = "4169→7259 comment lines in tracked .nix files (AGENTS.nix excluded) swept to pointer form: every Story:/Trap:/Fact: resolves, and the two dangling cites (port map, pti=off) got real homes in docs/. Residual mass is inline explanation, the accepted end state.";
      refs = {
        hosts = ["delphi" "frieren" "netbook"];
        modules = ["hosts/delphi/configuration.nix" "hosts/frieren/configuration.nix" "hosts/frieren/infra-stack.nix" "lib/aki-site.nix" "hosts/netbook/configuration.nix" "flake/outputs.nix" "modules/user/ai/hermes-user.nix"];
        tasks = ["dev:qmd:refresh"];
        docs = ["docs/delphi-runtime.md" ".agents/deploy/hosts/frieren.md" ".agents/deploy/hosts/netbook.md"];
      };
      body = ''
        **The goal is routing, not deletion.** A comment is not slop because it
        is long; it is out of place when its kind belongs to another channel.
        Deleting it loses the reasoning that made a fix correct.

        **Categories, and the channel that owns each.** Policy/trap →
        `flake/policies.nix` predicate or an option assertion; fleet fact →
        `inventory.toml` (`dev:inventory:feed`); why/history → an AGENTS.nix
        note; procedure → `taskfiles/*.yml` or `writeShellApplication`; durable
        explanation → `docs/` (prose keeps a pointer).

        **Measured** 4169 comment lines 2026-10-21; 7014 by 2026-11-23 when
        61a1f1ba pruned boilerplate and banners routed durable-why.

        **Cite sweep 2026-11-25**: every `Story:`/`Trap:`/`Fact:` pointer in
        the five heavy files resolves; `Fact: port map` was dangling — the
        mount table in `docs/delphi-runtime.md` is it now, and infra-stack's
        uncited blocks moved to its deploy doc + `image-daily-queue`.

        **Tail sweep, same day** (netbook, outputs.nix, hermes-user): already
        pointer-form. One dangling cite — netbook's `§"pti=off"…` — got its
        section in the deploy doc; the stale "newest kernel" claim beside it
        was corrected to the measured initrd story. Gates: nix-comments rc=0
        (519 pointers, all task cites resolve), checks:policies PASS. CLOSED.
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
        **The rule.** Move what has no library and no shared logins, and keep the
        name and the copy behind. stirling-pdf went 2026-10-21; paperless,
        vaultwarden and anki 2026-11-02. `docs.`, `vault.` and `anki.frieren.lan`
        stay frieren's vhosts, and `services.offloadBridge` mirrors every tree to
        `/srv/backup/offload` at 03:10, inside the restic window. The tunnel file
        was deleted only after all three names answered with frieren holding no
        loopback listeners.

        **What is left is a decision.** hermes stays resident on both hosts (each
        gateway polls its own bot token). The monitor pair moved 2026-11-04: gatus
        and the empty uptime-kuma left frieren, the checks run in delphi's
        `services.fleetMonitors` over the tailnet, alerts post back to frieren's
        SimpleX bridge. A name that lives on frieren still needs frieren's nginx.

        **Exit — met.** Each moved unit is gone from frieren's system.slice and
        serves from delphi; the shelter copy sits under `/srv/backup/offload` in a
        restic snapshot. Verified 2026-11-20 (devin): delphi answers on the tailnet
        (stirling :8445 → 200, gatus :8181 → 200) while the three `*.frieren.lan`
        names stay frieren vhosts, and snapshot d2228859 (03:30) carries the four
        offload trees. Memory shed ~1.4 GiB (stirling 633, paperless ~480,
        uptime-kuma 137, vaultwarden 58, gatus 42, anki 6 MiB).

        **Finished 2026-11-26.** Delphi's own uptime-kuma — enabled, listening on
        :8448, zero monitors — was the last duplicate. Service, portal card and
        `fleetSentinel` watch entry are gone, and `services.fleetMonitors` asserts
        no host runs gatus and uptime-kuma together.
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
        Procedure is `docs/sops-rekey.md` § *TPM-sealed identity* (the skill that duplicated it was
        deleted: `agent-prose-budget`). Three facts a reconstruction gets wrong: (1) two rebuilds,
        because rebuild A installs `security.tpm2`, `tss` and `age-plugin-tpm` and must not reference
        the identity that rebuild B points `sops.age.keyFile` at; (2) `sops.age.plugins` on both
        planes, since sops-nix sets the user unit's `Environment=PATH=` to exactly that list and
        `home.packages` does not reach it, so an empty PATH dies on `0 successful groups required,
        got 0`; (3) `tss` is per session, so the first user-plane start after the group change still
        fails until a reboot. Verify the store copy, not a checkout: the unit decrypts
        `/nix/store/<hash>-secrets.yaml`, and on scratch `~/Documents/nixconfig` is a home-manager
        store symlink that cannot be pulled. Pair the decrypt with a `SOPS_AGE_KEY_FILE=/nonexistent`
        control that must fail. Scratch passed both planes 2026-10-22 (`5042298e…` encrypted,
        `436f477d…` plaintext, control exit 128), and `p256tag` works on sops 3.13.3 / age 1.3.2.
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
        Delivered 2026-10-27: the session is the fleet's. tty1 autologins and execs
        `/etc/xdg/dwl-session` (NixOS's `programs.dwl`), driven by this profile's spliced-keymap
        `package` and `extraSessionCommands`, so no PATH shadows the compositor; her layer is
        `hosts/netbook/dwl-keybinds.h`, spliced *first* because dwl takes the first match. niri, waybar,
        greetd and gnome-keyring left the closure; mako, fuzzel, alacritty and swaylock left the bridge
        block, so the closure carries fnott at 112 MiB (was mako 326) and the profile ships
        `/etc/xdg/fnott/fnott.ini`. A card identifies itself by a unique *summary* (`fnottctl list` →
        `id: <summary>`), bodies pass through `strip_span` because fnott draws `<span>` literally, and
        menus/lock are `wmenu -p/-l/-P` and `waylock -fork-on-lock`. Proven: fnott owns the bus name, a
        synthetic Notify reads back through `fnottctl list`, and `checks:host HOST=netbook` is green.
        Losses and mapping: `docs/netbook-rice-port.md`.
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
        **Shape.** CI refuses the LAN cache by design, so a runner cannot substitute what
        frieren or delphi built: R2 charges no egress and 10 GiB is the free tier. Each
        path is HEADed against every non-LAN cache in the registry (cachix, the bucket,
        cache.nixos.org, numtide, nix-community, nix-gaming, determinate); only misses
        upload, and a push crossing the budget is refused before writing — hence the
        entry sits immediately after `cachix` in every order.

        **The edge never signs.** narinfo is signed by the pusher (`secret-key=`), so a
        Worker key would reimplement Nix's fingerprint; `CACHE_AUTH_TOKEN` was refused
        because `nix copy` has no `--header`.

        **Numbers live in the doc.** `docs/nix-cache-edge.md` carries the closure table
        (2728 paths / 18.48 GiB, 771 MiB unique per system, ~13 systems per 10 GiB), the
        retention shape, the arch-routed sync and the traps measured on a live push.
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
        - 2026-11-11 correction: InfluxDB's retirement did not stick. Scrutiny
          0.9.5's influxdb probe is unconditional — the web server panicked at
          startup and restart-looped 264 times, so smart.frieren.lan answered
          502. It stays on, narrowed to 127.0.0.1:8086.
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
          "tools/os/internal/image/cloudinary.go"
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

    delphi-host-clone-not-authority = {
      title = "The checkout on delphi is not the tree that is deployed";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-26";
      summary = "Delphi keeps a clean, never-fetched clone of an October history that no unit builds from; the running generation comes from an archived flake source, so a rebuild there would run last month's config. Decide: delete it, or re-point it at the authoritative remote.";
      refs = {
        hosts = ["delphi"];
        modules = ["hosts/delphi/infra-stack.nix"];
        tasks = ["infra:deploy:host:delphi"];
        docs = [".agents/deploy/hosts/delphi.md"];
      };
      body = ''
        Measured 2026-11-26 with `sudo git -C /root/Documents/nixconfig log -1`:
        `main` at e1216fa2 (2026-10-26), clean, no FETCH_HEAD, `modules/secrets`
        uninitialised. The subject exists here as 57679c54, so the host holds a
        different history rather than an older copy — it cannot fast-forward to
        what runs. No systemd unit, `/etc/nixos` file or keeper path names it.

        Inert but not harmless: it is the only git tree on a host people ssh
        into, and a `nixos-rebuild --flake` against it rebuilds October. Delphi
        switches from an archived source (`nix flake archive`, then
        `/nix/store/<src>#delphi`), which the runbook now says.

        The other half: local `main` holds the commits delphi runs and
        `git branch -r --contains` names no remote for them, while `origin/main`
        is a different commit. Until one is pushed, the deployed tree exists in a
        single working copy.

        Exit: `ssh delphi 'sudo rm -rf /root/Documents/nixconfig'` — or the tree
        tracks the authoritative remote and fast-forwards; re-measure either way
        before trusting a rebuild from it.
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
        modules = ["hosts/frieren/configuration.nix" "hosts/frieren/reverse-proxy.nix" "hosts/frieren/dns.nix" "hosts/frieren/infra-stack.nix"];
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

    hm-leaf-chain-split = {
      title = "The remaining HM chains: roles.home's minimal hardcode and the user.base/user.ai leaf lists";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-11-24";
      summary = "After the per-host list split (hmFeatures/hmModules landed 1ce4ac4f), three hardcoded import lists still landed multi-host: roles.home's unconditional roles.minimal (12 embedded hosts), roles.minimal's [user.base user.ai] (22 hosts), and the leaf lists inside user.base (7 imports) and user.ai (6). Same shape as the earlier splits: maps stay shared, lists became per-host data.";
      from = ["eval-cost-ladder"];
      refs = {
        hosts = [
          "poseidon"
          "eisen"
          "frieren"
          "stark"
          "fern"
          "schneeeule"
          "scratch"
          "aristotle"
          "diogenes"
          "aceofspades"
          "ancientace"
          "cassini"
          "mtfuji"
          "kellerbench"
          "deckstation"
          "delphi"
          "applevalley"
          "ares"
          "guckloch"
          "sledgehammer"
          "alarm"
          "kali"
        ];
        modules = [
          "modules/roles/home.nix"
          "modules/roles/minimal.nix"
          "modules/user/base.nix"
          "modules/user/ai/default.nix"
          "flake/host-inventory.nix"
          "modules/global/home-manager-shared.nix"
          "modules/global/noDE.nix"
        ];
        tasks = ["checks:drv-equality" "checks:host" "checks:quick"];
      };
      body = ''
        Blast radius (ops:kg:blast + host-inventory join — the kg sees static
        self.modules."x" references but not the dynamic hmModules resolution, so
        roles.lean/roles.demo show 0 importers while clanker/demo consume them):

        - roles.home → 12 embedded hosts via the fleet.hmUserModules default:
          poseidon, eisen, frieren, stark, fern, schneeeule, scratch, aristotle,
          diogenes, aceofspades, ancientace, cassini.
        - roles.minimal → those 12 via roles/home's hardcoded import, plus
          hmModules on mtfuji, kellerbench, deckstation, delphi, applevalley,
          ares, guckloch, sledgehammer (containers), alarm, kali — 22 hosts.
        - user.base (scripts, lf, env, shell, sops, helix, lynx) and user.ai
          (aichat, antigravity-cli, skills, freebuff-remote, mainframe-remotes,
          zed-mcp) → the same 22 through minimal. Containers pay the import
          surface then gate it off (noDE: profiles.ai.enable=false).
        - roles.lean (clanker) and roles.demo (demo): already per-host.

        Plan, consistent with list-per-host / map-shared:
        1. `minimal` becomes a named entry in roles/home's features map; every
           embedded host's hmFeatures gains it (drv-identical) so the base+ai
           floor is droppable per host.
        2. roles.minimal's list becomes the same map shape (hmMinimalFeatures),
           or dissolves into the 10 consumers' hmModules (penguin's pattern).
        3. user.base / user.ai lists become per-host data (hmBaseFeatures /
           hmAiFeatures) so a container's AI-off is data, not option disables.

        Landed: minimal is a named feature; user.base/user.ai take
        hmBaseFeatures/hmAiFeatures args via extraSpecialArgs in all four
        chains. Containers then dropped user.ai entirely — hmModules names
        user.base + shell + user.ai.skills, and noDE's profiles.ai enable
        went with the surface it gated. 30/30 drv-identical both times.
      '';
    };
    desktop-facts-one-module = {
      title = "Desktop duplicated facts consolidated; heterogeneous power policies stay local";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-27";
      summary = "Desktop fact dedupe landed: global dms owns greeter defaults, tailscale accept policy is data, nas-client owns host mount options, Haswell graphics is a leaf, and ssh.ca client is a desktop-chain default; the supposed laptop-power trio was rejected as heterogeneous policy.";
      from = ["hm-leaf-chain-split"];
      refs = {
        hosts = ["aristotle" "diogenes" "poseidon" "stark" "fern" "eisen" "delphi" "frieren"];
        modules = [
          "modules/profiles/base-desktop-environment.nix"
          "modules/global/dms.nix"
          "modules/global/tailscale-policy.nix"
          "modules/profiles/nas-client.nix"
          "modules/profiles/haswell-graphics.nix"
          "modules/profiles/desktop-client.nix"
          "modules/ssh-ca.nix"
          "flake/host-inventory.nix"
        ];
        tasks = ["checks:drv-equality" "checks:host"];
      };
      body = ''
        Implementation corrected two audit facts: stark is Kaby Lake/iHD, not
        Haswell, and thermald/fstrim/logind are distinct host power policies
        rather than one verbatim laptop trio. Landed: modules/global/dms.nix
        owns the dms greeter default; non-greeter dms hosts opt out as data,
        while frieren is off in the headless base and on in the desktop
        specialisation. modules/global/tailscale-policy.nix generates the
        accept-dns/accept-routes flags, desktop-client opts in, and hosts tune
        booleans. nas-client owns extraOptions, so the aristotle/diogenes
        Frankenmount blocks are deleted. haswell-graphics is imported only by
        aristotle/diogenes. ssh.ca client is mkDefault true on the desktop
        chain, with explicit false where the host did not already use it.
        Evidence: checks:host passed on aristotle plus poseidon, stark, fern,
        frieren, schneeeule, scratch, aceofspades and ancientace. Scoped
        checks:drv-equality compared eleven affected/representative hosts as
        identical after a transient aristotle watchdog rerun. diogenes/eisen
        were already host-protected in the pre-refactor baseline, so their
        derived equality could not be measured on this machine.
      '';
    };

    job-scout-lane-state-2026-11-24 = {
      title = "The boards are mined out, so the lane tailors HITS.nrw's CV and German letter";
      kind = "open";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-11-24";
      summary = "The lane turns from sweeping to tailoring: arbeitnow's sixteen pages, the Greenhouse/Lever/Ashby/Personio/Recruitee boards and remotive are exhausted, RemoteOK and BA jobsuche answer 403, jobicy/nomads/himalayas/interamt are dead. HITS.nrw (fit 4, Düsseldorf, Linux/K8s app operations, 2 lead rows) is the active target.";
      links = [
        "job-scout-boards-exhausted-2026-11-24"
        "job-scout-wide-feed-sweep-2026-11-24"
        "job-scout-daily-feed-sweep-2026-11-24"
      ];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["apps:scout" "apps:update" "checks:quick"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The boards are mined out, so this lane stops sweeping and tailors.

        Exhausted: arbeitnow's sixteen pages, the Greenhouse, Lever, Ashby,
        Personio and Recruitee boards by family, remotive's devops feed.
        Blocked, not empty: RemoteOK and BA jobsuche answer 403 from this
        host. Dead: jobicy, Working Nomads, Himalayas, interamt; a further
        pass would re-read the same postings.

        Active target: HITS.nrw — Hochschul-IT-Services.nrw, Düsseldorf,
        Application Operator / DevOps Engineer, Linux and Kubernetes, fit 4,
        the only fit-4 German role whose day is own-fleet Linux rather than a
        vendor estate, so the German ad wants a German Anschreiben. Next
        action: tailor the CV and write that letter, with no sweep behind it.
        Drift: HITS.nrw holds two lead rows, `hits-nrw-application-operator-
        devops` beside a truncated slug, one employer to one row once merged.

        Nothing sends before 2026-12-07; the lane has no send verb.

        Exit: HITS.nrw is `applied` with a receipt and the duplicate merged.

        Delivered 2026-11-24 as a prep packet, not a send: a German CV
        projected onto the ad (15 of 39 highlights, 4 of 10 projects) and an
        Anschreiben to Heather Baumgarten live under
        `~/.local/state/appflow/submissions/hits-nrw-application-operator-devops`;
        the duplicate is merged and the 2026-12-07 hold owns the send.
        HiSolutions AG followed (German ad, remote, fit 5) with a curated CV
        and Anschreiben under
        `~/.local/state/appflow/submissions/hisolutions-ag-senior-kubernetes-expert-devops-engineer`,
        its stored JD replaced by the employer's own text after remotive's scrape.
      '';
    };
    job-scout-lane-2026-11-25d = {
      title = "One packet from the 2026-11-25c sweep, and place filtered before the next read";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "The ten 2026-11-25c leads were read at source: Oxoia (Baden) is the packet — German ad, Linux fleet operations, IaC and coding agents as the daily standard. The other nine park, seven on place (Paris, London, Nantes, UK client sites, 60-80% on site) and two on skill.";
      links = ["job-scout-lane-state-2026-11-24"];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["apps:scout" "apps:update" "checks:quick"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Ten rows say `Sweep 2026-11-25c`; four more share the origin string
        from the earlier p5 pass (DAM, ICG, MY Humancapital,
        headhunter.digital) and are still at scouted.

        Packet: Oxoia (Baden, Aargau) — a growing fleet of devices in customer
        buildings, Linux in operation, IaC, Git, Python and Bash, coding
        agents named as the working standard, German. Build the German packet
        once the 2026-08-26 listing is confirmed open.

        Parked on place: Artefact and Doctrine (Paris, French), Optiverus and
        Signal AI (London), Opencast (UK client sites), S-quaar (Nantes, one
        remote day), Talmatch (60-80% on site). Parked on skill: Alta Ares
        (ground-station networking for a defence prime) and OBRO (Windows and
        M365 generalist with helpdesk, posted 2025-04).

        Rule for the next pass: a lead resolves only if the ad is
        German-language or EU-remote. Nine of ten reads ended in the same
        verdict, so place is filtered before the read, not after it.

        Read the ad from the page's JobPosting JSON-LD over curl: the rendered
        arbeitnow page times out at 20 s, and `employmentType` there reports
        permanent Swiss roles as TEMPORARY.

        Nothing sends before 2026-12-07.
      '';
    };
    job-scout-boards-exhausted-2026-11-24 = {
      title = "Nine employers sit at lead and the feeds behind them are mined out, so the lane tailors instead of sweeping";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Nine employers, eleven rows, all stage lead after the 164af385, 7b40455e and c9f09993 sweeps: HITS.nrw, Shipzero, Wellis and noris at fit 4, TecTake, Studytube, Projektron, Rheinmetall and CHECK24 at fit 3. Arbeitnow's sixteen pages, the Greenhouse/Lever/Ashby/Personio/Recruitee boards and remotive are mined out; RemoteOK and BA jobsuche only answer 403.";
      links = [
        "job-scout-lane-state-2026-11-24"
        "job-scout-wide-feed-sweep-2026-11-24"
        "job-scout-daily-feed-sweep-2026-11-24"
      ];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["apps:scout" "apps:query" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Nine employers, eleven rows, all `stage lead` after the three
        2026-11-24 sweeps — and the feeds behind them are mined out, so the
        lane's next move is tailoring, not another pass.

        fit 4  HITS.nrw       Düsseldorf  Linux/K8s app ops     2 rows
        fit 4  Shipzero       Hamburg     AI platform engineer  2 rows
        fit 4  Wellis         Rotterdam   DevOps/Platform       on-site NL
        fit 4  noris network  Nürnberg    OpenStack networking  remote DE
        fit 3  TecTake        Igersheim   senior infrastructure Microsoft
        fit 3  Studytube      Amsterdam   cloud engineer        on-site NL
        fit 3  Projektron     Berlin      cloud engineering     German C1
        fit 3  Rheinmetall    Düsseldorf  Linux and container   OpenShift
        fit 3  CHECK24        Hamburg     Ansible and Linux     big estate

        Mined out: arbeitnow's sixteen pages (3,761 postings, four untracked
        hits, all agencies or non-engineering); the Greenhouse, Lever, Ashby,
        Personio and Recruitee boards by family; remotive's devops feed (15
        postings, none EU-eligible). Blocked, not exhausted: RemoteOK and BA
        jobsuche answer 403 from this host, so an empty result is the bot
        wall. Dead this round: jobicy, Working Nomads, Himalayas, interamt,
        stellenblatt, devjobs.de (client-rendered), Berlin Startup Jobs RSS,
        and the plusserver, secunet cloud, Univention, LINBIT, Open-Xchange,
        Proxmox, Stackable and B1 careers pages.

        So the next lead comes from an employer page or a search on German
        role phrasing — what surfaced noris, Rheinmetall and CHECK24.

        Drift: HITS.nrw and Shipzero hold two lead rows each, cloudpunks two
        more — dupes by the one-row-per-employer rule. Exit: all nine applied
        with a receipt or closed with a reason, dupes merged, note DELIVERED.
      '';
    };
    job-scout-next-sweep-freebuff = {
      title = "The next idle freebuff lane task is one more employer-lead sweep";
      kind = "handoff";
      status = "DELIVERED";
      priority = "P3";
      date = "2026-11-27";
      summary = "The named vendor sweep ran 2026-11-27: SUSE's Premium Support req 71007910 is still live and Giant Swarm and LINBIT state no openings, while B1, Univention, Open-Xchange and Proxmox each hold a tracked row with a stronger live req. No new employer, no row minted, nothing sent.";
      refs = {
        modules = [
          "taskfiles/apps.yml"
          "taskfiles/bountystash.yml"
          "scripts/task/apps-scout.sh"
        ];
        tasks = ["apps:scout" "apps:search" "apps:query" "matt:cv:check"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Task: one more employer-lead sweep of the four families — devops, sre,
        platform, infrastructure — run from the idle freebuff lane.
        `task apps:search -- <company>` runs before every `apps:scout`, because
        a duplicate employer stays one row and a second row closes as a dupe,
        losing the lead. A dead route is a finding, not a failure.

        Prep-only to 2026-12-07: nothing is sent from this lane, and the hold
        covers row creation too, so the sweep's evidence lands under
        `~/.local/state/appflow/followups/` and any `apps:scout` row is written
        only once the hold lifts. The five ranked packets (netcup 1, Eficode 2,
        mogenius 3, KHS 4, Advantest 5) stay `stage lead` and stay untouched.

        Ran 2026-11-27: all seven vendor pages re-read live, `apps:search` first
        for each. No new employer — Giant Swarm and LINBIT state no openings,
        SUSE's req 71007910 is still live and already carried by the 2026-11-25t
        file, and B1, Univention, Open-Xchange and Proxmox each hold a tracked
        row with a stronger live req on the same thread. Verdicts and routes:
        `~/.local/state/appflow/followups/2026-11-27-employer-lead-sweep-freebuff.md`.
        Exit met: `checks:quick` green, no row minted, nothing sent.
      '';
    };
    job-scout-sre-platform-sweep-2026-11-24 = {
      title = "Three fresh SRE/platform leads landed; the tracked set already owns the rest";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Evening sweep of devops/sre/platform/infrastructure: Makersite (remote Germany, EUR 80-100k), Catapult Sports Cologne (self-hosted K8s) and Dymatrix Platform Architect are new rows; Orbem, Enpal, n8n, Nebius, Attio, ClickHouse and workidentity were checked and already carry a row, so they close as duplicates rather than being scouted twice.";
      links = ["job-scout-next-sweep-freebuff"];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["apps:scout" "apps:search" "checks:quick"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Swept the four families on 2026-11-24 evening: Greenhouse, Ashby,
        Lever, Personio and Recruitee boards for employers not yet on file,
        plus the arbeitnow feed and the employer careers pages of the EU
        vendors the earlier notes named.

        New rows: Makersite (remote-first within Germany, Berlin/Stuttgart,
        EUR 80-100k, ISO compliance plus backup RTO/RPO and on-call
        ownership); Catapult Sports Cologne (Kubernetes across self-hosted
        clusters and AWS, Terraform/Ansible with GitOps, GitLab CI, GPU
        clusters — the closest shape to a fleet-shaped Linux platform job
        this lane has found); and Dymatrix Platform Architect, which is
        architecture of a marketing-data platform rather than SRE
        operations.

        Checked and already on file, so closed as duplicates rather than
        re-scouted: Orbem and Enpal rejected, n8n applied, Nebius, Attio,
        ClickHouse, Qonto, Swile, workidentity, Xempus and DeepL tracked.

        Route: all three are ATS forms (Recruitee, Greenhouse, the
        employer's own form), not mailboxes, so a packet cannot leave by
        mail and the 2026-12-07 hold still governs the sends.

        Exit: all three rows reach `applied` with a receipt, or are closed
        with a reason; `checks:quick` green.
      '';
    };
    job-scout-wide-feed-sweep-2026-11-24 = {
      title = "Widened feed sweep: HITS.nrw, TecTake and Studytube are new; trawa and Biz Factory already carry rows";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Third 2026-11-24 sweep, sixteen arbeitnow pages (3,767 postings) filtered on title and a German location or remote: Hochschul-IT-Services.nrw (Düsseldorf, Linux/Kubernetes application operations, fit 4), TecTake (Igersheim, senior infrastructure, fit 3) and Studytube (Amsterdam, cloud engineer, fit 3) are new rows.";
      links = ["job-scout-daily-feed-sweep-2026-11-24"];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["apps:scout" "apps:get"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Went to sixteen feed pages (3,767 postings) instead of the six the
        earlier sweeps used, then filtered on a devops/SRE/platform title
        with a German location or remote. Three rows, all untracked:

        Hochschul-IT-Services.nrw, Düsseldorf (Application Operator /
        DevOps Engineer, Linux and Kubernetes) — the newly founded central
        IT provider for NRW's public universities: HISinOne, Moodle and
        ILIAS on Linux application servers and Kubernetes, Puppet, CI/CD,
        monitoring and 2nd/3rd-level incidents. Fit 4, the closest to
        own-fleet operations this lane has found in Germany.

        TecTake, Igersheim (Senior Infrastructure Engineer) — e-commerce
        central infrastructure across on-prem, Azure and Google; Windows
        and Linux, virtualisation, backup and storage, M365 and AD,
        scripting. Fit 3: the Linux and automation half fits, but the
        centre of gravity is Microsoft.

        Studytube, Amsterdam (Cloud Engineer) — owns its AWS estate,
        Terraform, CI/CD, security and monitoring. Fit 3: right shape and
        English-language, but Amsterdam on-site, so it waits on the same
        relocation question as Wellis.

        Closed as already on file: trawa (Senior Platform Engineer, prep)
        and Biz Factory (applied) reappeared under their tracked titles,
        and IONOS, gridscale, DENKweit, eleQtron, virtual7, wabcon,
        Projektron, Shipzero and Wellis were in the feed again.

        Route: all three apply through their own forms; the 2026-12-07
        hold governs the sends.
      '';
    };
    job-scout-daily-feed-sweep-2026-11-24 = {
      title = "Daily-feed sweep: Shipzero, Wellis and Projektron are new; the rest of the day's feed was already on file";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Second 2026-11-24 sweep, over arbeitnow's same-day feed rather than ATS boards: Shipzero Hamburg (AI Platform Engineer, fit 4, packet tailored), Wellis Rotterdam (DevOps/Platform, fit 4, NL on-site) and Projektron Berlin (Cloud Engineering, fit 3, German C1) are new rows; nine employers in the same feed were already on file.";
      links = ["job-scout-sre-platform-sweep-2026-11-24"];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["apps:scout" "agents:apps:packet"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Swept arbeitnow's Germany, Netherlands and Switzerland feeds on
        2026-11-24 evening rather than the ATS boards again, because the
        roles posted that day are what the boards do not yet carry. Three
        new rows, all posted the same day:

        Shipzero, Hamburg (AI Platform Engineer) — the LLM-agent platform
        on top of a logistics-emissions data platform: orchestration,
        evals, tracing, agent governance, plus the existing DevOps estate.
        Fit 4, and the only Germany-based agent-shaped role the sweep
        found; packet tailored and built.

        Wellis, Rotterdam (DevOps/Platform Engineer) — first dedicated
        infrastructure hire at a healthtech scale-up, multi-cloud, manual
        provisioning, no production visibility. Fit 4 on shape, on-site in
        NL, so relocation cost decides it.

        Projektron, Berlin (Cloud Engineering) — 230 VMs, containerisation
        of the hosting estate, Nginx/HAProxy, Ansible/Puppet; German C1 is
        the gate.

        Closed as already on file, not re-scouted: DENKweit, eleQtron,
        wabcon, virtual7, Treatwell, Blocktech, Namespace (applied), Enact
        and gridscale all reappeared in the same-day feed.

        Route: Shipzero is brokered through join.com, so the employer ATS
        still has to be found before the packet leaves; the 2026-12-07
        hold governs the sends.
      '';
    };
    lib-pipe-elemat-lambdas = {
      title = "elemAt flip-lambdas in lib/*.nix want an `at` helper or direct calls";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-24";
      summary = "Code-review sweep of `|>` across lib/*.nix (~600 uses, 19 files): 18 `(xs: builtins.elemAt xs i)` flip-lambdas in 8 files — elemAt's (list, index) order fights the pipe while builtins.elem pipes natively. 7301202c landed the two exact twins (builtins.head, lib.last); 14 remain.";
      refs = {
        modules = [
          "lib/closure-graph.nix"
          "lib/gemini-portal.nix"
          "lib/knowledge-graph.nix"
          "lib/skills.nix"
          "lib/quotient-hash.nix"
          "lib/pkg-list.nix"
        ];
        tasks = ["checks:drv-equality"];
      };
      body = ''
        The sweep's finding is one asymmetry: `builtins.elem e list` is already
        pipe-shaped (`list |> builtins.elem t` works), while
        `builtins.elemAt list i` puts the list last, so every piped index grew
        an `(xs: builtins.elemAt xs i)` lambda whose only job is flipping args.

        Landed in 7301202c (drv-equality 30/30 identical): systemd-policy.nix
        took `builtins.head` for index 0 and a direct call for index 1;
        nix-files.nix took `lib.last` for `n - 1` and a direct call for `n - 2`.

        Remaining 14, by file: closure-graph.nix 6, gemini-portal.nix 4, and
        one each in knowledge-graph.nix, skills.nix, quotient-hash.nix,
        pkg-list.nix.

        Suggested shape for the next loop, not yet decided: a per-file
        `let at = i: xs: builtins.elemAt xs i;` where the count justifies it
        (closure-graph, gemini-portal), direct `builtins.elemAt xs i` calls
        for the singletons. A shared `at` helper is not worth a new lib file —
        these are per-domain imports, not a common prelude.

        Exit: no `(xs: elemAt xs` lambda remains in lib/, and
        `task checks:drv-equality` reports 30/30 identical.
      '';
    };
    lib-pipe-catattrs = {
      title = "map (e: e.field) projection pipes in lib/*.nix belong to builtins.catAttrs";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-elemat-lambdas"];
      summary = "Pass 5 of the lib |> sweep: 20 `map (e: e.f)` single-field projections in 7 files collapse to `builtins.catAttrs \"f\"` — one name instead of a lambda. Every site projects a schema-guaranteed field; drv-equality 30/30 identical.";
      refs = {
        modules = ["lib/matt-site.nix" "lib/pkg-list.nix" "lib/inventory.nix" "lib/delphi-site.nix" "lib/closure-graph.nix" "lib/aki-site.nix" "lib/agents-notes.nix"];
        tasks = ["checks:drv-equality"];
      };
      body = ''
        The pattern and its one subtlety: `xs |> map (e: e.f)` throws when a
        record lacks `f`; `builtins.catAttrs "f"` skips it — so the rewrite is
        for schema-guaranteed fields only (every site here is). The other
        edge: catAttrs carries a present null, so pkg-list keeps its
        `r.value != null` filter ahead of the projection.

        Sites: matt-site 10 (cvFiles name x4, corpus/json work name,
        untranslated in a throw, resumeProjects + invented, contacts href),
        pkg-list 2, inventory 2 (services name + port), delphi-site cardGrid
        group, closure-graph sub (set one line up), aki-site 2,
        agents-notes id x2.

        Gate: drv-equality 30/30 identical, .#sites.matt-site resolves to the
        same store path. Race incident 5 in passing: the staged index was
        consumed by a sibling `git commit` mid-hook (HEAD lock failed), so
        the diff rode to origin inside their 55a7f111 — content verified
        intact (catAttrs counts match), attribution theirs.
      '';
    };
    lib-pipe-count-findfirst = {
      title = "Residual lib |> classes: filter |> length to lib.count, filter |> head to lib.findFirst";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-catattrs"];
      summary = "Pass 6 of the lib |> sweep: the residual classes. `xs |> filter p |> length` collapses to `lib.count p` (docs.nix aliasCount, inventory.nix count); `xs |> filter p |> head` becomes `lib.findFirst p (throw \"named\")` (matt-site contactHref, quotient-hash fibIndex) — same hit semantics, named error replaces list index out of bounds.";
      refs = {
        modules = ["lib/docs.nix" "lib/inventory.nix" "lib/matt-site.nix" "lib/quotient-hash.nix"];
        tasks = ["checks:drv-equality" "checks:quotient-hash" "checks:host"];
      };
      body = ''
        The sweep is down to residuals: 776 pipe sites in 20 files, and the
        remaining classes are two sites each. `lib.count` is `length (filter p
        xs)` verbatim — zero semantic risk. `lib.findFirst` is `head (filter p
        xs)` when a match exists and a lazy default otherwise: passing a `throw`
        keeps the fail-on-miss contract but names it, which is strictly better
        than head's unhelpful index error.
        Not rewritten on purpose: `split |> head` (first segment of a split is
        a different idiom), `filterAttrs |> attrNames` (already the canonical
        spelling), and `map |> unique` (unique preserves order; the attrNames
        trick would sort). The loop is effectively dry — further passes would be
        renames, not refinements.
        Gate: checks:quotient-hash green (fibIndex exercised end-to-end), matt
        site drv resolves, inventory.derived evals, drv-equality identical.
      '';
    };
    lib-pipe-count-findfirst-flake = {
      title = "Residual lib.count / lib.findFirst in flake/*.nix; modules/ audited, one site skipped by design";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-count-findfirst"];
      summary = "Pass 7: the residual classes extended past lib/. Eight `filter |> length` sites in flake/checks.nix, outputs.nix, policies.nix collapse to `lib.count`; policies.nix sops-meta `suffixHits`-then-head folds into `lib.findFirst ... null`. modules/ was audited — gravatar-profile is an arg-free data file, so giving it lib for one findFirst is signature change, not refinement.";
      refs = {
        modules = ["flake/checks.nix" "flake/outputs.nix" "flake/policies.nix" "modules/config/gravatar-profile.nix"];
        tasks = ["checks:quick" "checks:host"];
      };
      body = ''
        Same classes as pass 6, one directory up. All eight count sites are the
        literal composition; the findFirst site (unencrypted_suffix probe in
        sopsYaml) drops the plural `suffixHits` binding that pretended to care
        about a list when only the first matters.
        Audited and refused: epistemics `permitted |> head` is sort-then-head
        with a second consumer, not the class; policies `sibling |> head` feeds
        +1 arithmetic on the hit, which breaks the fold; gravatar-profile's
        manual found-then-head is the class but the file takes no args — `lib`
        would mean a signature change plus a call-site edit in himalaya for a
        one-line gain. Not warranted.
        Incidental drift fixed in-tree: the sibling's 72335824 added
        scripts/task/appflow-send.sh at 137 lines with no script-budget record;
        the entry is recorded (its own small commit) or checks:quick stays red.
        Gate: checks:quick green end-to-end, checks:host frieren rc=0,
        .#knowledgeGraph.evidence evals through the new count.
      '';
    };
    lib-pipe-cmssep-replicate = {
      title = "Residual lib |> classes: map |> concatStringsSep to concatMapStringsSep, genList-pad to strings.replicate";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-count-findfirst-flake"];
      summary = "Pass 8: two more residual classes. `xs |> map f |> concatStringsSep sep` folds to `lib.concatMapStringsSep sep f` (closure-graph rows, agents-notes refLine+kinds join, policies detail x2). `n |> genList (_: c) |> concatStrings` is `lib.strings.replicate n c` — not `lib.replicate`, which is the LIST version and returns [c c ...].";
      refs = {
        modules = ["lib/closure-graph.nix" "lib/agents-notes.nix" "lib/delphi-site.nix" "lib/gemini-portal.nix" "flake/policies.nix"];
        tasks = ["checks:drv-equality" "checks:policies"];
      };
      body = ''
        The replicate class had a namespace trap worth recording: `lib.replicate`
        is `lists.replicate` (n: a: [a]) — `lib.replicate 3 "x"` yields
        ["x","x","x"], and a consumer concatenating it gets a type error, not a
        pad. The string version is `lib.strings.replicate :: int -> string ->
        string`, and since its first arg is n, the count cannot pipe in on the
        left — write `" " |> lib.strings.replicate n`, piping the string into
        the second arg. First draft wrote `lib.replicate`; eval caught it.
        concatMapStringsSep is the literal expansion of map-then-join, so every
        site is identity-safe; the agents-notes kinds join already used the
        combinator one binding up (the in-file idiom).
        Gate: drv-equality 30/30 identical, .#checks.policies builds,
        fleet-docs-site resolves, all five files parse.
      '';
    };
    lib-pipe-loop-exhausted = {
      title = "The lib |> loop is audited to exhaustion; one concatMap fold, and the folds that do not exist";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-cmssep-replicate"];
      summary = "Pass 9: `concatLists (map f xs)` in nix-registry folds to `builtins.concatMap` (one site; the file's other leg already spelled it). The bigger finding is the audit's floor: `lib.filterMap` does not exist in nixpkgs — `map f |> filter (x != null)` IS the canonical spelling, and five candidate sites were reverted when eval proved it.";
      refs = {
        modules = ["flake/nix-registry.nix" "flake/checks.nix" "lib/nix-files.nix" "flake/policies.nix"];
        tasks = ["checks:nix-registry" "checks:policies"];
      };
      body = ''
        What was tried and refused, recorded so the next pass does not retry:
        `lib.filterMap` is a phantom — not in `lib`, not in `lib.lists`, on this
        pin; `map f |> filter (!= null)` stays. `lib.genAttrs` cannot replace
        `map (nameValuePair n v) |> listToAttrs` when the value needs the whole
        element — genAttrs's fn receives the name only. `foldl' (a: b: a + e.f)
        0` is the canonical field-sum; nixpkgs ships no `lib.sum`. `sort |>
        reverse` is worse than a flipped comparator but no site exists. The
        netbook `genList` maps a non-constant lambda — index-grouping, not the
        pad class.
        One fold did land: nix-registry's `concatLists (map importsOfPath
        paths)` to `builtins.concatMap`, matching the concatMap already used
        for the same file's dangling check.
        Gate: nix-registry and registry-schema drvs build, all edits parse.
      '';
    };
    lib-pipe-catattrs-inline = {
      title = "Pipe sweep pass 10: the inline-lambda spelling of catAttrs, six sites";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-loop-exhausted"];
      summary = "The catAttrs pass missed a second spelling: `xs |> map (e: e.attr)` is the same fold written as an inline lambda, and six sites survived the earlier sweep — checks.nix (nodeTypes/edgeTypes), policies.nix (citedIds), agents-notes.nix (evidence), epistemics.nix (unsettleable/persistable), service-portal.nix (shown ports). All convert to `builtins.catAttrs`, the in-tree idiom.";
      refs = {
        modules = ["flake/checks.nix" "flake/policies.nix" "flake/epistemics.nix" "lib/agents-notes.nix" "modules/services/service-portal.nix"];
        tasks = ["checks:host" "checks:drv-equality"];
      };
      body = ''
        `builtins.catAttrs "a" xs` is `builtins.map (v: v.a) xs` verbatim —
        byte-identical derivations. The earlier sweep grepped for
        `builtins.catAttrs`-adjacent shapes and `map` feeding `elemAt`; the
        `map (x: x.attr)` lambda feeding `unique`/`all` was a second spelling
        of the same class. `catAttrs` also beats the lambda on the miss:
        an attrless element errors naming the attr, same as the lambda, but
        the combinator name says the intent.
        Deliberately not folded: `filter |> map` in epistemics stays two
        steps (catAttrs takes the tail, the filter stays the gate);
        `nameRefsOf |> filter |> map` in nix-files needs the filter before
        the projection.
        Gates: ontology drv builds (the checks.nix pair evals), epistemics
        unsettleable/persistable and agentsNotes.issues all [], drv-equality
        30/30 identical, checks:host frieren rc=0 — service-portal is
        imported there and by delphi.
      '';
    };
    lib-pipe-mapattrstolist-attrvalues = {
      title = "Pipe sweep pass 11: attrNames-then-lookup is mapAttrsToList, genAttrs-to-list is attrValues";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-catattrs-inline"];
      summary = "Two lookup-idiom folds the earlier passes missed: epistemics `preferredRoute` ranked `attrNames |> map (n: routes.\${n} // {name = n;})` — `lib.mapAttrsToList` is that loop verbatim. agents-notes `entryList` mapped noteIds back into the genAttrs it had just built — `builtins.attrValues` is exact because noteIds is attrNames-sorted and `ordered` re-sorts anyway.";
      refs = {
        modules = ["flake/epistemics.nix" "lib/agents-notes.nix"];
        tasks = ["checks:drv-equality"];
      };
      body = ''
        The class is `attrNames |> map (n: set.''${n} ...)` — walking a set's
        names to look each value back up. `mapAttrsToList` carries name and
        value together. Refused sites: `map (m: self.modules.''${m})` in
        noDE/demo/hm-inventory-role is a lookup into a DIFFERENT set keyed by
        a name list — attrValues cannot express it. `attrNames |> map
        (id: "data/.../''${id}.json")` in aki-site projects the NAME, not the
        value. `cache-policy` urlOf/keysOf map names into registry fields —
        same non-class.
        The attrValues fold only holds because noteIds = attrNames raw
        (sorted) and entries = genAttrs noteIds, so the value order matches
        the name order; `ordered` re-sorts on id immediately after, so even
        that constraint is belt-and-braces.
        Gates: epistemics spend/table eval through preferredRoute (cost/
        metered/why rows intact), agentsNotes.counts total 269 through
        attrValues, drv-equality 30/30 identical.
      '';
    };
    lib-pipe-sorton = {
      title = "Pipe sweep pass 12: ascending single-attr sort comparators are sortOn, five sites";
      kind = "open";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-mapattrstolist-attrvalues"];
      summary = "`lib.sort (a: b: a.f < b.f)` is `lib.sortOn (x: x.f)` — verified the combinator exists on the pin first (the filterMap lesson). Five sites: agents-notes ordered (id), epistemics permitted (key), service-portal inGroup (title), delphi-site tailnetCards (title), aki-site note table (id). Descending `>` sites and complex comparators stay — sortOn is ascending-only.";
      refs = {
        modules = ["lib/agents-notes.nix" "flake/epistemics.nix" "modules/services/service-portal.nix" "lib/delphi-site.nix" "lib/aki-site.nix"];
        tasks = ["checks:drv-equality" "checks:host"];
      };
      body = ''
        `lib.sortOn f` decorates, sorts, undecorates — O(n) key calls instead
        of O(n log n), and the comparator name now says what the sort is
        FOR. Refused sites: every `a.f > b.f` comparator (matt-site sortKey/
        start/projectRank, aki-site bytes, nix-comments lines) — no
        descending sortOn exists and `sort |> reverse` is a documented
        non-class; `a < b` on scalars (docs.nix names, service-exposure)
        has nothing to project; epistemics's ranked sort carries a let-bound
        tier computation — real comparator logic, not a projection.
        Gates: fleet-docs-site builds (aki-site renders every note row
        through sortOn id), drv-equality 30/30 identical, checks:host
        frieren rc=0 (service-portal), epistemics.table verdict rows
        intact, counts.total 270, issues [].
      '';
    };
    lib-pipe-sweep-closed = {
      title = "The |> refactor sweep is closed: every foldable class is folded or a documented non-class";
      kind = "decision";
      status = "DELIVERED";
      priority = "P5";
      date = "2026-11-25";
      from = ["lib-pipe-sorton"];
      summary = "Thirteen passes audited lib/, flake/, modules/ and hosts/: catAttrs both spellings, count, findFirst, concatMapStringsSep, strings.replicate, concatMap, mapAttrsToList, attrValues, sortOn. What remains is either a documented non-class or a combinator nixpkgs does not ship (filterMap, lib.sum, a descending sortOn). hosts/ has zero sort calls; modules/ one scalar identity. Loop stops here.";
      refs = {
        modules = ["lib/agents-notes.nix" "flake/epistemics.nix" "modules/profiles/service-exposure.nix" "modules/services/service-portal.nix"];
        tasks = ["checks:drv-equality" "checks:quick" "checks:nix:style"];
      };
      body = ''
        The audit floor, so no future pass retries it: `map f |> filter (x !=
        null)` is canonical (no `lib.filterMap` on the pin); `map
        (nameValuePair n v) |> listToAttrs` cannot be genAttrs (fn gets the
        name only); `foldl'` is the canonical field-sum (no `lib.sum`);
        `split |> head` is a different idiom; descending `>` comparators have
        no sortOn; `a < b` on scalars has nothing to project; `filter |>
        map` with the filter as gate stays two steps.
        The lone modules/ comparator — service-exposure `portsOf` sorting
        port ints `a < b` — is scalar identity, refused.
        Evidence trail: drv-equality 30/30 identical on every refactor
        commit (314c6e95, f7ebdb87+0678e1e5, 3f214204, c3986055,
        7ad46d58, 83df611b, 8350ac74); checks:host frieren rc=0 where a
        module was touched; checks:quick green on HEAD. `nix flake check`
        remains memory-gated off on this host — the equivalents stand.
        Next value in this lane is a different class: toString chains,
        mkIf/optionalAttrs idioms, or non-pipe patterns.
      '';
    };
    apps-lane-has-no-send-task = {
      title = "The application lane can draft but cannot send, so escalate rather than sweep";
      kind = "open";
      status = "BLOCKED";
      priority = "P2";
      date = "2026-11-24";
      summary = "Decided 2026-11-24: escalate. Flink and Pentland Firth packets carry CV plus letter, and Pentland has an addressed draft to jobs@pentlandfirth.com in Drafts. Nothing can leave: the task plane has no send verb, and Flink's posting is a LinkedIn form with no published mailbox.";
      links = ["job-scout-next-sweep-freebuff"];
      refs = {
        modules = [
          "modules/plugins/appflow/sync.py"
          "scripts/task/appflow-sync.sh"
          "taskfiles/apps.yml"
        ];
        tasks = ["agents:apps:draft" "agents:apps:drafts" "apps:gate:packet"];
        docs = ["docs/email-archive.md" ".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The 02:54 sweep's four leads reduced to two applicable ones. Flink
        (Platform Eng, Berlin, 14/32 highlights) and Pentland Firth (Sr Cloud
        Platform, Munich, 9/32) both have packet CVs and tailored letters;
        Pentland also has an addressed draft held in Drafts. Maesn was closed as
        a backend requisition and Atlas Titan was do-not-packet on German C1, so
        re-tailoring them is not a move.

        Why not (b): both packets are complete and their letters name their
        gaps, so more tailoring is polish, not progress. Why not (a): a re-sweep
        adds leads that reach the same wall — the missing piece is a send step,
        not supply. The block is structural: the task plane has no sending task,
        only `agents:apps:draft`/`drafts` and mail triage verbs, and the draft
        path prints `to (no recipient)` when given no address. Flink publishes
        no address (`jobs.goflink.com` is a dead short-link domain, `flink.com`
        challenge-blocks), so only its form can carry an application.

        Escalated in xs: nixconfig:job-scout-fresh, blocked,
        03hamwdctdtyjszty0luwo507.

        Exit: a task that transmits a draft, with a gate proving it, or the
        person sends the Pentland draft and submits Flink through its form; then
        this note is DELIVERED with both tracker rows showing `applied`.
      '';
    };
    job-scout-fresh-packets-public = {
      title = "The two tailored packets are public and ranked; the EU careers-page gap is the open lead";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Flink (rank 1, 14/32) and Pentland Firth (rank 2, 9/32) publish as redacted PDFs under assets/files/packets/ with street address and phone stripped; the EU vendors that post only on their own careers pages are the next sweep's target, because only ATS boards were probed today.";
      links = ["job-scout-next-sweep-freebuff" "apps-lane-has-no-send-task"];
      refs = {
        modules = ["modules/plugins/appflow/packet.nix"];
        tasks = ["apps:gate:packet"];
        docs = [".agents/skills/apps/SKILL.md" ".agents/skills/neocities/SKILL.md"];
      };
      body = ''
        Order is the fit count, not the sweep order: Flink 14/32 of the JD's
        highlights and 4/10 projects, Pentland Firth 9/32 and 4/10. Both were
        re-rendered from the same JD and letter with only the contact block
        changed — city and email kept, street and phone removed — because the
        public surface matches `cv.pdf`. The build re-syncs `pii.json` into any
        fresh config, so a public render needs that file pre-seeded with
        `{"basics":{}}` or the address comes back.

        Public renders: CV 2 pages, letter 1 page each, zero hits for
        `Burgerhof|79261|+49 1733` in `pdftotext`. The private packets keep the
        address and were relinked to their original artifacts (`1v8vjckp…`,
        `xixyyzf5…`) after the public build took the submission symlinks.

        Gap: only ATS APIs were probed. LINBIT, B1 Systems, Univention,
        Open-Xchange and Proxmox post on their own careers pages, where an empty
        Greenhouse or Ashby feed proves nothing. A genuinely new lead is most
        likely there.

        Exit: `apps:scout` records one of those pages as a lead row after the
        2026-12-07 hold, or each is recorded as having no live req.
      '';
    };
    job-scout-sweep-2026-11-25t = {
      title = "Sweep 25t: six leads off Stepstone, and the boards that answer nothing";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Stepstone's three lanes at two pages gave 143 cards, 91 in-family, 25 at employers the ledger does not hold and nine detail reads; six filed on scout-2026-11-25t, one parked inside the hold. Arbeitnow is exhausted at six pages, germantechjobs carries no items, berlinstartupjobs sits behind Cloudflare, the Arbeitsagentur API answers empty.";
      links = ["job-scout-fresh-packets-public" "apps-lane-has-no-send-task"];
      refs = {
        modules = ["scripts/task/apps-scout.sh" "taskfiles/apps.yml"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:scout:parked"];
      };
      body = ''
        The 25t read took Stepstone's platform, site-reliability and
        infrastructure lanes at two pages each: 143 cards after dedupe by ad URL,
        91 in the devops family, 25 after the employer-token dedupe against the
        1,025 names already held, and nine detail pages read before a verdict.
        Filed six on `scout-2026-11-25t`, all at stage `lead`: Luerssen Werft
        (DevOps/Platform, Lemwerder, 4), novomind (Platform, Hamburg, 4), SUSS
        MicroTec (Infrastructure & Platform, Garching, 4 — its ad carries Nix),
        eddyson (SRE/DevOps, Goettingen, 3), PPI (Senior Platform, GitLab and
        Artifactory, 3) and SCHIFFL group (Cloud Infrastructure, Frankfurt, 3).
        Each carries its ad's validThrough and a next action gated on 2026-12-07.

        Parked, not filed: freenet DLS Cloud/Platform-Engineer DataOps, Hamburg,
        validThrough 2026-11-26 — one day out and inside the hold. Liebherr-Aerospace
        (2026-12-05) and Hilti (2027-01-20) were read and left for the recheck;
        Amadeus Fire and Bertrandt were skipped as agencies.

        What the boards returned: arbeitnow's six pages held nine in-family German
        cards, none new; germantechjobs answers 301 on the bare host and its followed
        feed carries no items; berlinstartupjobs returns Cloudflare's challenge; the
        Arbeitsagentur API answers with no result envelope; Kubermatic is sales and
        GTM only; 1KOMMA5GRAD has one Edge & Cloud role; DeliveryHero has no family
        match; Himalayas page one is US only. Stepstone carried the yield, so the
        card parser matters more than the aggregators.

        Exit: each of the six is tailed into `prep` after 2026-12-07 with a packet,
        or dropped with the row saying why; freenet DLS is rechecked on 2026-11-26
        and filed only if reposted.
      '';
    };
    job-scout-sweep-2026-11-25u = {
      title = "Sweep 25u: ten leads, five expiries inside the hold, and an expiry only on detail pages";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Cycle 25u read devops pages 1-3 and the other three lanes at pages 3-4: 216 cards, 165 in-family, 86 at employers the ledger does not hold, 41 after construction and agency trims, 16 detail reads. Ten filed on scout-2026-11-25u, five parked on an expiry inside the hold, one dropped for a 2029 validThrough.";
      links = ["job-scout-sweep-2026-11-25t" "job-scout-fresh-packets-public"];
      refs = {
        modules = ["scripts/task/apps-scout.sh" "taskfiles/apps.yml"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:scout:parked"];
      };
      body = ''
        Read: devops pages 1-3, then platform, site-reliability and infrastructure at
        pages 3-4. Nine pages, 216 unique cards, 165 in-family, 86 employers absent
        from the 1,050-name ledger, 41 after the construction and agency trim —
        Stepstone's infrastructure lane is mostly Bauingenieur work — and 16 detail
        pages read before a verdict.

        Filed ten on `scout-2026-11-25u`, all at stage `lead`: Ascent Digital
        (München/Graz, 4), Bijou Brigitte (Hamburg, 4), EOS Technology (Hamburg
        team lead, 4), LivEye (Föhren, 4), Paychex Europe (Rostock, 4), TÜV NORD
        SERVICE (Essen, 4), S-Management/DSV (Stuttgart, 4), POLIPOL (Diepenau, 3),
        moysies & partners (Hamburg, 3) and Diehl Aerospace (Frankfurt, 3).

        Parked on an expiry inside the hold: Anexia netcup (2026-12-01), Compliance
        Solutions (12-05), MRH TROWE (11-28), GEMA (11-29), TUM Campus Heilbronn
        (12-04). Hotzone was dropped — its card claims validThrough 2029, a feed
        artefact rather than a live ad.

        Held already: BMW Group, BWI, Bank11, Deutsche Telekom, Diehl Defence, and
        DHBW under its acronym, which is why exact-name dedupe needs the house token.

        This cycle put validThrough only on detail pages: all 216 listing cards came
        back with the field empty, so an expiry read from the card would have been a guess.

        Exit: each of the ten is tailed into `prep` after 2026-12-07 with a tailored
        packet, or dropped with the row saying why; the five parked are rechecked
        after their dates and filed only if reposted.
      '';
    };
    job-scout-sweep-2026-11-25q-supplement-2 = {
      title = "Sweep 25q re-read: Personio answers 200, Airbus deduped, four fit-3 rows";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Same-day re-read of the six 25q boards once Personio answered 200: 88 in-family rows against 1,081 held names, 32 unheld and almost all Mittelstand. Airbus deduped against the held house. Four fit-3 rows filed, four packets built, no newcomer clears fit 4.";
      links = ["job-scout-sweep-2026-11-25q-supplement" "job-scout-sweep-2026-11-25u"];
      refs = {
        modules = ["scripts/task/apps-scout.sh" "scripts/task/appflow-packet.sh" "taskfiles/apps.yml"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:scout:parked"];
      };
      body = ''
        Boards, as they answered: gtj 586 items, WWR 79, RemoteOK 101, Ashby 9
        Kubermatic and 56 Camunda, BSJ 12, and Personio 1KOMMA5GRAD 200 with 2.4 MB
        of XML — the 401 from the earlier 25q read did not repeat.

        88 in-family rows against 1,081 held names left 32 unheld, and almost all of
        them were Mittelstand: Mitarbeiter IT-Infrastruktur, Systemadministrator,
        Citrix, Netzwerk. Nine had a platform or cloud title; the best of those, E
        Airbus Defence and Space IT Operations & Cloud Platform Specialist (70-100k),
        is the house the ledger already holds as Airbus Deutschland GmbH, so
        house-token dedupe dropped it instead of opening a second thread.

        Filed on scout-2026-11-25q, all fit 3: AKDB Senior IT-Systemarchitekt
        Infrastruktur & Cloud (45-74k, Munich), Sunrise Medical IT Infrastructure
        Specialist (65-75k, Malsch), SimonsVoss IT Infrastructure Operations Lead
        (39-76k) and Seghorn Teamleitung IT-Infrastruktur (60-75k, Hamburg).

        Why 3 and not 4: three are Microsoft-estate operations roles where the CV's
        centre is Linux, storage and declarative provisioning, and two ask for
        leadership held so far by direction rather than by title. No row clears 4.

        Letters ran 301-318 words, each in the ad's own vocabulary and each naming
        its gaps in the third paragraph. Only Sunrise publishes an application
        address (candidate@sunrisemedical.de); the other three are portal-only, so
        their next action is a submission, not a send.

        Exit: send Sunrise after 2026-12-07, portal-submit the other three on the
        same date, and re-read gtj only for DevOps- or SRE-titled ads.
      '';
    };
    job-scout-sweep-2026-11-25q-supplement = {
      title = "Sweep 25q supplement: four packets from six boards, and gtj is not a platform board";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "The six-board pass under cycle id 25q read germantechjobs, WWR, RemoteOK, two Ashby boards and BSJ: 842 rows, 147 in-family, 89 not held, four filed and four packets built. gtj is Mittelstand systemadministration, the remote boards were already held, Personio answered 401 and Ashby had no in-family seat.";
      links = ["job-scout-sweep-2026-11-25u" "job-scout-fresh-packets-public"];
      refs = {
        modules = ["scripts/task/apps-scout.sh" "scripts/task/appflow-packet.sh" "taskfiles/apps.yml"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:scout:parked"];
      };
      body = ''
        Boards, as they answered: germantechjobs 586 feed items, weworkremotely 79,
        RemoteOK 101, Ashby 65 across Kubermatic and Camunda, BSJ 12, and Personio
        1KOMMA5GRAD 401 — no XML, so nothing to read there this pass.

        Filtering: 842 rows, 147 in-family after dropping sales, Ausbildung and
        junior variants and any ad whose location is United States only, 89 at
        employers the 1,061-name ledger does not hold, six of those with a genuinely
        platform-shaped title. Four were filed on `scout-2026-11-25q` and four
        packets built: GWDG Storage Expert (Göttingen, fit 4), RockQ ML Platform
        Engineer (3), WWK Lead System Engineer (Munich, 2) and alphacaps Microsoft
        Cloud & Infrastructure (Augustdorf, 2).

        What the boards actually contain: gtj is Mittelstand IT-Systemadministration,
        not platform engineering — of 586 items only six were DevOps, SRE or
        platform-shaped, and its job pages are JavaScript shells, so the ad text has
        to come from the RSS description rather than the page. WWR and RemoteOK
        carried real infra roles, but nearly all at employers already in the ledger:
        Grafana Labs, JFrog, EPAM, Dropbox, Prove, Smartsheet, Upsun, Knack, Wrike.
        Kubermatic's Ashby board is nine sales and GTM seats; Camunda's 56 had no
        in-family opening. BSJ's twelve items were ML, backend and product.

        Each packet carries its own letter and JD: the builder still defaults to one
        `$CONFIG/letter.json` and silently builds a CV-only packet otherwise, so both
        paths are passed explicitly. Selected highlights ran 11/36, 11/36, 9/36 and
        10/36.

        Exit: send the four after 2026-12-07, or drop the two fit-2 rows once the F5
        and Intune gaps are judged; re-read gtj only for DevOps-titled ads.
      '';
    };
    devin-lane-handoff-2026-11-24 = {
      title = "Devin lane: image-daily pool helpers landed; two uncommitted gate files; jev routes idle panes";
      kind = "handoff";
      status = "DELIVERED";
      date = "2026-11-24";
      summary = "pool.go carries the read-only pool verbs (remaining/share/pending), shell rewired to the CLI, budget ledger shrunk, gates green. Uncommitted: cv-blog-check.sh (ceiling entry moves in its owner's diff) and hermes-persona config.yaml (fallback chain + sail goal_judge + retries 9). Idle-pane routing: jev-decide --provider typesafe; goal_judge is out of tmux-pane-steward.";
      refs = {
        modules = [
          "tools/os/internal/image/pool.go"
          "tools/os/internal/image/briefs.go"
          "scripts/task/cv-blog-check.sh"
          "modules/user/ai/hermes-persona/config.yaml"
          "scripts/task/infron-check.sh"
        ];
        tasks = ["checks:quick" "checks:host" "checks:image-daily" "checks:drv-equality" "checks:infron"];
        docs = [".agents/skills/jevdecide/SKILL.md"];
      };
      body = ''
        image-daily port: the read-only pool helpers (remaining, share,
        pending) live in pool.go, the shell calls the CLI, the budget ledger
        shrank with each port. Green: checks:quick, checks:host frieren,
        checks:image-daily, drv-equality 30/30. Engine glue still in shell:
        build_index's ffprobe shape-cache loop, deploy_frontend (wrangler),
        launch_round (systemd-run), resolve_plate, banner_crop,
        dimensions/landscape — mostly external-process wrappers. The natural
        next slice is build_index's shape cache: data, measurable.

        Uncommitted: scripts/task/cv-blog-check.sh (CV/publish consistency
        gate, grew 158->172 — its owner bumps the ceiling entry in the same
        diff). modules/user/ai/hermes-persona/config.yaml (codebuff's file:
        fallback-chain edits + goal_judge pinned to the sail/deepseek lane +
        api_max_retries 9 for 9 lanes). Whoever commits it takes the bump in
        the same diff. SAIL_API_KEY still must be added to sops
        ai-services-shared-env — it is in neither the blob nor ~/.hermes/.env.

        Routing: idle-pane direction decisions route through
        `jev-decide decide --provider typesafe`; goal_judge is removed from
        tmux-pane-steward routing.
      '';
    };
    devin-lane-appflow-write-auth = {
      title = "Appflow write routes: bearer gate landed and verified on delphi's live vhost";
      kind = "open";
      status = "CLOSED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Write routes (7571daca) are bearer-gated and verified live on delphi: unauth and wrong-key POST 403 on both routes, the right bearer passes through to the upstream, reads stay open (application-pipeline 200).";
      refs = {
        hosts = ["delphi"];
        modules = ["modules/services/appflow-board.nix" "hosts/delphi/configuration.nix"];
        tasks = ["checks:host"];
        docs = ["docs/appflow-board.md"];
      };
      body = ''
        The board's nginx has no auth anywhere; the write routes widen tailnet
        read exposure into arbitrary overwrite of status/stage/next_action on
        any application record. The intended gate (from the code-review
        comments on the routes): one shared bearer key in sops
        (ai-services-shared-env or a dedicated secret), wired to nginx via
        auth_request or a `map $http_authorization` gate applied only to the
        two write locations — reads stay open as they are today.

        Landed: `appflow-board-bearer` in modules/secrets.yaml, the map via
        `sops.templates."appflow-board-write-auth.conf"` included from
        `services.nginx.appendHttpConfig`, and `if ($appflow_write_ok = 0) {
        return 403; }` on the two write locations. The key never enters the
        store. Verified on a replica nginx: unauth POST -> 403 on both routes,
        `Bearer <key>` POST -> 200, wrong key -> 403, unauth GET read -> 200.

        Verified live 2026-11-25 against
        https://delphi.cloudforest-kardashev.ts.net:8463 after the rebuild:
        unauth POST 403 on both write routes, wrong key 403 on both,
        `Bearer <key>` passes through — the upstream's own answers come
        back (404 on a dead-id update and a param-less upsert; a real 200
        needs a real row). Unauth GET read open: application-pipeline 200.
        Side observation, unrelated to this gate: /api/applications
        answers upstream 404 while application-pipeline 200s — the
        archive's empty-result answer, pre-existing.

        Exit: after the delphi rebuild, repeat the curl pair against
        https://delphi.cloudforest-kardashev.ts.net:8463 and see the same
        403/200 split — met 2026-11-25.
      '';
    };
    devin-lane-image-daily-go-port = {
      title = "image-daily Go port: every external-process boundary lives in tools/os; shell keeps dispatch and env glue";
      kind = "open";
      status = "CLOSED";
      priority = "P2";
      date = "2026-11-25";
      from = ["one-os-cli" "devin-lane-handoff-2026-11-24"];
      summary = "~30 verbs in tools/os/internal/image behind .#cli.image.daily; 28 unit tests plus a 9-assert fixture pin every gate arm. Closed with image-gen's cpg auth dance, upload_bank, batch and detach as gen/gen-batch/gen-detach; cloudinary.sh deleted — the family's last curl. stash@{0} parked. Renaming unjudgedStreak/shrinkGuard/modelProvider fails the gate by name.";
      refs = {
        modules = ["tools/os/internal/image/main.go" "tools/os/internal/image/main_test.go" "tools/os/internal/image/ship.go" "tools/os/internal/image/cloudinary.go" "tools/os/internal/image/imagegen.go" "tools/os/internal/image/pool.go" "tools/os/internal/image/plates.go" "tools/os/internal/image/briefs.go" "scripts/task/image-daily.sh" "scripts/task/image-daily-lib.sh" "scripts/task/image-daily-gate.sh" "scripts/task/image-ship.sh" "scripts/task/image-gen.sh" "flake/cli.nix"];
        tasks = ["checks:image-daily" "checks:images:publish:test" "checks:images" "checks:images:ship:test" "images:gate"];
      };
      body = ''
        The port's end state (verified 2026-11-25): the spend, judge,
        publish and front-end machinery lives in tools/os/internal/image
        behind .#cli.image.daily — a symlink onto the `os` umbrella whose
        argv[0] dispatch selects the image domain — and image-daily-lib.sh
        resolves the binary via IMAGE_DAILY_BIN, PATH, or a one-off
        `nix build`. Shell keeps dispatch, env resolution and shims only;
        cloudinary.sh is deleted with its budget line, the last curl.

        Coverage: the publish fixture is 9 assertions — every gate arm
        proven on 470c9034^ and strip mutations; 28 unit tests pin the
        urls.tsv projection, skipReason's burn vocabulary, the ffprobe
        cache loop and its missing-probe die, deploy_frontend's PAGES
        gate, both systemd-run vectors (ship-detach, gen-detach), the
        served poll, cloudinary.go's wire contract against httptest, and
        genRetry's 401-refresh/429-backoff table plus the gen_once merge
        contract under a stub cpg (bank=false keeps the session URL).

        Ported last: image-gen.sh's cpg auth dance and upload_bank —
        verbs gen, gen-batch, gen-detach; image-gen.sh is a shim over the
        lib. The bank id derivation (src-relative vs wall/<day>/basename)
        moved with it.

        Loose thread: stash@{0} "On main: pre-existing changes" is parked
        from an aborted concurrent-lane rebase — not mine to pop or drop.

        Maintenance: the gate greps symbol NAMES — `modelProvider` +
        `GEMINI_API_KEY` (gen.go), `unjudgedStreak` (plates.go),
        `shrinkGuard` (briefs.go). A rename fails the gate with a
        misleading message; keep the names or update the greps in the
        same diff.
      '';
    };
    devin-lane-refactoring-2026-11-25 = {
      title = "Devin lane close-out: image-daily port + comment audit CLOSED; appflow re-verify CLOSED (bare-route 404 was the param contract, not a missing deployment)";
      kind = "open";
      status = "CLOSED";
      priority = "P3";
      date = "2026-11-25";
      from = ["devin-lane-image-daily-go-port" "devin-lane-appflow-write-auth" "nix-comment-audit" "devin-lane-handoff-2026-11-24"];
      summary = "Lane record: image-daily Go port CLOSED (engine.sh retired, gates green end-to-end) and nix-comment-audit CLOSED (every Story:/Trap:/Fact: pointer resolves; tail sweep clean). Appflow tail CLOSED 2026-11-26: all five board read routes answer 200 on delphi when called with their params — the bare-GET 404 was NpgsqlRest refusing an unparametrized endpoint, not a missing .sql in the deployed tree.";
      refs = {
        hosts = ["delphi" "frieren" "netbook"];
        modules = ["tools/os/internal/image/main.go" "modules/services/appflow-board.nix" "lib/nix-comments.nix" "hosts/netbook/configuration.nix"];
        tasks = ["checks:image-daily" "checks:nix:comments" "checks:policies" "ops:docs:budget"];
        docs = ["docs/delphi-runtime.md" ".agents/deploy/hosts/netbook.md" "docs/appflow-board.md"];
      };
      body = ''
        Lane close-out 2026-11-25 (devin, nixconfig refactoring): both threads CLOSED.

        image-daily Go port — CLOSED. Every external-process boundary lives in
        tools/os/internal/image behind .#cli.image.daily; engine.sh retired with
        its budget line. Green end-to-end: go build/vet/test, checks:image-daily,
        the 9-assert publish fixture, ship 4/4, images-check 771/771,
        checks:host frieren rc=0.

        nix-comment-audit — CLOSED. Every Story:/Trap:/Fact: pointer resolves;
        the tail sweep (netbook, outputs.nix, hermes-user) found one dangling
        cite, fixed at its doc home. Census: 7259 comment lines, 519 pointers,
        54/54 task cites; prose budget untouched.

        Appflow tail — CLOSED 2026-11-26 on the live host. The Nov-25 404 was a
        dirty-tree generation whose npgsqlrest lacked two committed .sql files
        (a487f3d4 asserts every proxied route has one). The *persistent* 404 was
        the param contract: NpgsqlRest answers "not found" for a parametrized
        endpoint called bare, so `/api/applications` 404s while `?lim=5` serves.
        All five read routes answer 200 with params; docs/appflow-board.md names
        the bare-route trap. Gates green twice: comments 54/54, policies, images
        772/772, hosts delphi+frieren+netbook, drv-equality 30/30.
      '';
    };
    shared-worktree-commit-race = {
      title = "One checkout, many lanes: git commit records the index, not the author's intent — rule adopted in HOME-PREAMBLE";
      kind = "open";
      status = "CLOSED";
      priority = "P3";
      date = "2026-11-25";
      from = ["devin-lane-refactoring-2026-11-25"];
      summary = "Three hits in one lane on the same day: a sibling's uncommitted note swept into an amend, a transient worktree deletion of 13 appflow .sql files nearly shipping a wrong diagnosis, and origin/main moving between commit and push. Proposed rule: one git worktree per agent lane, never add -A in a shared tree.";
      refs = {
        modules = ["AGENTS.nix" "scripts/task/xs-turn-post.sh"];
        tasks = ["agents:xs:list" "agents:xs:post"];
        docs = ["docs/agent-turns.md" "docs/agent-context/HOME-PREAMBLE.md"];
      };
      body = ''
        The mechanism is one sentence: `git commit` records the INDEX, not
        the author's intent, so in a shared checkout every lane's staged
        and unstaged state sits inside the blast radius. Three hits in one
        lane on 2026-11-25:

        1. `git add -A` before an amend swept the sibling's uncommitted
           `job-scout-sweep-2026-11-25j` note into my commit; they committed
           it themselves as 92c0f6dd — same content committed twice, once
           under the wrong message.
        2. A transient worktree deletion of 13 appflow .sql files (present
           in HEAD, absent from the tree) almost shipped a "missing
           endpoint" diagnosis; the live cause was the deployed tree's
           `endpointsDir`, not the repo.
        3. A sweep note landed mid-turn twice, moving origin/main between
           commit and push — every commit this lane made needed a rebase.

        The earlier cousin: a sibling `git commit` recorded my staged Go
        port under their message (content correct, attribution theirs).

        Adopted (same day, HOME-PREAMBLE §Agent turns): in a tree that is
        not exclusively yours, stage named paths only — never `add -A` or
        `commit -a` — treat `git stash` as stashing somebody else's work,
        and a lane with sustained repo work gets its own `git worktree
        add`. The incident count is xs itself: a shared-tree incident is a
        turn on `SUBJECT=<repo>:worktree-race`, so `xs:list` on that
        subject is the running count — zero at adoption.
      '';
    };
    fleet-hygiene-tailscale-creds-stale = {
      title = "Both stored tailscale credentials are dead — mint fresh auth material";
      date = "2026-11-24";
      kind = "open";
      priority = "P3";
      status = "OPEN";
      summary = "The sops tailscale material no longer joins a node: gokrazy.gok.tailscale_auth_key (modules/secrets.yaml) is a consumed single-use key (invalid key), and the TAILSCALE.CLIENT OAuth pair (apikeys.yaml) mints a token but lacks key-creation scope (calling actor does not have enough permissions).";
      body = ''
        Found 2026-11-24 while trying to join clanker (instabox) to the
        tailnet. Both stored creds fail:

        - `gokrazy_gok_tailscale_auth_key` → `invalid key: unable to
          validate API key`. Almost certainly a single-use key already
          consumed by the gokrazy image bring-up.
        - `TAILSCALE.CLIENT.{ID,SECRET}` (apikeys.yaml) → OAuth token
          mints and reads `/devices` fine (33 devices; tags in use:
          `tag:extagent`, `tag:experimental`), but `POST /tailnet/-/keys`
          is denied. The OAuth client's scopes need `devices:write`.

        A third pair, `tailscale.client.{id,secret}` in
        modules/secrets.yaml, is fully dead (`API token invalid`).

        Exit: mint a fresh reusable auth key (or re-scope the OAuth client
        with devices:write) in the tailnet admin console, replace the sops
        entries via the normal secrets:sync path, and prove it with one
        throwaway `tailscale up --authkey` on a test box.
      '';
    };
    job-scout-boards-url-checked-2026-11-24 = {
      title = "The swept boards, URL-checked: six employers answer, ZenDiS has none";
      date = "2026-11-24";
      kind = "open";
      priority = "P3";
      status = "OPEN";
      summary = "Nine sources swept and every employer they surfaced now carries a live board URL and the tracker's own fit: six answer with an infrastructure req, ZenDiS has no board to apply through, and STATWORX stays the one untracked lead.";
      from = ["job-scout-sre-platform-sweep-2026-11-24"];
      refs = {
        tasks = ["apps:add" "apps:export"];
      };
      body = ''
        Swept 2026-11-24 with new sources rather than the usual boards: the
        Bundesagentur Jobsuche API, ~100 Greenhouse/Lever/Ashby slugs, Personio
        and Recruitee feeds, BerlinStartupJobs, Remotive, RemoteOK, LinkedIn.
        Against the 1,125-row export it left one untracked fit.

        Every employer it surfaced, with the board that answers and the tracker's
        own fit — a display name is not a URL:

          STATWORX        personio/statworx    200  132 reqs  fit 3  filed
                          Cloud Engineer, Frankfurt am Main
          Helsing         gh/helsing           200  176 reqs  fit 4  tracked
          Isar Aerospace  gh/isaraerospace     200  142 reqs  fit 3  tracked
          Scout24         gh/scout24           200   13 reqs  fit 3  tracked
          SumUp           gh/sumup             200  325 reqs  fit 3  applied
          Solaris         gh/solarisbank       200   19 reqs  fit 2  tracked

        No board, so not a lead: ZenDiS answers 200 on zendis.de/karriere but
        renders client-side with no Personio or Greenhouse board (both 404), so
        nothing to apply through. AutoScout24 answers with 31 reqs and no infra
        title; Univention is down to 3 reqs, none infra, its PM req refused.

        Exhausted, not to be swept again: Arbeitnow (2,700 postings), Jobicy,
        Himalayas, Remotive, RemoteOK, BerlinStartupJobs, the Personio and
        Recruitee feeds, the ~100 ATS slugs. Jobsuche is unreachable, not
        exhausted: nine attempts, two resets, seven 403 "No match found".

        Dedupe reads normalized names, so `solarisbank` missed the tracked
        `Solaris` row and a Berlin SRE surfaced as new: grep the name first.
        Exit: rows hold at lead until 2026-12-07, then the vendor careers pages.
      '';
    };
    job-lane-queue-delphi-2026-11-24 = {
      title = "The delphi job lane is consistent, packet-ready and waiting: 82 prep rows and a fit-5 tail";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Lane consistent and idle by design: five duplicate Supabase/Managed Postgres rows closed, the Ashby-applied row standing, DeepL's packet prepared for a CAPTCHA hand-submit, and eleven prep rows plus a fit-5 lead tail waiting out the 2026-12-07 hold. Boards mined out; RemoteOK and BA jobsuche answer 403. Next is tailoring, not another sweep.";
      from = ["job-scout-boards-exhausted-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:add" "apps:update" "apps:dupes"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        State on 2026-11-24, after the duplicate cleanup. The tracker is
        consistent: five Supabase/Managed Postgres packet rows are closed as
        duplicates and supabase-postgres-deployment-engineer-nix stands,
        applied 2026-11-21 on an Ashby confirmation. Nothing in this lane
        lives in the repo; the record is the delphi table, and the hold runs
        to 2026-12-07.

        Packets are prepared and go nowhere on their own. DeepL is closest:
        the letter is dated 22 Nov and needs re-dating at send, and arbeitnow's
        CAPTCHA form is the only route, so it is a hand-submit. The prep queue
        is SingleStore, trivago, EPAM, IP Fabric, plusserver, Docplanner,
        Dropbox, Bloomreach, Angeheuert, Bechtle, QED.ai.

        At lead, awaiting tailoring: Workidentity, 0G, Wheely, Foundational,
        LuxusKollektion, iits, Tailscale, Kaluza, SAP, 1GLOBAL, Frontier,
        HiSolutions — the fit-5 tail of 290 employers, which is inventory
        rather than queue.

        Boards are drained (see the mined-out note). RemoteOK and BA jobsuche
        answer 403, so an empty sweep there proves the bot wall, not the market.

        Exit: one packet goes out through its ATS or a hand-submit after the
        hold, or one fresh DevOps/SRE/Platform/Infrastructure lead is filed
        from an employer page. No broad sweep.
      '';
    };
    job-scout-funnel-widened-2026-11-24 = {
      title = "Five employers no board sweep reaches, filed after the marquee names turned out to be held";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Five employers the record did not hold were filed live on 2026-11-24 — Swissquote, Julius Baer, vCluster Labs, Cloudflight, PORR — after a sweep of Swiss and DACH banks plus AI-infra vendors. The marquee names were already held or closed by rule 1, and five careers pages stayed unfetched rather than empty.";
      from = ["job-lane-queue-delphi-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:add" "apps:scout"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Five employers the record did not hold were filed on 2026-11-24, all
        live and all published off the aggregators this lane already drains:
        Swissquote (SRE, Cloud Operations, Gland), Julius Baer (Kubernetes
        Platform Engineer, Zurich), vCluster Labs (AI Infrastructure Engineer,
        remote), Cloudflight (SRE, Vienna plus six AT sites) and PORR (Senior
        Platform Engineer, Vienna). Fit 4 on the first three, 3 on the last two.

        Why these: the marquee names a broad search returns are already held —
        Flox, Nebius, Mirantis, Resend, Second Front, WunderGraph, Upvest,
        Unikraft, Wikimedia, STACKIT, Hetzner, IONOS, Scaleway, Contabo,
        noris, Mittwald, Adfinis, Aykua, Tweag. Widening meant the employers
        no board sweep reaches: Swiss and DACH banks on Workday and
        SmartRecruiters, and an AI-infrastructure vendor whose req lives only
        on its own careers page.

        What closed rather than opened: GitLab applied 2026-11-22 and its
        second req was not pursued; Canonical rejected 2026-11-22, so it is
        shut for 180 days; Maze applied 2026-10-04; Flox already applied, so
        four fresh Flox reqs are duplicates by rule 1.

        Unfetched, not empty: FiveSquare's careers URL 404s, INWX and SerNet
        careers paths 404, Scarf's careers redirects to its about page, and
        Hornetsecurity lists no infrastructure role. None of the five is
        evidence of a closed market.

        Next: tailor Swissquote or Julius Baer first, then vCluster. Sends
        stay held to 2026-12-07.
      '';
    };
    job-scout-niche-boards-2026-11-24 = {
      title = "Four employers from the niche boards, one with a deadline before the hold lifts";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "Niche sources the lane had not drained — the NixOS jobs board, fossjobs, jobs.ch and vendor careers pages — turned four employers into live leads: OpenNebula Systems, DeepJudge, SysEleven and the BIS. The BIS deadline of 2026-12-04 falls before the 2026-12-07 hold, so it needs a decision rather than a packet.";
      from = ["job-scout-funnel-widened-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:add" "apps:scout"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Origin scout-niche-2026-11-24. These sources had never been drained:
        the NixOS jobs board, fossjobs, jobs.ch and developerjobs.ch, and the
        vendors' own Teamtailor, Personio and Ashby pages.

        OpenNebula Systems — Kubernetes Platform Engineer, remote from Spain
        only, fit 4, posting open to 2026-12-09. Open-source cloud and edge,
        RKE2, Go, Terraform, CSI.

        DeepJudge — Site Reliability Engineer, Zurich on-site, fit 4. AI legal
        search across public and private clouds, Go/Python, GitOps, SLOs.

        SysEleven — SRE Managed Kubernetes, Berlin or 100% remote in Germany,
        fit 5. Go and Terraform operators, Prometheus/Loki, on-call, German B2.
        The 2026-11-23 drop recorded no SRE req on the board; there is one now,
        so this is the same employer resurfacing rather than a new one.

        Bank for International Settlements — SRE, Automation & Resilience,
        Basel hybrid, fit 4, three-year fixed term, applications close
        2026-12-04.

        Not new, checked: VirtusLab's Nix Wizard was already a manual lead;
        Luminovo applied; Parasail holds a live lead; Puzzle ITC's only open
        role is backend; Cloud&Heat lists nothing infrastructure; the BIT and
        ZHAW job URLs 404; Rocken and Avacone are agencies, not employers.

        Next: the BIS closes 2026-12-04, three days before the hold lifts, so
        the hold needs an explicit decision for that one row. Otherwise
        SysEleven and VirtusLab are the strongest Nix-adjacent targets.
      '';
    };
    job-scout-send-unblocked-2026-11-24 = {
      title = "Sweep 2 was blocked by board URLs, not by the send path";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-24";
      summary = "The sweep-2 block was ATS URL handling: four rows stored the arbeitnow board page as applyUrl while the join.com form sat in nextAction. All four now point at the form. himalaya, the API and apps:sent all work here; what remains is the 2026-12-07 hold, a packet build that delegates to frieren, and a pay-band decision on Livello.";
      from = ["job-scout-niche-boards-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh" "scripts/task/appflow-docs.sh"];
        tasks = ["apps:add" "apps:sent" "apps:docs:import"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2 (nixconfig:job-scout-sweep2) claimed five leads were blocked
        with board/ATS URLs. The block is URL handling, not the send path.

        Diagnosis, each part tested on 2026-11-24. himalaya is configured here
        with two accounts and apps:sent reads the Sent folder, exiting 0 with
        two bcc-blast findings over the last day — the mailbox is readable.
        The archive API answers and apps:docs:import ran (41 imported, 110
        unchanged). typst has no checkout here, so packet builds delegate to
        frieren over ssh, which is a capability limit, not a blocked send.

        The real defect: applyUrl held the arbeitnow board page while the
        join.com form was written into nextAction. NDI, VISPIRON, SPECTRUM and
        Livello are repointed at their join.com endpoints, all four answering
        200. JD stored: the board page's ld+json carries the text, imported
        into the database, so a packet builds from the row itself.

        Livello still needs a decision before any packet: the ad publishes
        EUR 45,000-50,000 a year in Düsseldorf, under a senior infra band, and
        requires a German work permit with no sponsorship.

        New leads from boards this lane had not read (karriere.at, ictcareer.ch,
        SIX careers): SIX Group Kubernetes Platform Engineer, Zurich, fit 5;
        Aargauische Kantonalbank ICT Cloud Platform Engineer, Aarau, fit 4;
        x-tention DevOps Engineer, Wels or Vienna, fit 4. 50Hertz was already
        held; zkb.ch and eurofunk careers paths 404, so those stay unfetched.

        Next: the hold to 2026-12-07 is the only thing between these rows and a
        submission — build the packet on frieren, then submit at join.com.
      '';
    };
    job-scout-tracker-curation-2026-11-24 = {
      title = "The tracker merges duplicate employers into one canonical row";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-24";
      summary = "Nine employers held two live rows each; every pair is now one canonical row, with the other closed at `other` and its evidence copied into notes. Packet contradictions were fixed only where the data disagrees with itself: two `lead` rows with built packets moved to `prep`, Proxify back to `lead` on a dead URL, litef given a portal URL. `apps:dupes` exits 0.";
      from = ["job-scout-send-unblocked-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh" "scripts/task/appflow-packet.sh"];
        tasks = ["apps:dupes" "apps:add"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The tracker carried nine employers with two live rows each. Curation
        2026-11-24 folded each pair into one canonical row and closed the other
        at stage `other` with a "Merged into <id>" status — the convention the
        table already used for scouted duplicate leads.

        Canonical choice was the row holding the further stage or the richer
        record: auteega (recruiter form plus the received mail), catapult
        (applied, mail linked, now pointing at Greenhouse 8329716), dhbw
        (infrastructure req, fit 5), globallogic (TPM interview), hits-nrw,
        icf (senior requisition), shipzero (packet tailored), sourceq (fit 5)
        and ucs (interview, two linked mails). Nothing was deleted: the API has
        no delete route, so a closed row keeps its evidence and its notes were
        copied onto the canonical row.

        Packets were reconciled only where the contradiction is in the data.
        gridscale and maxcluster carried a built packet at stage `lead` and
        moved to `prep` with statuses that say so; Proxify went back to `lead`
        because its requisition is dead on re-check. litef claimed a ready
        packet with no applyUrl, and now names www.litef.com/karriere.

        One thing this pass did not do: check the artifacts. Packets build on
        frieren and this host has no submissions directory, so thirty-odd
        "packet ready" claims stayed as written rather than being downgraded on
        a filesystem fact that cannot be read from here. `apps:dupes` now exits
        0 with `[]` (was nine employers); the table holds 1148 rows.
      '';
    };
    job-scout-dispatch-pass-2026-11-24 = {
      title = "A send-pending pass exits as dispatches plus one honest refusal: nothing is `sent`";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-24";
      summary = "41 open rows carry a complete packet and a dispatch file (To, subject, exact body) in ~/.local/state/appflow/dispatch: 5 have a published address, 36 are portal-only. 123 open rows are blocked on a missing artifact, 122 of them the CV. Every row reads UNSENT, because the hold runs to 2026-12-07 and the plane has no send verb — `applied` would assert a mail that does not exist.";
      from = ["job-scout-send-unblocked-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh" "scripts/task/appflow-packet.sh"];
        tasks = ["apps:query" "apps:update" "apps:upsert" "apps:gate:packet"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        A request to mark completed packets `sent` met two facts: the stage is
        derived from status (`applied` is the only bucket that means "a mail
        left"), and no mail leaves before 2026-12-07. Writing `applied` with a
        date would have been a fabricated submission in the fleet's pipeline,
        so the pass stops one step short and says so.

        What it produced per row: the recipient (row notes, apply_url, and the
        packet's lead/sheet lines only — matt@ addresses excluded), a subject
        (letter.json's own, else `Bewerbung als <role>` / `Application —
        <role>` by language), and the body verbatim from letter.json or the
        rendered PDF. Status is `Packet ready — dispatch prepared|portal only`,
        which stages as `prep`; next_action names the address, the 2026-12-07
        date, the dispatch ref and the file.

        Addresses are the scarce thing: netways (jobs@netways.de), two StackIT
        rows (recruiting@mail.schwarz) and two Telekom rows
        (thomas.arbeit@t-systems.com). The other 36 apply through a portal, so
        their dispatch file points at the URL instead of inventing a mailbox.

        Exit: after 2026-12-07 each row either flips to `applied` on the same
        day its mail leaves, or the lane records why the address could not be
        confirmed. The 122 missing CVs are a build backlog, one host per
        process, not a send problem.
      '';
    };
    job-scout-outreach-sent-2026-11-24 = {
      title = "Two outreach packets left the building before the hold: NETWAYS and noris, on an explicit operator instruction";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P1";
      date = "2026-11-24";
      summary = "NETWAYS GmbH (jobs@netways.de) and noris network AG (alicia.hanna@noris.de) were dispatched 2026-11-24 21:54 UTC from matt@bountystash.com through Resend; both read last_event=delivered at the API. Proofline was held: its posting requires a pull request before contact and the packet has none. The 2026-12-07 hold still stands for every other row.";
      from = ["job-scout-dispatch-pass-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:get" "apps:upsert" "apps:query"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The send-pending pass had refused to write `sent` because nothing had
        left and the hold ran to 2026-12-07. This turn the operator asked for
        three rows by name, so the hold is overridden for those three only and
        nothing else changes: the other 39 dispatch files stay UNSENT.

        The plane still has no send verb, so dispatch is the Resend API with the
        account whose domain is verified for sending, and the receipt is the
        message id. Two left:

          netways-system-engineer-schwerpunkt-cloud  jobs@netways.de
            01a20f8d-7fe8-7d59-b219-ad35adc40bf9  delivered
          noris-network-ag-senior-cloud-native-engineer-openstack-networking
            alicia.hanna@noris.de  01a20f8d-822a-7840-8820-a68c0fe41c5f  delivered

        Both addresses were confirmed on the live postings rather than taken
        from the packet (the netways jobs page names jobs@netways.de; the noris
        posting lists Alicia Hanna, HR Manager, with that address). Bodies were
        rebuilt from the letter PDFs, because no letter.json exists for these
        packets and a naive extraction leaves soft hyphens inside words.

        Proofline stayed home: proofline.sh/careers asks for a pull request to a
        prooflinedev repository before anyone reads a CV, and "documentation-only
        changes do not meet this requirement". An email without that link is the
        low-effort spam their filter exists to drop, so the row is `prep` with a
        next action that names the PR, not `applied`.

        Exit: the other rows wait for 2026-12-07; a row flips to `applied` only
        with a message id that answers delivered at the provider.
      '';
    };
    job-scout-scouted-decided-2026-11-25 = {
      title = "Five scouted leads decided: one packet, four parks, and two calls still owed";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-25";
      summary = "Five scouted leads were read and decided 2026-11-25: 21bitcoin (Munich) becomes the one packet — AWS multi-account IaC, DevSecOps, English, hybrid, on-call, EUR 75-120k — while gridscale OPCP, CBTW, ProcuVia and Little John Bikes park with a reopen trigger each. Still owed: a tailor order (Swissquote or Julius Baer, then vCluster) and a BIS ruling before the hold lifts.";
      links = ["job-scout-niche-boards-2026-11-24" "job-scout-outreach-sent-2026-11-24"];
      refs = {
        hosts = ["delphi"];
        modules = ["modules/plugins/appflow/sync.py" "scripts/task/apps-db.sh"];
        tasks = ["apps:overview" "apps:query" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Five scouted leads were read in full on 2026-11-25 and decided; every
        row now carries a status and a next action and `scouted` is empty.

        Packet: 21bitcoin (Munich) — AWS Organizations/Control Tower,
        CDK/OpenTofu/Terraform, GitHub Actions, Snyk/Semgrep, Bedrock agent
        platforms, English ad, hybrid, on-call explicit, EUR 75-120k. Build
        from the stored join.com JD by 2026-11-28, naming the AWS/CDK depth
        and reframing on-call as the fleet's sentinel and gatus paging.

        Parked with a reopen trigger each: gridscale OPCP (Ceph wins — fit 5
        with a ready packet, and one employer is one live thread; reopen if
        Ceph is silent by 2026-12-12), CBTW (MLOps lifecycle, LangChain, ETL,
        negotiation German), ProcuVia (React/TS product delivery), Little John
        Bikes (Windows/Entra/Citrix plus 2nd-level helpdesk, below senior).
        `parked` is a new stage in both status mirrors.

        Two calls are still owed. Tailor order: Swissquote or Julius Baer
        first, then vCluster — all three live at fit 3 to 4, no packet yet. And
        the BIS SRE closes 2026-12-04, before the hold lifts on 2026-12-07, so
        that row needs an explicit ruling: send it early as the one exception,
        or record the posting as missed.

        Exit: `scouted` stays at zero and each parked row keeps its reopen
        date, or the BIS row carries a written hold ruling.
      '';
    };
    job-scout-dated-sweep-2026-11-25 = {
      title = "The dated sweep: 3,723 postings, eight rows at scouted, and a fit upload that still 500s";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Arbeitnow, 90 ATS boards, eight Personio XML feeds and devjobs over the 2026-11-15 cutoff returned 3,723 postings and 63 title matches, with 31 employers already on record; eight new German platform leads were filed as the first rows at `scouted`, each held to 2026-12-07 with a next action naming the JD question, while a fit value still answers 500 on the upsert route.";
      from = ["job-scout-scouted-decided-2026-11-25"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:add" "apps:upsert" "apps:dupes"];
      };
      body = ''
        Sweep 2026-11-25, dated only: arbeitnow 30 pages (3,397 postings),
        90 ATS boards (2,401), eight Personio XML feeds and 40 devjobs links
        gave 3,723 postings inside the ten-day window (cutoff 2026-11-15); 63
        title matches across 35 employers, 31 of them already holding a row
        and skipped. Eight landed at origin scout-2026-11-25b, one Airbus
        listing merged into its better-fit sibling, and apps:dupes stayed [].
        Every posting was fetched live and read; nothing was sent.

        Filed at `scouted` and held to 2026-12-07, each next action naming the
        JD question: K+S Cloud & Platform Engineer (85, the GCP share) ·
        Cosinex System Administrator (85, same) · Airbus ML Data &
        Infrastructure (80, GCP versus on-prem) · ESQlabs Principal Platform
        (70) · SEW-Eurodrive CIAM Platform (70) · 50Hertz Platform (60,
        cluster stack and on-call) · HUK-COBURG Platform Linux/Ansible (60,
        same) · ZF Compute Platform Engineering Lead (55, GCP).

        These are the first eight rows at `scouted`: the status begins
        "Scouted 2026-11-25", which both stage mirrors map to the new bucket,
        and apps:upsert wrote the stage explicitly so the hourly sync agrees.
        The `fit` column is still null — a fit value answers 500 on
        /api/application-upsert — so the score lives in the status text.

        Sources that refuse this host: Bundesagentur 403, The Muse 404,
        germantechjobs deprecated, devjobs /api/jobs 404. Personio is the only
        German feed with a real createdAt; its hits were stale (eitco
        2026-11-10, Lumenaza May, synaos June, Reverion 2024).

        Exit: the eight stay scouted until 2026-12-07 and a person sends;
        the next sweep fixes the fit upload before it adds rows.
      '';
    };
    job-scout-sweep-2026-11-25d-parked = {
      title = "The 2026-11-25d sweep parks all four: place, language and a work-eligibility clause";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Delphi filed four 2026-11-25d leads at scouted — Whitecircle, Alan, Vitestro, Univé — and all four were read at source and parked: three on place alone, Univé also on language and on a governance-shaped role. No packet, which is the first evidence for the lane's own 25d rule: reads that end this way were never worth starting.";
      from = ["job-scout-lane-2026-11-25d"];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "scripts/task/apps-db.sh"
        ];
        tasks = ["apps:scout" "apps:update" "apps:dupes"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Four rows, read in full on 2026-11-25 from the employer's own text:
        arbeitnow's JobPosting JSON-LD for Whitecircle, Vitestro and Univé, and
        Ashby's posting-api job board for Alan.

        Whitecircle (Paris, 100-150k USD): GPU Kubernetes, the Nomad-to-K8s
        move and the canary/rollback release process are the best infra match
        the lane has seen, and it is still an office in London or Paris on a
        hybrid setup with relocation. Park on place.

        Alan (remote within France, Belgium and Spain, published 2026-09-10):
        Terraform/Terramate over AWS and GCP, Kubernetes, Datadog, incident.io,
        FinOps and AI-augmented ops, English enough and French not required —
        behind a clause requiring legal eligibility in those three countries.
        Park on place and eligibility.

        Vitestro (Utrecht): AWS direction, IaC as the source of truth, cost
        control and regulated medical-device readiness in English — three days
        a week in Utrecht, no remote route. Park on place alone.

        Univé (Zwolle, 57.5-81.2k EUR): Dutch ad, NL home days, continuity and
        MSP management over Azure/AKS rather than building it. Park on place,
        language and skill.

        Four reads changed no verdict, so the lane rule — German ad or EU-remote
        before a read — was adopted one sweep too late. The scout that filed
        these ran before it existed; the next sweep applies it at the filter,
        not after the read. Nothing sends before 2026-12-07.
      '';
    };
    job-scout-sweep-2026-11-25c = {
      title = "A ten-lead sweep on the fixed fit route: arbeitnow and the ATS boards, deduped against 920 employers";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Arbeitnow's 2,855 in-window listings and fifteen ATS boards left 94 family matches and 29 untracked employers; ten survived the duplicate and non-fit filters and were filed at scouted with origin scout-2026-11-25c, fit banded 3-4 through FIT_MAP on the upsert route 6916f4c7 fixed.";
      from = ["job-scout-dated-sweep-2026-11-25"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:dupes"];
      };
      body = ''
        Sweep 2026-11-25c, prep only, from delphi: twelve arbeitnow pages
        (2,855 listings) plus fifteen ATS boards (Greenhouse, Ashby, Lever)
        covered the 2026-11-15 cutoff. 94 postings matched the family; 65
        belonged to an employer already held (920 names, 312 rows at
        scouted). The ATS half returned one fit, PostHog's SRE, which is
        US-Pacific and refused on geography.

        The 29 untracked names still carried duplicates and non-fits, and
        each was read before it was dropped: Artefact under three company
        strings, Decathlontechnology against the tracked Decathlon, Capco's
        double listing, Accenture support, Quantexa's VP role, EXCO's
        graduate EE/OT req, IT-High's first-line support, got IT's M365
        admin, Screeningeagle's product owner and Phenogyag's project
        manager.

        Filed at `scouted`, origin scout-2026-11-25c, held to 2026-12-07:
        Doctrine 74 · Artefact 72 · Oxoia 70 (band 4) · Optiverus 68 ·
        Signal AI 66 · Opencast 62 · Alta Ares 58 · OBRO 58 · Talmatch 55 ·
        S-quaar 55 (band 3). The scores are 0-100 at the source and the
        route bands them, so the column holds 4 and 3: the 500 reported by
        job-scout-dated-sweep-2026-11-25 is closed by 6916f4c7.

        Exit: `apps:scout STAGE=lead` lists the ten for the first prep
        window after the hold, and none of them is a send.
      '';
    };
    job-scout-packet-brose-2026-11-25f = {
      title = "The Brose packet is built, honest about the AWS gap, and held for the 2026-12-07 send";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "A German letter and CV tailored to the landing-zone brief, built to the ad's own vocabulary and stating the three gaps — no production AWS landing zone, no Terraform or CloudFormation estate, no AWS certification — before the interview rather than in it; stored outside the repo and held for the send window.";
      from = ["job-scout-decisions-2026-11-25f"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:get" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The packet is two Typst sources and their PDFs under
        submissions/brose-aws-system-engineer-bamberg: a one-page German letter
        and a two-page CV that follows the ad's own order — landing zone,
        permissions, infrastructure as code, change discipline, monitoring, DR,
        cost — instead of the corpus order the base resume uses.

        The tailoring rule was one sentence of the ad per line of the CV. Where
        the ad says Organizations and Control Tower the packet says module
        boundaries and a registry check; where it says IAM it says a short-lived
        SSH certificate authority and per-host secrets; where it says ITIL change
        it says one gate that runs identically in CI and on the host. That
        analogy is a claim, so it is stated as one — translated onto the task,
        not dressed as AWS experience.

        The gaps are in the letter, in a paragraph of their own: no production
        landing zone, no Terraform or CloudFormation estate, no AWS
        certification. A German employer reads three honest sentences as
        preparation; it reads a discovered gap in month two as a problem.

        Nothing sends before 2026-12-07. The letter carries that date rather than
        the build date, the row stays at prep, and the ad runs to 2026-12-18, so
        the window and the advert now agree.

        Exit: send 2026-12-07 through the Brose form, log the send on the row and
        set the follow-up for 2026-12-21; re-date the letter if the send slips
        past the advert's validThrough.
      '';
    };
    job-scout-decisions-2026-11-25f = {
      title = "Of the 2026-11-25f five, Brose gets the packet and four park — two on the calendar";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "All five ads answer 200 with the full stepstone JobPosting, so the read decided on content: Brose's AWS landing-zone seat is the only end-to-end platform ownership and goes to packet, while Majori and ALTEN park because their validThrough lands before the 2026-12-07 window and Scheer and UKA park on a network-first and a Microsoft-first core.";
      from = ["job-scout-decisions-2026-11-25e"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:get" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Read all five ads in full at source before deciding, and the stepstone
        JobPosting carried the whole text the germantechjobs blob had abridged:
        responsibilities, profile, benefits and the apply route.

        Brose gets the packet. An AWS landing zone on Organizations and Control
        Tower, the core services, IaC in Terraform or CloudFormation, governance
        and DR, FinOps, ITIL incident work across Europe, North America and Asia —
        the only one of the five that is platform ownership end to end, and the
        freshest at 2026-11-18 with a 2026-12-18 window.

        Four park, and two of them on the calendar rather than on fit: Majori's
        validThrough is 2026-12-05 and ALTEN's is 2026-11-29, both before the
        2026-12-07 send window, so a packet cannot be spent on either. That is the
        window's price, paid for the first time on something worth having —
        ALTEN's GPU Kubernetes brief is the closest ad of the lane to this
        fleet's accelerator work.

        Scheer and UKA park on fit: Scheer is routing, switching, firewall and VPN
        with automation only desirable, and UKA is Microsoft administration —
        M365, Hyper-V, Entra ID, Exchange Hybrid, SQL Server, PRTG, Veeam — with
        Linux and Proxmox desirable but not the job.

        Exit: Brose preps now and sends 2026-12-07, the four stay parked, and an
        ad whose validThrough falls inside the window is parked at the read
        instead of carried to prep.
      '';
    };
    job-scout-decisions-2026-11-25e = {
      title = "The 2026-11-25e five are decided: spotixx and VCE get packets, three hold";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Every posting still answers with its JobPosting intact, so liveness does not discriminate and datePosted does: spotixx (two days) and VCE (eleven months, refreshed) move to prep, QAVION, Amber and hubside stay held on evidence, and the 2026-12-07 send window is intact.";
      from = ["job-scout-sweep-2026-11-25e"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:get" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Read each ad live before deciding, and the read answered a different
        question than the sweep did. All five return 200 with their JobPosting
        intact, so "live" is not the discriminator: datePosted is. spotixx is two
        days old (2026-11-23, validThrough 2027-01-04); VCE is eleven months old
        but its validThrough was refreshed to 2027-01-03 with the text unchanged,
        which is a re-upped listing rather than a dead one. QAVION, Amber and
        hubside run 2026-01-24, 2026-09-28 and 2026-06-19.

        spotixx gets a packet: two days old, 60-80k, GCP the only hard
        requirement, and the seat is IaC plus attested CI/CD plus automated audit
        evidence — this fleet's shape pointed at provable controls. VCE gets the
        second: the closest hands-on match on the board, self-managed kubeadm,
        microk8s and k3s, and no salary to anchor on is a question, not a
        refusal.

        The three holds are holds on evidence, not on fit. QAVION pays 80k-150k
        for an unnamed client ten months after posting; Amber wants three days on
        site for a secops seat behind the same security direction as spotixx;
        hubside is a recruiter with no client, no salary and a Nutanix admin
        core. Each costs one mail at the window, no packet.

        Exit: spotixx and VCE prep now and send 2026-12-07, the hold is intact,
        and a lead earns a packet only when datePosted is inside three months or
        the employer answers a question.
      '';
    };
    job-scout-sweep-2026-11-25e = {
      title = "The 2026-11-25e sweep files five German leads and learns datePosted is the only age signal";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Thirty arbeitnow pages (5,765 listings, 2026-11-18 to 2026-11-25) plus four Greenhouse boards left 130 family matches and 79 place-eligible rows; 74 were already held and five were filed at scouted — spotixx 68, QAVION 65, VCE 62, Amber 50, hubside 45.";
      from = ["job-scout-sweep-2026-11-25d"];
      refs = {
        modules = [
          "scripts/task/apps-scout.sh"
          "scripts/task/apps-db.sh"
        ];
        tasks = ["apps:scout" "apps:update" "apps:dupes"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2026-11-25e, prep only: arbeitnow's job-board API over thirty pages
        (5,765 unique listings, 2026-11-18 to 2026-11-25) plus the Greenhouse
        boards for GitLab, Grafana Labs, Cloudflare and Tigera. 130 titles matched
        the family, 79 were place-eligible, 74 of those were already held (927
        names) and five were filed at `scouted`. The dups were label noise —
        Artefact under three spellings, Microsoftcorporation, gridscale twice in
        one page — and `hiringOrganization` settles each one.

        Scored 0-100, banded by the route: spotixx 68 (3) · QAVION 65 (3) ·
        VCE 62 (3) · Amber 50 (2) · hubside 45 (2).

        spotixx (Frankfurt, 60-80k) is the one worth a look: DevSecOps over IaC,
        keyless CI/CD attestation, IAM and secrets, ISO 27001/SOC 2/PCI evidence,
        home office inside Germany, GCP the single fixed requirement. VCE
        (Dortmund) is the closest hands-on match the lane has had — self-managed
        kubeadm, microk8s and k3s clusters, Linux, PostgreSQL, Prometheus/Grafana,
        GitOps — at lab scale. QAVION is fully remote at 80k plus profit share and
        reads evergreen. Amber (Aachen, three days on site) and hubside (Munich,
        recruiter) are security ownership and Nutanix/Azure admin: the weak pair.

        Staleness is the finding: three of five carry datePosted of 2026-01-24,
        2025-12-17 and 2026-06-19 while validThrough runs into 2027, so
        `datePosted` is the only age signal. Remotive was tried and dropped —
        its `?search=` is ignored and the same fifteen unrelated jobs came back
        for all four queries.

        Exit: the five stay scouted, nothing sends before 2026-12-07, and the
        next sweep reads `datePosted` before the ad.
      '';
    };
    job-scout-sweep-2026-11-25d = {
      title = "Four leads after the boards went quiet: Whitecircle, Alan, Vitestro, Univé";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Hours after the c sweep, 14 Arbeitnow pages (3,181 listings) and 36 ATS boards left 152 family matches, 112 of them held; the 40 untracked names were mostly the c refusals and off-lane roles, and four survived at scouted with origin scout-2026-11-25d, fit banded 3-4 through FIT_MAP.";
      from = ["job-scout-sweep-2026-11-25c"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
      };
      body = ''
        Sweep 2026-11-25d, prep only, from delphi, 25 hours after c:
        fourteen arbeitnow pages (3,181 listings) and 36 ATS boards (19 in
        the first tier, 17 EU-heavy in the second) gave 152 family matches.
        112 belonged to an employer already held (929 names, 1,209 rows);
        the second tier's only unheld name was Alan.

        The 40 untracked arbeitnow names were read one by one. Most were
        the c refusals still standing (Accenture, capco's three listings,
        Quantexa's VP seat, Phenogyag, Screeningeagle, EXCO's graduate
        EE/OT req) or roles outside the lane: backend platform at Manychat,
        DPG and BLP, Imc's first-line IT support, Quandela's hardware
        systems engineer, Falu's freelance PLC contract, Trainline's
        security seat and Agon's simulation software.

        Filed at `scouted`, origin scout-2026-11-25d, held to 2026-12-07:
        Whitecircle 80 (GPU Kubernetes, Paris) · Alan 70 (multi-cloud IaC,
        remote FR/BE/ES) · Vitestro 70 (AWS architect, Utrecht) at band 4,
        Univé 64 (Azure/AKS platform, Zwolle) at band 3. Alan's
        work-eligibility rule is the first question; nothing is a send.

        c's ten rows were read in and moved on before this sweep started
        (nine parked, Oxoia at prep), so they were held, not re-filed.

        Exit: `apps:scout STAGE=lead` lists the four. The small yield is
        the finding: at this dedupe depth these boards are exhausted, so
        the next sweep spends its budget on sources that still refuse us.
      '';
    };

    job-scout-sweep-2026-11-25e-boards = {
      title = "The 2026-11-25e boards pass: three German platform leads, every other board held";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Fifteen Arbeitnow pages, 60 ATS boards, the November HN thread and germantechjobs yielded 21 untracked infra employers after the 934-name filter; DIN, Bonnier Media and Vetter Pharma survived at scouted with origin scout-2026-11-25e, fit 76/66/62 banded 4/3/3, while PSI Software and netgo dropped out as already held.";
      from = ["job-scout-sweep-2026-11-25e"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2026-11-25e, boards pass, prep only, from delphi: Arbeitnow, the
        ATS boards, the November HN thread and germantechjobs, deduped against the
        934-name ledger, on the post-d rule — German ad or EU-remote.

        Arbeitnow: 15 of 16 pages, 3,516 listings, 134 family titles; 11 left
        after the ledger and place filters, all read, none a platform role
        (smart-hands networking, first/second-level support, a 20-hour
        generalist, ERP and M365 administration, construction planning).

        60 ATS boards: 2,080 postings, 86 family titles, every one held. The slug
        `grafanalabs` does not normalise to `Grafana Labs`, and `solarisbank` is
        the Solaris row already on record. The HN thread's 26 infra-plus-Europe
        comments named Simple Analytics, Namespace, Splash Tech and Proxima
        Fusion, all held; the rest were onsite or US/Canada/LATAM.

        germantechjobs was the only source with new employers: 21 after the
        filter, five read through the feed's requirement block because the pages
        are JS shells. PSI Software SE and netgo proved held, leaving three rows
        at scouted, origin scout-2026-11-25e, fit sent as the band because the
        column's CHECK is 1-5: DIN 76/4 (Azure, AKS, Terraform at a standards
        body), Bonnier Media 66/3 (Azure and IaC), Vetter Pharma 62/3 (OT DevOps,
        GitLab and Ansible in GxP). Held to 2026-12-07.

        Refused on eligibility: Amazon (EU-member-state nationality), Airbus
        Defence and Space, Teledyne, ELAC SONAR, Enrichment Technology; on shape:
        Porsche Consulting, ALTEN, KIND, Scheer.

        The five rows of job-scout-sweep-2026-11-25e share this origin from a
        concurrent turn, so it holds eight and the stage twelve. Nothing is a send.
      '';
    };

    job-scout-sweep-2026-11-25f = {
      title = "The 2026-11-25f sweep: a second ATS batch and the German boards, one systems admin";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "A second ATS batch of 115 slugs, five aggregators, Berlin Startup Jobs and 1KOMMA5GRAD's Personio feed produced 77 platform-family titles, 59 already held and 18 outside German or EU-remote scope; Jonas und der Wolf survived at scouted with fit 82 band 4 on origin scout-2026-11-25f.";
      from = ["job-scout-sweep-2026-11-25e-boards"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25f: the mined pool, one Berlin systems admin, prep only.
        Sources the a-e sweeps had not used: 115 ATS slugs across Greenhouse,
        Ashby and Lever in a second batch (37 boards answered, 1,631 postings, 77
        platform-family titles), remotive, Working Nomads, Himalayas (120 of
        116k), Landing.jobs, RemoteOK, We Work Remotely, Berlin Startup Jobs'
        engineering and nine skill boards, 1KOMMA5GRAD's Personio XML (339
        positions) and only the freshest Arbeitnow page.

        The new boards were the dedupe test rather than the source: 59 of the 77
        family titles sit at employers already on record — enpal's Staff Platform
        Engineer (Berlin), Kubermatic's Senior Cloud Native Consultant (CET +-4),
        IONOS Linux administrators, Camunda SRE, ClickHouse EMEA remote, Adyen
        platform engineers, Scaleway SREs (Paris), Celonis Head of IT Platform
        (Munich). The other 18 were US, India, Australia or Costa Rica.

        German leads that cleared the ledger were refused on shape or evidence:
        DATATRONiQ is already held, Proact's presales architect and Accenture's
        1st/2nd-level support are not engineering, and Wyden's Lead Platform
        Engineer (AWS) is remote from a Zurich entity with no EU contract stated.

        One row: Jonas und der Wolf, (Senior) Systems Administrator, Berlin-
        Moabit, fit 82 band 4. German ad, 50-70k at 40h (30h possible):
        Linux with Docker/Portainer, Ansible, GitLab CI, Grafana/InfluxDB/
        Telegraf, Sentry, BorgBackup and WireGuard, ISO 27001, C1 German. It
        excludes customer infrastructure, so the DevOps share is support.

        Origin scout-2026-11-25f; five rows of another turn share it. Exit:
        nothing read past the requirement block, nothing sent, held to 2026-12-07.
      '';
    };

    job-scout-packets-2026-11-25g = {
      title = "Sweep 2026-11-25g read at source: five packets, three rows that should not become one";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "All eight 25g rows were fetched at source (six needed a browser because the board renders client-side) and read in full: five German ads became one-page letters with two-page ad-ordered CVs, while two Azure architect roles and one duplicate employer did not.";
      from = ["job-scout-sweep-2026-11-25g"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:get" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2026-11-25g was the first German batch after the ATS pool ran dry,
        and its eight rows sat unread until this pass. All eight were fetched at
        source: six germantechjobs pages render only in a browser, so a plain
        fetch returned a cookie banner and the ad needed an open, a wait and a
        text dump; the other two slugs redirect to a board index, so their ad
        body came from the feed item that carries salary, requirements and
        responsibilities.

        Five rows became packets under submissions/: porsche, enrichment,
        signal-iduna, netcologne and ra-radiology. Each is a one-page German
        letter and a two-page CV in its own ad's order, with the gaps in the
        letter rather than in the interview. Porsche is the one where a quiet
        fact reorders everything: the ad makes a master's mandatory and he has
        one, so the row is a real application, not a long shot.

        Three rows did not become packets. fonds-finanz and vonovia ask for
        Azure enterprise architecture as the substance of the job — landing
        zones, Entra ID and PIM, FinOps, steering providers — and a Nix fleet is
        not an answer to that. psi-grid is the same employer as
        psi-software-se-devops-engineer-m-w-d, so the older row keeps the thread.

        That duplicate is the rule working, not a loss: one employer, one live
        thread. Everything is held to 2026-12-07 and nothing was sent.

        Exit: send the five on 2026-12-07, log each send on its row, follow up
        2026-12-21; a packet whose ad expires first is dropped, not sent late.
      '';
    };
    job-scout-sweep-2026-11-25g = {
      title = "The 2026-11-25g sweep: eight boards in full and the German inventory behind them";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Eight named boards read in full produced 198 platform-family titles, 90 held and 53 outside German or EU-remote scope; eight German rows sit at scouted on origin scout-2026-11-25g (six band 5, two band 4), with germantechjobs the only board still yielding fresh employers.";
      from = ["job-scout-sweep-2026-11-25f"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25g: eight boards read in full, the first German batch after the ATS pool ran dry.
        Boards and what answered: germantechjobs RSS (1,291 postings) plus ten tag pages,
        berlinstartupjobs feed and engineering pages, WeWorkRemotely three feeds (120), RemoteOK base
        and devops tag, Ashby 48 slugs (17 boards, 973 postings), Personio 18 slugs (2 feeds, 343
        positions), SmartRecruiters 23 slugs (DeliveryHero, 100 rows); Stepstone refused every request.
        Dedupe: 198 platform-family titles, 90 at employers already on record, 53 US, UK or APAC. The six
        German or EU-remote Ashby titles are all held — enpal, 1komma5grad, Camunda, Kubermatic — and
        WWR plus RemoteOK's 35 family roles are all outside scope, so the fresh German inventory sits on
        germantechjobs.
        Eight rows at scouted, origin scout-2026-11-25g:
        Enrichment Technology Linux Platform Engineer, Jülich 60-80k, band 5;
        PSI Software DevOps Engineer, Neuburg 45-75k, band 5;
        SIGNAL IDUNA Public Cloud Engineer, Dortmund 65-95k, band 5;
        NetCologne System Engineer Infrastructure, Cologne 62.4k, band 5;
        Fonds Finanz Cloud & Infrastructure Architect 50-70k, band 5;
        Porsche Consulting AI & Cloud Platform Engineer, remote 64-104k, band 5;
        Vonovia Cloud Architect Azure/AWS 60-85k, band 4;
        RA Radiology Head of Infrastructure 60-95k, band 4.
        The 100s are corpus coverage of a dense requirement block, not a ranking: the matcher normalizes
        against 60 points and saturates, so band 5 means the ad names the stack.
        Refused on shape or evidence: WALDNER (SAP Basis), CAL Consult (8+ years, contract-shaped),
        Starnberger Kliniken (network only), Amazon (location unstated, consulting), Trellix (manager,
        28-68k), KIND (release manager, 30-55k), plus Werkstudent, dual-study and 1st-level titles.
        Caveats: germantechjobs carries the requirement block, not the full ad, and no city for Vonovia,
        Fonds Finanz or RA Radiology; Porsche's ad makes a master's mandatory.
        Exit: nothing sent, nothing read past the block, held to 2026-12-07.
      '';
    };

    job-scout-sweep-2026-11-25i = {
      title = "The 2026-11-25i sweep: the feed was flat, the vendors' own careers pages were not";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Germantechjobs re-read in full gave 99 platform-family titles and 67 employers the ledger lacks, nearly all in-house Windows administration; the fresh engineering came from six vendor careers pages, where two ads became packets (JACOB Karlsruhe, NT-ware Bad Iburg) and three were parked on craft or place.";
      from = ["job-scout-sweep-2026-11-25h"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25i: germantechjobs answered 586 items with 99 devops/SRE/platform titles at 67
        employers the 954-row ledger lacks, nearly all in-house Windows administration, so none was filed.
        The fresh engineering came from the vendor pages the apps skill names as aggregator-free — LINBIT,
        B1 Systems, Open-Xchange, Univention, Proxmox, Hetzner — and every one already held a row, so one
        employer keeps one thread. Five rows were filed at scouted, origin scout-2026-11-25i: JACOB
        Elektronik (Senior Linux Systems Engineer), NT-ware (Linux-Systemadministrator), IPB (Senior Network
        Engineer), MIWE (Systemarchitekt Cloud/Kubernetes) and Proxmox (IT Infrastructure Allrounder), each
        stack and gap in its ledger row. Two packets were built from JACOB and NT-ware, a one-page German
        letter and a two-page CV in each ad's own order. Three were parked: IPB is ISP routing at backbone
        scale, MIWE is IoT edge architecture and project leadership, Proxmox is Vienna on-site at Allrounder
        level despite the closest stack match.
        Caveat: germantechjobs detail pages redirect to the board index, so the ad text is the feed item's
        own requirement block; the Proxmox ad was read on proxmox.com, and NT-ware's two on-site days are why
        the letter offers a move. Refused on shape: RockQ, WWK, the Niedersachsen justice IT, LearnWise,
        BALLY WULFF and the remaining MSP sysadmin rows.
        Exit: five rows decided, two packets held to 2026-12-07, nothing sent.
      '';
    };

    job-scout-todo-2026-11-25i = {
      title = "Five 2026-11-25i rows held to 2026-12-07: two packets to send, three todos to re-read";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-25";
      summary = "Two packets stand built under submissions/ and send on 2026-12-07 (JACOB via its application route, NT-ware via its form); IPB, MIWE and Proxmox are open todos on the same hold date, each revisiting only on the condition its row names.";
      from = ["job-scout-sweep-2026-11-25i"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:update" "apps:scout"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Nothing from 2026-11-25i has been sent. Send day and follow-up day are one date for all five
        rows: 2026-12-07, then 2026-12-21.
        Complete packets, a one-page German letter and a two-page CV in each ad's own order, each with
        a submission-sheet.md carrying page counts and hashes:
        jacob-elektronik-senior-linux-systems-engineer — send through the JACOB application route;
        nt-ware-linux-systemadministrator — send through the NT-ware form; the ad wants two on-site days
        in Bad Iburg, so the letter offers a move.
        Three rows are open todos on the same hold date, not live applications. A revisit starts by
        reading the full ad at source, not the ledger row, and only on the condition the row names:
        ipb-internet-provider-berlin-senior-network-engineer-juniper-automation — senior ISP routing
        (Juniper, BGP/OSPF at backbone scale); only if IPB opens a systems or platform role.
        miwe-systemarchitekt-projektleiter-cloud-kubernetes — IoT edge architecture and cross-department
        project leadership at 36-60k; only on a pure platform or SRE role.
        proxmox-it-infrastructure-allrounder — closest stack match (Debian, Proxmox VE, KVM/LXC,
        firewalls) but Vienna on-site at Allrounder level; only on a remote or Germany-based role.
        One employer keeps one thread, and an ad that expires before 2026-12-07 is dropped, not sent late.
        Exit: both sends recorded on their rows with 2026-12-21 follow-ups, and each parked row either
        revisited or closed with its reason, so this note moves to DELIVERED.
      '';
    };

    job-scout-sweep-2026-11-25l = {
      title = "The 2026-11-25j sweep: the feed was flat by hash, and the fresh engineering was three German ads";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Germantechjobs answered byte-identical to the 25i read, the other boards and the ATS families only held employers, so the sweep's fresh engineering was three German ads: EOS and WinValue became ad-ordered packets and AND-E was parked on DR governance.";
      from = ["job-scout-sweep-2026-11-25i"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25j: germantechjobs came back byte-identical to the 25i read (sha256 cf313395, 586
        items), so flat is a hash — 155 in-lane titles at 129 employers left 80 unheld, nearly all in-house
        Windows or VMware administration. The other boards and the ATS families only held employers, and
        Stepstone answered this pass with a 301, so nothing here rests on it.
        Three rows were filed at scouted, origin scout-2026-11-25j — EOS (DevOps), WinValue
        (IT-Administrator), AND-E (Lead Infrastructure Backup/DR) — and two packets were built from them, a
        one-page German letter and a two-page CV in each ad's own order, the gaps named in writing in each
        ledger row. EOS's two-year term is accepted in writing. AND-E was parked: it owns DR governance,
        BIA, RTO/RPO and exercise running, not building the fleet.
        Refused on shape: EOS Senior IT Security (assessment, no operational ownership), ProBioGen, 11880,
        GELITA, ante Holding.
        Exit: send both packets on 2026-12-07 with 2026-12-21 follow-ups, close AND-E on its condition, and
        let the next sweep prove or drop the flat-feed claim by hash. Nothing was sent.
      '';
    };

    job-scout-sweep-2026-11-25h = {
      title = "The 2026-11-25h sweep: the feed was exhausted, the unfiled employers were not";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "Germantechjobs re-read in full came back byte-identical to g, so the pass turned on dedupe: exact-name matching against 955 ledger employers exposed 94 never-filed employers, and six of them became scouted rows on origin scout-2026-11-25h.";
      from = ["job-scout-sweep-2026-11-25g"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25h: germantechjobs re-read in full and unchanged — 1,291 postings, zero new
        since g, and its ten tag pages carry no job link the feed lacks. The other seven boards were not
        re-read: g proved Stepstone unreachable and Personio, SmartRecruiters and Ashby empty of unheld
        infra titles.
        The lead source this pass was the dedupe, not the feed: g's held check was a loose substring match,
        so 94 employers inside the same 1,291 postings had never been filed. Exact-name dedupe against all
        955 ledger employers leaves 213 family postings at 33 held employers and those 94.
        Six of them became rows at scouted, origin scout-2026-11-25h:
        Mecklenburgische Linux System Engineer, 55-75k, band 5;
        Fresenius Medical Care Infrastructure Datacenter, 60-82k, band 5;
        Vivantes Storage/Backup/Exchange engineer, Berlin 53-66k, band 4;
        Röchling Industrial System Engineer Infrastructure & Security, 60-85k, band 5;
        Stadt Mannheim Managed Datacenter/Server specialist, 40-60k, band 4;
        Waldemar Link Senior IT Systems Engineer, Hamburg 60-85k, band 3.
        Refused from the residual on shape or evidence: ELAC SONAR (multi-year local-LLM operations),
        Röchling Medical and intersoft (client management, 1st/2nd level), Zech (connectivity only),
        alphacaps, Sunrise Medical and SimonsVoss (M365 administration), sino AG (25-person allrounder
        shop), Allegion (the same ad template as SimonsVoss), plus Werkstudent, dual-study, Ausbildung and
        municipal trainee titles.
        Caveats: no city in the feed entry for Mecklenburgische, Fresenius or Röchling Industrial; Vivantes
        requires measles immunisation proof; Stadt Mannheim pays TVoD, so the band is indicative; Waldemar
        Link's 67 is a Microsoft/identity ad against a Linux-weighted resume.
        Exit: nothing sent, nothing read past the requirement block, held to 2026-12-07.
      '';
    };

    job-scout-sweep-2026-11-25j = {
      title = "Sweep 2026-11-25i, pass two: Stepstone came back and carried six leads";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-11-25";
      summary = "A second read of the boards found Stepstone newly reachable and six unheld German infrastructure employers behind exact-name dedupe, while germantechjobs stayed identical and the remote boards held nothing in lane.";
      from = ["job-scout-sweep-2026-11-25i"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25i, second pass, filed as note j because the i label was already taken earlier
        today by a gtg pass that filed IPB, JACOB, MIWE, NT-ware and Proxmox. This pass read the boards again
        and Stepstone answered for the first time in the lane: its listing pages render normally (25 inline ads
        per query page), while detail pages only load with a Referer header and otherwise reset the connection
        in 60 ms. Germantechjobs came back identical for a third time: 1,291 postings, zero new since g, and its
        ten tag pages are still 6.4 KB with zero items. Berlinstartupjobs produced 28 engineering links and one
        infra title; WeWorkRemotely 25 US-remote devops roles; RemoteOK 19 mostly US SaaS listings; 20 slug
        probes across Personio, SmartRecruiters and Ashby, built from the 94 unfiled employers, returned 3
        postings and 1 infra title.
        Stepstone: twelve search pages over six infra queries gave 228 unique cards, about 100 unheld
        direct-employer ads parsed through JobPosting JSON-LD, and six new rows at scouted on origin
        scout-2026-11-25i, whose other five rows belong to the earlier i pass:
        DENIC Ops Engineer Kubernetes/CI-CD/Security (Frankfurt), band 5;
        Schwarz Digits STACKIT control-plane Platform Engineer (Bad Friedrichshall), band 5;
        Rheinmetall Senior Platform Engineer Linux and Container (Düsseldorf), band 5;
        Viridium Cloud and Systems Engineer (Neu-Isenburg), band 5;
        mgm Linux Systemadministrator Cloud Infrastructure (Aachen), band 5;
        PROTOS Senior DevOps Engineer Cloud/Kubernetes (Berlin), band 5.
        Dedupe caught Testo (held as Testo SE & Co. KGaA) and SEW-EURODRIVE (held as SEW-Eurodrive), and KubeOps
        was refused because its ad body is Bechtle boilerplate while both KubeOps and Bechtle sit on the ledger.
        Agencies skipped: Amadeus Fire, FERCHAU, Brunel, Akkodis, Ratbacher, Instaffo, OMNIGENA, TECCON.
        Shape refusals: Bauingenieur and Projektleiter infrastructure, solution architects, LLMOps, SAP DevOps.
        Caveats: Stepstone publishes no salary on any of these ads, so every band is stack coverage only, and
        all six land on band 5 because the requirement blocks are dense enough to saturate the matcher;
        Rheinmetall carries on-call and travel; Viridium requires C2 German; PROTOS is consultancy delivery.
        Exit: nothing sent, nothing past the requirement block, held to 2026-12-07.
      '';
    };

    job-scout-sweep-2026-11-25k = {
      title = "Dedupe of the six 2026-11-25i rows: two were already answered, four stand";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Re-matching the six filed rows against the whole ledger by employer token found Rheinmetall's and Schwarz Digits' postings already carried by live rows, so those two are parked with their band-5 evidence intact and four stand at scouted.";
      from = ["job-scout-sweep-2026-11-25j"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:dupes"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Second pass over the six rows filed in job-scout-sweep-2026-11-25j. Dedupe ran over the whole ledger
        (1,253 rows, 972 employers) with token matching as well as exact names, and two of the six were already
        answered. Rheinmetall's Senior Platform Engineer - Linux & Container is the requisition already carried
        by rheinmetall-it-solutions-senior-platform-engineer-linux-container, a live lead at band 3; parent and
        subsidiary count as one employer under the 180-day rule, so band 5 cannot make it a second application.
        Schwarz Digits' (Senior) Platform Engineer - STACKIT Control Plane Platform is GT1923, and that row was
        already closed as a duplicate of stackit-iac, which is applied as of 2026-11-22: nothing at Schwarz
        Digits reopens before 2027-05-21.
        Both are parked, not deleted. The posting, the band-5 fit and the URL stay, the status names the row
        that blocks it, and the next action says what would reopen it.
        Four rows stand, all band 5 and all in lane: DENIC eG (Frankfurt, Kubernetes and CI/CD for the .de
        registry), mgm technology partners (Aachen, managed cloud and virtualisation), PROTOS TECHNOLOGIE
        (Berlin, consultancy DevOps), Viridium Gruppe (Neu-Isenburg, OpenStack and Azure, C2 German). Each
        keeps the Referer-header caveat and the 2026-12-07 hold in its next action.
        The finding is the dedupe, not the rows: exact-name comparison cannot reach an employer that sits on
        the ledger as "STACKIT / Schwarz Digits" or "Rheinmetall IT Solutions". Matching the distinctive word
        of the employer name caught both. The next sweep runs that match before filing and parks any row whose
        employer already holds a live application.
        Exit: no sends, nothing read past the requirement block, hold to 2026-12-07.
      '';
    };

    employer-lead-sweep-2026-11-25t-freebuff = {
      title = "Five untracked employers carry a live req, and the tracked vendors posted second reqs";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Ran the open note as cycle 2026-11-25t, prep-only. Giant Swarm has no live req; SUSE moved to Workday with one German seat; LINBIT's board is placeholder copy above a no-openings notice. The four tracked vendors each posted a second req. Of Stepstone's 138 page-one ads, five untracked employers carry a live req past the hold and Fabasoft parks on a 12-05 expiry; no row minted.";
      from = ["job-scout-next-sweep-freebuff"];
      links = ["job-scout-next-sweep-freebuff"];
      refs = {
        modules = ["taskfiles/apps.yml" "scripts/task/apps-scout.sh"];
        tasks = ["apps:search" "apps:scout" "checks:quick"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Ran the open note as cycle 2026-11-25t, prep-only: no row minted, nothing sent, evidence in
        ~/.local/state/appflow/followups/2026-11-25-employer-lead-sweep-freebuff.md.

        Vendor pages first, since the last round read ATS APIs only. Giant Swarm states that it has
        no open positions, so that recheck is a finding. SUSE is on Workday
        (suse.wd3.myworkdayjobs.com/Jobsatsuse; suse.com/careers is a landing page and
        jobs.jobvite.com/suse is Jobvite's own vendor page): 17 postings, one in Germany — Premium
        Support Engineer, posted 2026-11-20. LINBIT's /jobs/ is a stub, two lorem-ipsum cards above
        a no-openings notice, so the prep row blocked on that JD chases placeholder copy.

        The four tracked vendors each answered with a second req, not a new employer: B1 Systems
        still lists its Entwickler role alongside Senior Admin Linux/Open Source; Univention's
        tracked Open Source Software Engineer is gone and IT Consultant replaces it; Open-Xchange
        publishes Senior DevOps Engineer; Proxmox's new kernel, SDN and support seats are Vienna
        on-site, the place rule that already parked its Allrounder.

        Stepstone, six lanes one page each: 138 unique ads, 26 at employers the ledger holds by
        house token (plusserver, Bundesdruckerei, Interhyp, GMX/WEB.DE as the 1&1 mail subsidiary,
        HxGN, Diehl Defence, ABOUT YOU, Upvest, novomind, STULZ, EWE NETZ, LAIQON, AUGENTIC,
        BIOTRONIK, Claranet, Pradtke, grinnberg, meinestadt.de, S Rating), plus 17 cards that are
        staffing firms naming someone else's client.

        New, read in full, minted at scout-2026-11-25t once the hold lifts: GOLDBECK Technologies
        Platform Engineer (Azure/Kubernetes/Terraform, fit 4, 12-08), EDEKABANK (Senior) DevOps
        (GCP/Helm/ArgoCD, fit 4, 12-20), SUSS MicroTec Infrastructure & Platform Engineer
        (HCI/Veeam/MS-SQL, fit 2, 12-17), SCHIFFL IT Cloud Infrastructure Engineer
        (vSphere/Windows, fit 2, 12-23), SUSE (fit 3). Fabasoft's Kubernetes Consultant is the
        pass's closest stack match and closes 12-05, inside the hold.

        Exit: checks:quick green on this commit; the rows land after 2026-12-07.
      '';
    };
    job-scout-sweep-2026-11-25s-parallel = {
      title = "The fresh families, read: four feeds, one Nürnberg carrier, and a wall where a board should be";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "A fresh board set after 25r: Himalayas, Jobicy, the two November HN threads, and the Greenhouse/Lever/Recruitee/Workable employer feeds over 360 non-ledger names. One ad survived the 45-day rule — Core-Backbone GmbH, Linux IT-Systemadministrator, band 3 — and is filed at scout-2026-11-25s. The rest is two measured walls and three archives too young to qualify.";
      from = ["job-scout-sweep-2026-11-25r"];
      refs = {
        modules = ["scripts/task/apps-scout.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The 25s id was claimed by the Stepstone lane while this pass ran, so this is the parallel note for
        the same cycle: my one row shares origin scout-2026-11-25s with that lane's six. The brief was a
        fresh board set after 25r, and the honest answer is that this market has no sixth feed waiting: the
        four families read here are archive-poor or archive-huge, and one ad survived the 45-day rule.
        Himalayas is a wall rather than a board: it ignores sort, order, q and category, publishes about
        1,277 postings a day, and the 45-day rule only opens past roughly 57,000 postings — a 2,850-page
        traversal. A hundred pages were read as a measurement, none eligible, at about one page a second
        under 429 backoff. Not repeated. Jobicy's europe/engineering archive is 104 postings, newest
        2026-11-21, all inside the cut; the two November HN threads hold 19 lane posts filed 2026-11-02.
        The employer feeds were the flat half: 0 of 360 non-ledger names answered on Greenhouse or Lever,
        Workable timed out unread, Recruitee answered five boards and 48 offers, one in the window.
        That one is Core-Backbone GmbH, a Nuernberg carrier, Linux IT-Systemadministrator, band 3 through
        FIT_MAP (58), filed at scout-2026-11-25s with the Recruitee portal as the action after 2026-12-07.
        Exit: one row and one note. Do not repeat Himalayas without a filter, and finish or drop Workable.
      '';
    };
    kelvion-gcp-lead-verified-2026-11-25 = {
      title = "Kelvion's GCP role is live on the employer's own board, so the lead holds — not because the posting is in doubt";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "The 2026-11-25 verification pass on kelvion-holding-gmbh-cloud-platform-engineer-gcp-m-w-d found the requisition open on Kelvion's own softgarden board and on kelvion.com, not just the Bundesagentur mirror, with requirements that match the row. The onsite share is published as Hybrid with no day count, so it stays unknown rather than assumed. The lead holds to 2026-12-07 on the prep-only rule.";
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:update" "apps:scout:parked"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The row asked for verification only, and named two things to settle: the employer's own
        requisition, and the Herne onsite share. Both are settled, one comfortably and one not.
        The Bundesagentur listing still resolves and was edited six days ago, but a mirror proves
        little, so the employer's board was read directly: softgarden 67879872 and the kelvion.com
        detail page both answered 200 on 2026-11-25 with the same body — Von-der-Heydt-Strasse 2 in
        Herne, full or part time, posted 12.11.26, apply button live. The GCP duties match the row
        line for line: run GCP inside a hybrid estate, cloud-native on Kubernetes and Cloud Run,
        Terraform as the IaC tool, CI/CD, integration with on-prem and Azure Entra ID, IAM and audit
        work, migrations, FinOps. The profile asks three years of cloud engineering, one scripting
        language, and excellent English; German is nowhere in it.
        The onsite share is the part that does not resolve. The board says Hybrid, the address is the
        Herne head office, and no days per week are published anywhere in the listing, so the row's
        Herne hybrid stays accurate and the share stays unknown. It is not a reason to hold, and it is
        reason enough to ask early once a conversation starts.
        One thing the row did not know: a sibling Cloud Platform Engineer Microsoft Azure req
        (BA 19663-0067880677-S) went up five days ago at the same Herne address. One application per
        employer means these are one decision, not two shots.
        Verdict: the lead is real and prep can start, but nothing is sent before 2026-12-07. The row
        now carries the verification date, the employer-board evidence and the hold date.
      '';
    };
    job-mail-attention-2026-11-25 = {
      title = "The 25p sweep had nothing left to file, and the mail says Canonical and Adyen are closed";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "No 25p attention-sweep artifact exists: 25p was a Stepstone board pass, its eleven rows are all in the ledger, and the four it parked are not rows on purpose. The mail did have news — Canonical's six \"we regret\" updates and Adyen's \"not to move forward\" close two applied rows, and the remaining decision mail is acknowledgements.";
      from = ["job-scout-sweep-2026-11-25p"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:update" "apps:emails" "agents:mail:attention" "apps:scout:parked"];
        docs = [".agents/skills/apps/SKILL.md" ".agents/skills/mail-archive/SKILL.md"];
      };
      body = ''
        The brief asked for the new leads of a 25p attention sweep. There is no such artifact, and the
        ledger says why: 25p was a Stepstone board pass whose note filed eight rows, a parallel pane added
        three, and origin scout-2026-11-25p now holds eleven rows over eleven distinct companies. Nothing
        was inserted, because re-upserting a filed row nulls the columns a sparse record omits.
        The four the p note parked — Heimerle + Meule, HDI, Fabasoft, S Rating — are not rows by design:
        apps:scout:parked carries them by validThrough and files none inside the 2026-12-07 hold. Heimerle,
        Fabasoft and S Rating are absent from the ledger; HDI exists already from the 25s pane.
        Mail is the half with news. The archive links 455 messages to rows and application-attention is
        empty, but the replies that decide a row sit unlinked, so the search was employer token against
        emails since 2026-10-15. Ten decision mails came back: six Canonical "we regret" notices on
        2026-11-22 and 2026-11-23, Adyen's "not to move forward", freicon already rejected, a Call for
        Papers verdict, and acknowledgements from Bechtle, NETWAYS, GlobalLogic, Mittwald and others.
        Closed: the applied Canonical row and the applied Adyen row, both at Rejected 2026-11-23 with no
        next action, which keeps both employers out for 180 days. Nothing else moved; an acknowledgement is
        not a decision and a stage is not changed to look tidy.
        Open: roughly two hundred applied rows have an acknowledgement and no verdict, and the sync queue
        stays empty because the mail never linked, so the next pass searches by employer name, not by queue.
        Exit: two rows closed, zero leads inserted, zero sends.
      '';
    };
    job-scout-sweep-2026-11-25s = {
      title = "Six of 256 cards survive the hold, and the dedupe is the finding";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Stepstone's six lane queries at two pages each gave 256 unique ads; 85 sat at employers the ledger already holds, including one only a house-token match caught (Xempus AG against the held Xempus Deutschland GmbH). Six rows outlive the 2026-12-07 hold and are filed at scout-2026-11-25s; three are parked on an expiry inside it. The German feed was byte-identical for the fourth cycle.";
      from = ["job-lane-scout-2026-11-25"];
      refs = {
        modules = ["scripts/task/apps-scout.sh"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:scout:parked"];
        docs = [".agents/skills/apps/SKILL.md" "docs/task-control-plane.md"];
      };
      body = ''
        Read on 2026-11-25 in the four families. The 25r id was already claimed in the turn log
        by another lane, so this pass reads the boards itself and files under its own origin,
        scout-2026-11-25s, where two lanes cannot write one cycle.

        What each board answered. germantechjobs rss.xml: 4.4 MB, 586 items, sha256 cf313395 —
        the same hash for the fourth cycle, so the feed is flat, not empty. Stepstone: six lane
        queries at two pages each, 25 cards a page, 256 unique ads. arbeitnow page one returned
        300 rows and remoteok 101; both are US-weighted and neither added an employer the
        ledger lacks.

        The dedupe is the finding. 85 of 256 cards sat at employers already on the ledger, which
        is why the page reads like a market and is not one. One card proves the house-token
        rule: Xempus AG carries the same posting as the held Xempus Deutschland GmbH, and an
        exact-name match would have filed it twice. plusserver, Interhyp, Upvest, KNIME, Diehl
        Defence, ABOUT YOU and Bundesdruckerei fell to the same read.

        Filed at scout-2026-11-25s, each posting outliving the hold: Delos Cloud SRE (Walldorf,
        12-15), Next Kraftwerke Team Lead IT Infrastructure (Köln, 12-12), KubeOps DevOps
        Kubernetes (Balingen, 12-12), Quantum-Systems IT Infrastructure & Security (Gilching,
        12-21), Trianel Cloud Engineer Azure (Aachen, 12-25), HDI Agentic Platform Engineer
        (Hannover, 2027-01-02). Fits 5, 5, 4, 4, 4, 4; nothing sends before 2026-12-07.

        Parked, not filed, expiry inside the hold: grinnberg, meinestadt.de, S Rating.
        Taskfile: apps:scout:sweep carries 25s as its cycle and this pass's numbers,
        apps:scout:parked the three new dates beside the eleven from 25o.

        Gate: task --list-all parses the shard, apps:scout:sweep prints 25s, apps:scout:parked
        prints fourteen rows, and the six rows read back from the ledger at origin
        scout-2026-11-25s.
      '';
    };
    job-lane-scout-2026-11-25 = {
      title = "The four lanes were already on the ledger; the site now says them the way the ads do";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Reading the ledger for the four lanes returns 78 live leads — platform 26, devops 24, infrastructure 20, sre 8 — with devops carrying most fit-5 rows and no employer holding two live rows. The site and every CV now name those lanes and the stack the ads lead with, and the published fleet count is twenty-five, not thirteen.";
      from = ["job-cv-refresh-2026-11-25"];
      refs = {
        modules = ["lib/matt-site.nix"];
        tasks = ["matt:build" "apps:scout" "checks:images"];
        docs = ["docs/cv-ats-compliance.md" ".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Read, not re-swept. The 25r network pass was already claimed in the turn log by another
        lane, so this turn asked the ledger instead of the boards: family and status ride on the
        row, which makes the lane set queryable without touching a feed twice.

        What the ledger says: 78 rows with a live lead status across the four families — platform
        26, devops 24, infrastructure 20, sre 8. At fit 5 devops carries eight against platform's
        three, so DevOps is where the ads and this profile already agree. Kubernetes, Linux,
        Azure, Terraform and GitOps are the asks that recur in the role strings.

        Dedupe: every employer with more than one row is already settled — the superseded row says
        Duplicate, Merged or Closed and names the survivor — so the live set has no employer twice,
        and nothing was merged here. No row was filed from a listing alone.

        What changed, both locales in step: the target line every CV prints names DevOps, SRE,
        platform and infrastructure with Kubernetes or OpenShift, Terraform and GitOps on GCP or
        Azure, Linux estates on-prem or in the cloud; the hire section says the same in prose. The
        published fleet count moved from thirteen to twenty-five, the NixOS count in the
        inventory, and the stale figure sat in seven files at once — site, cases, project and both
        CV records.

        The lead list stayed out. Counts and lane shape are what this note carries; no company name
        reaches a page, because a public target page listing who is hiring is a list of who you are
        writing to.

        Gate: nix build .#sites.matt-site — six CVs at 2/2/1/1/1 pages against their budgets and
        cv-ats-check green on all six; task checks:images — 772 rows, 772 assets, same paths and
        bank URLs. Publishing is not in this turn: matt:deploy:prod is the destructive step, and
        agents:cv:publish-check is the gate that runs after it.
      '';
    };
    job-cv-refresh-2026-11-25 = {
      title = "The search target moved to the lanes the ledger actually shows";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "The twenty-five-p sweep filed eleven rows whose common thread is a lane, not an employer: DevSecOps and OpenShift platform, AI platform, datacenter infrastructure, Azure Local and managed-service cloud. The site hire section and the target line every CV prints now name those lanes. No work entry changed: a lead is a prospect, not an employer, and the lead list stays off the public page.";
      from = ["job-scout-sweep-2026-11-25q"];
      refs = {
        modules = ["lib/matt-site.nix"];
        tasks = ["matt:build" "apps:scout" "career:export:en"];
        docs = ["docs/cv-ats-compliance.md" ".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Read against the scout ledger on 2026-11-25. The input is the eleven rows under origin
        scout-2026-11-25p; there is no 25r yet, the ledger's newest origin is still p, so nothing
        newer existed to read.

        Treated as evidence of a market, not of a career. What the eleven rows share is a lane, not
        an employer: DevSecOps platform (ALDB), OpenShift platform (Creditreform), AI platform (DZ
        HYP, BarmeniaGothaer, BMW), datacenter infrastructure (adesso), managed-service cloud
        (valantic), Azure Local and backup (BEW), Azure cloud (Elevion), system administration
        (essendi). That is the shape the hire section and every CV's target line now state.

        What changed is profile.json and profile.de.json, the target paragraph and the hire body,
        two locales kept in step. The CV is a projection of those files, so the narrative moved
        without touching cv.typ, the variants or the JSON Resume pin.

        What deliberately did not change: the work section. The ledger holds prospects; a work
        entry is an employer, and none was added. Publishing the lead list would also show every
        company being courted, which is a leak rather than a feature.

        Gate, before the commit: nix build .#sites.matt-site — six CVs at 2/2/1/1/1 pages against
        their budgets, cv-ats-check green on all six (headings in reading order, name in the first
        three lines, visible URLs, no hyphenated line end). The longer target grew no page.

        Open, not silently closed: the profile, cases and projects copy says thirteen machines
        while the inventory now declares 38. Left for its own pass with the CV budgets re-run.
      '';
    };
    job-scout-sweep-2026-11-25r = {
      title = "The untried boards, read: 192 ATS boards, 10,417 postings, and no employer the ledger lacks";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Asked to read the boards 25q named: the vendor careers pages and the Ashby, Personio and SmartRecruiters families. Five vendor pages read, all five already rows. The ATS families answered 192 boards and 10,417 postings, 511 of them lane-titled, from 97 employers — every employer already on the 1,283-row ledger. Zero rows filed, so no origin was written.";
      from = ["job-scout-sweep-2026-11-25q"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:vendors" "apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The correction first: apps:vendors is a printer, not a market board. It names five EU vendors whose
        work is closest to this fleet and prints their careers URLs; the three ATS families are employer
        feeds reached by slug. Both were read.
        Vendors: LINBIT, B1 Systems, Univention and Open-Xchange are rows already (Open-Xchange lead, the
        other three prep); Proxmox is parked. Proxmox's page now carries an IT Infrastructure Allrounder
        (Linux/Debian, 3+ years) — the one lane ad sitting on a parked row, held by exact name and worth a
        recheck when the hold lifts, not a row under this cycle.
        Ashby: 113 boards, 5,102 postings. SmartRecruiters: 48 boards, 5,304 postings, paginated to the end of
        each board. Personio: 31 boards and 320 postings on the first pass over the full 1,343-name set, none
        of them lane-titled. The follow-up over the 355 employers not on the ledger answered 429 on every
        request, so its silence there is rate limiting and not an empty family: that retry is owed, not done.
        511 postings carried a lane title. 250 fell outside Europe, 122 were posted after 2026-10-11 and so
        are younger than the 45-day cut, nine asked for less than two years. The rest name 97 employers —
        ICEYE, Supabase, Legora, Parasail, Mondoo, NetBird, Nord Security, Gcore, Mirantis, Doctolib,
        GetYourGuide, Langdock and the rest — and every one is already a row. The false-hold audit printed
        the matched ledger row for each, so no lead hides behind a suffix-stripped key.
        Traps recorded: SmartRecruiters capped at page one reads 100 of DeliveryHero's 795 and 100 of
        BoschGroup's 5,181, and the first read of this sweep did exactly that. Personio rate-limits a burst
        with 429, which a naive read files as an empty board. And a slug is a guess: an empty family proves
        the employer was never onboarded to it, not that it is not hiring, so this flat verdict covers a
        known-employer population and not the market.
        Zero rows filed, no origin written. Exit: the untried families are flat too, so the next live source
        is a board outside these five, or the eight 25p rows once 2026-12-07 lifts.
      '';
    };
    job-scout-sweep-2026-11-25j-freebuff = {
      title = "Boards are not drained: 20 new Stepstone employers from nine metro reads";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "25j is a closed cycle, so the freebuff pass re-read instead: nine Stepstone metro pages gave 164 unique cards, 98 lane-titled, 78 ledger dupes, 20 new employers all still live, plus gtj, BSJ, WWR and RemoteOK (15 unseen, 6 filed at 25w). Open: the 2026-12-07 hold and no email on any fresh row.";
      from = ["job-scout-next-sweep-freebuff" "job-scout-sweep-2026-11-25j"];
      refs = {
        modules = ["scripts/task/apps-db.sh" "scripts/task/appflow-send.sh"];
        tasks = ["apps:scout" "apps:send" "apps:scout:sweep"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep id 25j is a closed cycle with its own note and origin, so this freebuff-lane pass
        re-read the boards rather than mint a second meaning onto it.

        Stepstone metro pages: nine fetches, devops, platform and site-reliability across Berlin,
        Munich and Hamburg, 25 cards each. After URL dedupe 164 unique cards, 98 lane-titled by
        title, 78 matching the 1,376-row ledger by exact normalised company name. Twenty employers
        are new, and every one carries a publishToDate after today, so none is an expired ghost.

        Ranked next leads, unfiled until a detail page is read: BridgingIT Team Lead Cloud and
        DevOps (5, closes 2027-01-02), Deutsche Telekom MMS Senior Cloud and DevOps (5, 12-19),
        EDEKABANK (Senior) DevOps (5, 12-20), Interhyp Senior SRE (5, 12-20), Soley Senior Software
        and DevOps (5, 12-09), XALT Senior DevOps (5, 12-09), eos.uptrade (Senior) DevOps (5, 12-02),
        grinnberg Senior Kubernetes and Linux Platform (5, 12-12). Then Amadeus Fire twice, ICT
        Digital, Instaffo Azure Platform, Randstad Digital, Ratbacher, TECCON and operational
        services at 4. ADAC Werkstudent and Reply (Junior) drop to 3 and are not leads.

        The other four boards the same day: germantechjobs 586 items, BSJ 12, WWR 79, RemoteOK 101.
        That pass held 122 unique lane titles, 104 already ledger rows, 15 unseen, and filed six at
        origin scout-2026-11-25w: CYCAP, Airbus, DATAGROUP, Bechtle, dot-change and MUEGGE. Two of
        the unseen were not postings, a retraining course and a dual-study programme.

        Open. The 2026-12-07 apps:send hold blocks all fifteen fresh-tailor letters: nine Stepstone
        packets from 25q and six from 25w sit at prep and the send verb refuses each on the row's own
        date. The hold is not the only blocker: none of the fifteen carries an email address, so
        these are portal applications. Also open: the Personio 429 retry over non-ledger employers
        has still not run, eight Stepstone rows say language de while their letters are English,
        and the twenty employers above are the standing proof that the boards are not drained.
      '';
    };
    job-scout-sweep-2026-11-25w = {
      title = "A sixth board pass on a spent id: 1,058 postings read, six fresh leads, four packets";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Asked for sweep 2026-11-25q, which is spent (note q, 18 rows). Landed as 25w: germantechjobs, WWR, RemoteOK, BSJ, Ashby and Personio answered 1,058 postings, 129 lane-titled, 122 unique, 104 already ledger rows. Six filed at fit 3-4, four packets built, nothing sent.";
      from = ["job-scout-sweep-2026-11-25s"];
      refs = {
        modules = ["scripts/task/apps-db.sh" "scripts/task/appflow-packet.sh"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Requested as 2026-11-25q, which is spent: note q plus 18 rows at origin scout-2026-11-25q.
        So this pass lands as 25w rather than giving an accepted cycle a second meaning.

        Boards, 2026-11-25: germantechjobs 586, WeWorkRemotely 79, RemoteOK 101, Berlin Startup
        Jobs 12, Ashby 14 boards and 933 postings, Personio 5 boards and 360. That is 1,058.
        129 carried a lane title, 122 survived name plus title dedupe, 104 matched an existing
        ledger row by exact normalised name, three were US-only, fifteen employers were unseen.

        Two unseen were not postings and were not filed: LearnWise sells AWS DevOps retraining,
        Peakwork a dual-study programme. Seven stayed unfiled on merit: team lead, ERP, avionics,
        network and generalist administrator titles, none platform work.

        Six filed at origin scout-2026-11-25w: CYCAP (4, Azure platform, Personio 2542744),
        Airbus Defence and Space (4, OpenShift and Kubernetes beside vSphere, 70-100k),
        DATAGROUP Operations (3, Citrix), Bechtle Bremen (3, network and security), dot-change
        (3, senior administrator), MUEGGE (3, generalist).

        Four packets, German letters because every ad is German and three require fluency, gaps
        stated, the same 72,000 EUR ask, the ad copied beside the id, the CV projected onto it.
        Verified by pdftotext on the store artifacts: letter one page, CV two, subject and
        closing present.

        Traps. The germantechjobs detail page is a JavaScript shell, 28 to 45 words and no
        ld+json, so the ad is the feed description CDATA, 262 to 350 words with requirements
        intact; the detail fetch is the wrong instrument. A Personio row carries the position
        id, not a URL. Dedupe: a first pass matched the first four-letter token and dropped 108
        of 122, so the house token is a candidate signal, never a verdict.

        No send: the 2026-12-07 hold stands and none of the six carries an email address.
        Gate: nix-instantiate --parse, nix eval .#agentsNotes.ok, apps:audit.
      '';
    };
    job-scout-sweep-2026-11-25q = {
      title = "The 2026-11-25j request: five boards flat, zero new rows, and an id already spent";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P3";
      date = "2026-11-25";
      summary = "Asked for as 2026-11-25j, which is a closed cycle with its own note and origin, so the pass landed as 25q. All five boards were re-read and none carried a new lead: germantechjobs was byte-identical for the sixth time, Stepstone returned the same 150 ad URLs as 25p, and bsj, WeWorkRemotely and RemoteOK held only employers already on the 1,283-row ledger.";
      from = ["job-scout-sweep-2026-11-25p"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search" "apps:scout:sweep"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Requested as 2026-11-25j. That id is a closed cycle — note j, its 25k second pass, rows at origin
        scout-2026-11-25j — so this pass lands as 25q instead of overwriting accepted history, the same rename
        25n took when it collided with the pane lane. No rows were filed, so no origin was written either.
        germantechjobs answered sha256 cf313395, 586 items, byte-identical to 25i through 25p: a sixth flat hash.
        Stepstone answered all six lane queries at the same byte lengths as the 25p fetch but different hashes;
        parsing its 150 cards returned the same 150 ad URLs, so the board rotated content without adding an ad.
        berlinstartupjobs: 12 feed items, one in lane (DATATRONiQ, Cloud and DevOps, Kubernetes and Edge) and it
        is already a lead from scout-2026-11-24c; the live listing page's 25 links hold that same single ad.
        WeWorkRemotely: 77 items, 27 in lane by title, six EU-eligible, and every employer is already on the
        ledger — Grafana Labs, Wrike, Bloomreach at prep, Smartsheet, Upsun and Platform.sh.
        RemoteOK: 101 items, almost all US-only; the one Europe in-lane ad is Dropbox's Atlassian Cloud
        administrator, already a prep row.
        Zero rows filed. Nothing reached a detail page because exact-name plus house-token dedupe against the
        1,283-row ledger held every candidate first; no refusal on shape was owed.
        Exit: the lane is flat for a sixth cycle. The next pass should read a board none of the five has, or
        wait for the 2026-12-07 hold to lift and work the eight rows from 25p.
      '';
    };

    job-scout-packets-2026-11-25t = {
      title = "Four 2026-11-25p leads now carry packets, and none of them can leave the lane";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Built packets for the four highest-fit 25p rows: ALDB (5), Creditreform (5), BMW (4), DZ HYP (4). Each ad was re-read in its full JobPosting before writing, so the letter rests on the posting and not the sweep note. Routes differ — ALDB takes email, three publish portals only — and every gap is stated in the letter. Nothing sent: the hold runs to 2026-12-07 and the lane still has no send verb.";
      from = ["job-scout-sweep-2026-11-25p" "apps-lane-has-no-send-task"];
      refs = {
        modules = ["modules/plugins/appflow/packet.nix"];
        tasks = ["apps:update" "agents:apps:packet" "apps:gate:packet"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        The four are ALDB (band 5, Berlin), Creditreform (band 5, Neuss), BMW Group (band 4, Munich)
        and DZ HYP (band 4, Hamburg). The other four 25p rows stay at lead: adesso and valantic are a
        band lower, and Elevion and BEW are Azure seats whose text is thinner than the four built.

        Validity, read from each posting: ALDB 2026-12-16, BMW 2026-12-19, Creditreform 2026-12-23,
        DZ HYP 2027-01-05. All four pass the 2026-12-07 window with room for one follow-up.

        Language follows the ad, not the row: German for ALDB, Creditreform and DZ HYP, English for
        BMW, whose posting is English. Each packet is its own Typst source under
        submissions/<id>/ — letter at one page, CV at two, plus job-description.txt, lead.md and
        submission-sheet.md, so the JD a packet was built from travels with it.

        The route is part of the packet because it differs. ALDB applies by email
        (bewerbung@aldb.org, CV in German, Zeugnisse); Creditreform, BMW and DZ HYP publish portals
        and no mailbox, and BMW states that email applications cannot be considered, so its letter
        names the portal and reference 194262.

        Gaps sit in the letter, not in the interview: no Kubernetes or OpenShift ownership, no RHEL,
        Satellite or Ansible, no Azure, Databricks or AKS, no GPU cluster or CUDA/NCCL/InfiniBand
        work, no Terraform (IaC is Nix), no AWS estate. Each CV footer repeats the short version.

        Nothing sent. The hold runs to 2026-12-07, and the second block is structural: the task plane
        has no send verb, so a packet becomes a mailbox draft at best. Rows moved from lead to prep
        with the send date in next_action.

        Exit: on 2026-12-07 the four rows go applied with the sent date and a follow-up lands for
        2026-12-21; ALDB closes 2026-12-16, so its follow-up is the last move, not a second letter.
      '';
    };
    job-scout-sweep-2026-11-25p = {
      title = "The 2026-11-25p sweep: a flat feed again, eight window-safe rows, and four holds exact names miss";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "First pass run from the shard instead of a note: germantechjobs was byte-identical again (sha256 cf313395) so Stepstone carried the cycle, six lane queries gave 150 cards and 73 held, and of 32 ads read in full eight survive the 2026-12-07 window, four park on expiry, and four house-token holds exact-name matching cannot see were refused.";
      from = ["job-scout-sweep-2026-11-25o"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:scout:sweep" "apps:scout:parked" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2026-11-25p, the first run driven by apps:scout:sweep rather than by rereading a note.
        germantechjobs answered sha256 cf313395, 586 items, byte-identical from 25i through 25o after the
        www-to-apex redirect, so the feed stayed flat by hash and Stepstone carried the cycle again: six lane
        queries gave 150 cards, exact-name plus house-token dedupe against the 1,272-row ledger held 73, 32
        detail pages were read, and Amadeus Fire answered 410 Gone — a closed ad, not an empty board.
        Eight rows filed at scouted, origin scout-2026-11-25p, every one valid past the 2026-12-07 hold, each
        carrying its ad's stack in its ledger row. Four parked on the window, not merit.
        Refused: the masked-employer recruiters, and Hilti on shape (onsite workplace support, not platform).
        Four house-token holds exact-name matching cannot see: meinestadt.de runs for Schwarz Digits where
        STACKIT already holds an applied row, Interhyp Gruppe sits as Interhyp AG, Claranet GmbH hides behind
        a Claranet Italia rejection inside 180 days, Liebherr-Aerospace under Liebherr-Digital.
        Three rows at the same origin came from a parallel pane, so the ledger holds eleven at 25p.
        Follow-ups: ten nudge flags went to review_flag, 13 live rows carried a past next-action date.
        Exit: decide the eight before 2026-12-07 and recheck the parked four as they expire.
      '';
    };
    job-scout-sweep-2026-11-25p-supplement = {
      title = "The p date was already worked; the mirror pass adds Almedia and four holds the shard pass cannot see";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "The p date was already worked from the shard side; this mirror pass adds one row those eight do not name: Almedia Staff Platform Engineer, live on the employer's own Ashby board while Arbeitnow served the same ad as removed. It also records berlinstartupjobs now answering Cloudflare 403, and an acronym hole in exact-name dedupe.";
      from = ["job-scout-sweep-2026-11-25p"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:add" "apps:scout"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        job-scout-sweep-2026-11-25p landed first, from a shard driving Stepstone, and its eight rows are not
        refiled here. This pass read the mirrors instead - germantechjobs RSS, WWR, RemoteOK, Arbeitnow and
        the Ashby boards - and the only survivor is one the eight do not name: Almedia Staff Platform
        Engineer, Berlin, on-site five days, published 2026-11-17 among 40 live requisitions on the
        employer's own Ashby board. It is filed at lead under origin scout-2026-11-25p, the same date label
        the shard pass used, with a prep-only next action and nothing sent before 2026-12-07.
        Arbeitnow listed that same role as removed (410). An aggregator mirror's death closes nothing: the
        employer ATS is the authority and the mirror is a pointer, so reading 410 as "gone" would have thrown
        away the pass's one verified lead. The reverse error is what filed dive solutions unverified last
        cycle, and both are the same mistake about which source decides.
        GitHub was checked as an employer signal, not a person's profile: almedia-tm is the real org - eight
        public repos, C#, Swift and Android SDKs, last push 2026-11-16 - and holds no infrastructure code, so
        it corroborates a live engineering team and says nothing about the platform stack. It does publish
        platform-engineer-case-26-q2, likely their platform case study, which belongs in the prep.
        Exact normalized name is not knowing the employer: the germantechjobs BAMF row looked new only
        because the record says "Bundesamt fuer Migration und Fluechtlinge (BAMF)" and normalization cannot
        bridge an acronym - apps:search with the full name is the check. Cisco rows are field pre-sales,
        Airbus and Cognizant are support or delivery leads, and KIND, WALDNER and alphacaps return through
        the aggregator still refused for the reasons 25o recorded.
        Two sources stayed unread rather than empty: berlinstartupjobs answers Cloudflare 403 on the page and
        on three feed paths, so its two Kubernetes postings are unfetched, and SmartRecruiters still needs a
        company slug before any query. Neither is evidence the market is closed.
      '';
    };

    job-scout-sweep-2026-11-25q-parallel = {
      title = "The 2026-11-25q sweep: a third flat feed, eight rows of my own, and the pane lane's three under the same cycle";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Germantechjobs answered byte-identical at cf313395 for the third cycle running, so Stepstone was the live board again: six lane queries gave 143 unique cards and 22 detail reads, eight rows close after the 2026-12-07 window, six park inside it, and every other board turned up only employers the ledger already holds. A parallel pane pass read the same cycle first and filed three more rows under it.";
      from = ["job-scout-sweep-2026-11-25p"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2026-11-25q: germantechjobs answered byte-identical at sha256 cf313395 for the third cycle
        running, so the hash settles nothing and Stepstone was the live board again — six lane queries gave
        143 unique cards, 101 unheld against the 1,272-row ledger, 22 detail pages read. Eight rows were
        filed at scouted, origin scout-2026-11-25p, every one closing after the 2026-12-07 window; each ad
        was read in its own words and its stack sits in the ledger row, not here.
        A parallel pane pass read the same cycle first: eleven unique rows across both reads, three only
        there (ALDB, BEW, Elevion) and three only here (Barmenia, essendi, Stadler).
        Six parked on the window, not merit. The refusals were shape, not skill: SEW-EURODRIVE, Allgeier,
        the staffing houses (Akkodis, Amadeus Fire, Instaffo, expertplace, grinnberg, OMNIGENA), the
        plant-engineering and inspection ads, the Windows-first seats and the small-MSP admin ads.
        The other boards were a dedupe result: eleven in-lane titles at five German employers, every one
        already a row; Personio answered 302, so its zero is a redirect, not an empty board.
        Exit: eight to decide before 2026-12-07 while six expire inside it. Nothing was sent.
      '';
    };

    job-scout-sweep-2026-11-25o-supplement = {
      title = "The 25o cycle was already filed; this pass adds gematik and ELAC and corrects my Stepstone block";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "The o cycle had already landed before this pass read the record, so nothing was refiled. It adds gematik and ELAC SONAR, both verified on employer pages, refuses KIND and WALDNER after reading theirs, withholds dive solutions as unverified, and corrects my Stepstone 403 to a missing Referer header.";
      from = ["job-scout-sweep-2026-11-25o"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:add" "apps:scout" "apps:update"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        This pass ran the o boards before reading the record, which is the mistake worth recording first: the
        cycle had already landed as job-scout-sweep-2026-11-25o — seven rows at origin scout-2026-11-25n plus
        three from a parallel pane — so none of that set was refiled and that note stands untouched. This is
        the supplement, not a rerun.
        Two employers the seven do not name survived verification. gematik runs its software factory's GCP
        estate with Kubernetes, Helm and Terraform, in Berlin, on a one-year fixed term stated in the title.
        ELAC SONAR wants internal LLM and GPU infrastructure under classified-work rules in Kiel, where German
        and defence are gates rather than preferences. Both were read on the employer's own page and filed at
        lead with prep-only next actions.
        Three apparent fits died on employer pages rather than on the boards: KIND is a .NET and Azure
        release-management role demanding C1 German, WALDNER is SAP Basis over S/4HANA and BTP, alphacaps is
        Microsoft-only. VP-Systeme is temp staffing and operational services is an admin title. The ledger
        already holds Kubernauts, EMnify and Datatroniq at lead, BAMF and EOS at prep, FACT-Finder at other and
        a Cisco Isovalent row; Reddit and Render matched titles but are US-only.
        dive solutions was filed and downgraded within the same pass: its Personio job 2785181 and the tenant
        feed both answer 404 and only mirrors claim the role, so the row now says unverified instead of live
        and its next action is to find the real requisition or withdraw.
        The Stepstone correction matters more than any row. This pass called the board unreadable on a 403;
        the cycle's note has it answering 200 on the same host. Re-testing that page with a Referer header still answered 000 0 here, so the difference deserves one probe before any cycle calls the board closed. A board that refuses an anonymous curl is not a
        board that cannot be read, and the seven rows already filed from it are the proof.
        Hold: everything here is prep-only, nothing is sent before 2026-12-07.
      '';
    };
    job-scout-sweep-2026-11-25o = {
      title = "The 2026-11-25o sweep: the flat hash, the redirect trap, and the seven window-safe rows";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Germantechjobs answered byte-identical to 25m after a www-to-apex redirect, so flat was a hash again and Stepstone carried the cycle: six lane queries gave 140 cards, 96 unheld employers and 30 ads read in full, of which seven survive the 2026-12-07 window, one is held by employer dedupe and eleven park on expiry.";
      from = ["job-scout-sweep-2026-11-25n"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25o, continued from note n. germantechjobs answered 301 at www and byte-identical at
        the apex (sha256 cf313395, 586 items), so the redirect is the trap: read without -L it is a 167-byte
        body that looks like an empty board. Stepstone answered 200 on six lane queries — 140 cards, 96
        unheld against the 1,265-row ledger — and its cards sit in an embedded JSON blob keyed by
        companyName, with no JSON-LD and no anchor hrefs; a detail page needs a Referer header.
        Seven rows were filed at scouted, origin scout-2026-11-25n, each inside the 2026-12-07 window and
        each carrying its ad's stack in the ledger row. GMX/WEB.DE was the closest stack match and stayed
        held by dedupe: 1&1 Mail & Media, and the ledger holds United Internet. Eleven parked on expiry,
        not merit; the refusals were shape (VMware/Windows MSP, HCI and Veeam, Entra/Intune, a Microsoft
        hyperscaler, Azure, AD core, group IT strategy).
        A parallel pane pass filed three more rows at 04:03 and owns note n, so the ledger holds ten.
        Exit: decide these seven before 2026-12-07 while the eleven expire inside it, Stepstone read first.
      '';
    };

    job-scout-sweep-2026-11-25m = {
      title = "The 2026-11-25m sweep: the feed was flat by hash and Stepstone carried six German leads";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Germantechjobs came back byte-identical to 25i and the remote boards held nothing in lane, but Stepstone answered 200 and its own result page carried nine unheld employers; detail pages separated six real platform roles from a client placement, a junior seat, an agency and a training ad.";
      from = ["job-scout-sweep-2026-11-25l"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Scout 2026-11-25m: germantechjobs answered at sha256 cf313395 with 586 items, byte-identical to
        25i, so flat is a hash and not a judgement — 81 devops/SRE/platform/infrastructure titles left 35
        unheld rows at 32 employers, nearly all in-house Windows and VMware administration the h and l
        sweeps had already refused. The other boards answered and carried nothing in lane.
        Stepstone answered 200 this time and its embedded JSON yielded 24 listings: ten employers the
        ledger already holds and nine it did not. Each detail page was read before any row was written;
        six survived, at scouted under origin scout-2026-11-25m, each carrying its ad's stack in its ledger
        row. Refused on shape: Bertrandt (client placement), Bank11 (first experience), Ratbacher (agency),
        LearnWise (a training course), RockQ, alphacaps and sino as earlier sweeps refused them.
        Exit: Stepstone moved while the feed stayed flat, so the next sweep reads Stepstone first and
        treats a germantechjobs hash match as no evidence either way. The 2026-12-07 hold covers all six.
      '';
    };

    job-scout-sweep-2026-11-25n = {
      title = "The 2026-11-25n sweep: the feed flat by hash again, and three employers 25m counted as held";
      kind = "decision";
      status = "ACCEPTED";
      priority = "P2";
      date = "2026-11-25";
      summary = "Germantechjobs answered byte-identical and the Stepstone listing set did not change, but the re-read showed 25m had recorded three unheld employers as already in the ledger and left its ninth listing without a verdict; three rows land at scouted and Randstad Digital is refused on the live Randstad contact.";
      from = ["job-scout-sweep-2026-11-25m"];
      refs = {
        modules = ["scripts/task/apps-db.sh"];
        tasks = ["apps:scout" "apps:search"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Sweep 2026-11-25n: the feed flat at sha256 cf313395 again, and three employers 25m had counted as
        held were not. Stepstone's bytes moved (sha dc2db6c6) while its listing set did not: the same 24
        employers in the same roles, and 25m's note recorded ten of them as already in the ledger —
        Ehrhardt + Partner, Randstad Digital and Medical AI among them — judged six, refused Bertrandt and
        Bank11, and left devops excellence without a verdict.
        Three rows land at scouted, origin scout-2026-11-25n: Ehrhardt + Partner (DevOps), Medical AI
        Analytics (DevOps, GPU Kubernetes), devops excellence (DevOps, client service work), each stack in
        its ledger row. Randstad Digital is refused: a mandant search, and the ledger already holds
        Randstad Professional at contacted, which the 180-day rule extends to the group.
        Dedupe lesson: subset matching on name tokens missed Randstad Digital because its ledger entry
        carries a different second word; the house name has to be tested on its own.
        Exit: the boards are not exhausted, they did not move — the 25m gap was bookkeeping, not supply.
        The 2026-12-07 hold covers all three rows and nothing was sent.
      '';
    };
    intent-capability-spec = {
      title = "Intent and capability are declared types: the request side of a turn, as data";
      kind = "proposal";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-26";
      summary = "v0.0.1 spec landed as v1.0.0rc: flake/intents.nix declares the six intent kinds (each with a resolvable ending gate), lane capabilities keyed by xs `source`, and the admit() verdict between them. The graph carries capability/intent nodes and serves edges; checks:intents gates it; lib/quotient-hash.nix gets its first production consumer as the dedup class for re-sent dispatches.";
      from = ["agent-lane-plane" "kg-zeck-cache"];
      refs = {
        hosts = ["delphi" "frieren" "eisen"];
        modules = ["flake/intents.nix" "flake/ontology.nix" "flake/outputs.nix" "lib/knowledge-graph.nix" "lib/quotient-hash.nix" "scripts/task/intents-check.sh" "taskfiles/checks.yml"];
        tasks = ["checks:intents" "checks:ontology" "checks:quotient-hash"];
        docs = ["docs/agent-turns.md" "docs/selector-daemon-predesign.md"];
      };
      body = ''
        The gap `agent-lane-plane` measured: xs subjects are coordination
        labels, not intents — jev-decide selected 0/15 on them because nothing
        declared what an intent is. The spec makes the request side first-class
        data: an intent is `subject` + `kind` + `claims` + `gate` (resolved
        against the task list — an intent cannot promise a gate that does not
        exist); a capability is `provides` + `claims` radius + evidence `floor`
        + `via`; `admit` composes them. The canonical refusal is
        tmux-pane-steward admitting a chain-change — "route, do not execute"
        is now a predicate, not a paragraph.

        Options weighed: **A. quotient-class intent dedup — ADOPTED.** `classOf`
        keys an intent canonically (kind + sorted claims); two dispatches
        spelling the same work share a class — the duplicate-dispatch class
        this lane answered five times in one session, and the lib's first
        production consumer. Exact-match only: the class advises ("have I sent
        this"), never refuses. **B. Zeckendorf epoch ordering — DEFERRED:**
        `kg-zeck-cache` ran it and failed Kelly (589 ms vs 562 ms miss, 761 ms
        vs 35 ms hit) — a numbering in search of a table; revive only if a real
        epoch sequence appears (flake.lock update epochs). **C. Cassini
        identity as ledger checksum — DEFERRED, rides with B:** the three-window
        identity is meaningful only on a Fibonacci-partitioned table, and the
        turn ledger is not one; if B's table lands, C is its free integrity
        check.

        Fleet fit: delphi holds the ledger (`lib/agent-turns/turns.json` is its
        committed snapshot), frieren runs the gate, eisen is untouched —
        routing stays jev-decide's; this spec classifies what it routes TO.
        `checks:intents` gates the schema; `checks:ontology` proves the two new
        entity types and `serves`. 60 intent + 6 capability nodes project.
      '';
    };
    wallpaper-nixconfig-dark-publish-blocked = {
      title = "nixconfig-dark wallpaper rotation and Cloudinary publish landed";
      kind = "open";
      status = "CLOSED";
      priority = "P3";
      date = "2026-11-26";
      summary = "wallpapers/nixconfig-dark.png, lib/image-daily/briefs.json, and lib/image-daily/rotation.json landed on origin/main (b5920ed6), and task images:publish + task checks:images completed cleanly (784 assets on Cloudinary and 07b3aa80.bountystash-assets.pages.dev).";
      from = ["image-daily-queue"];
      refs = {
        hosts = ["frieren"];
        modules = [
          "lib/image-daily/rotation.json"
          "lib/image-daily/briefs.json"
          "wallpapers/nixconfig-dark.png"
          "scripts/task/images-publish.sh"
        ];
        tasks = ["images:publish" "images:wallpaper" "checks:images"];
        docs = ["taskfiles/images.yml"];
      };
      body = ''
        Landed in commit b5920ed6 on origin/main:
        - `wallpapers/nixconfig-dark.png` (1536x1024 dark Frieren constellation wallpaper)
        - `lib/image-daily/briefs.json` (`wall-nixconfig-dark` brief)
        - `lib/image-daily/rotation.json` (`2026-11-26/nixconfig-dark.png` and
          `2026-11-26/catwoman-dc.png` prepended to `wall.in`)

        Resolved 2026-11-26T22:19+01:00: `task images:publish` succeeded (784/784
        assets on Cloudinary, including `wall/2026-11-26/nixconfig-dark.png` at
        `v1795720865`, deployed to `https://07b3aa80.bountystash-assets.pages.dev`
        with HTTP 200) and `task checks:images` passed (`784 row(s), 784 asset(s)`).
      '';
    };
    freebuff-hisolutions-ag-2026-11-27 = {
      title = "HiSolutions AG Senior Kubernetes packet: built, gated, nothing sent";
      kind = "handoff";
      status = "DELIVERED";
      date = "2026-11-27";
      summary = "HiSolutions AG Senior Kubernetes/DevOps packet built, gated and published: the letter names the employer, three German CV bullets are fixed, letter-pdf-check and cv-ats-check green, checks:appflow PASS, 1-page letter / 2-page CV. Nothing sent before 2026-12-07.";
      refs = {
        modules = [
          "scripts/task/cv-ats-check.sh"
          "scripts/task/letter-pdf-check.sh"
          "scripts/task/repo-blobs.sh"
          "lib/matt/lebenslauf.json"
          "lib/matt/cv-software.de.json"
        ];
        tasks = ["checks:appflow" "matt:build" "matt:cv:check"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Landed in `0d4e0d42` (not pushed):
        - `lib/matt/lebenslauf.json` — three Bountystash bullets: final stops,
          `sops` -> `SOPS`, "inventargetriebener CI" -> "CI aus der Inventardatei",
          rebuilds stated as reproducible rather than as history.
        - `lib/matt/cv-software.de.json` — the two highlights quoting those bullets,
          in lockstep; drift fails the build with `cv-variant: not in the de corpus`.
        - `~/.config/appflow/lebenslauf.json` (live copy) took the same three fixes.
          Never `matt:gist:sync-de`: it overwrites the PII block the packet renders.

        Letter `~/.config/appflow/letters/hisolutions-ag-senior-kubernetes-expert-devops-engineer.json`:
        employer named in P5, "Beratung ist mein Handwerk", the fleet as "eine
        Deklaration: 25 NixOS-Hosts", "72.000 EUR Jahresgehalt brutto", English native;
        the Kubernetes and Terraform limits stay stated rather than dropped.

        Packet `~/.local/state/appflow/submissions/hisolutions-ag-senior-kubernetes-expert-devops-engineer`:
        anschreiben.pdf 1 page, lebenslauf.pdf 2 pages, both tagged; dir 700, files 600.
        Gates on the shipped bytes: `letter-pdf-check` ("the letter matches the record"),
        `cv-ats-check`, typst page budget, `checks:appflow` PASS. Site
        https://514b89be.matt-9pf.pages.dev redeployed; `matt:cv:check` 14 ok / 0 failed.

        Landed 2026-11-27 in `5ff0947f`. The gate this note hit is now a per-path ceiling in
        `scripts/task/repo-blobs.sh`: AGENTS.nix answers to a budget that only falls.

        Nothing is sent: `apps:send` refuses this row before 2026-12-07; hand-submit at
        https://karriere.hisolutions.com/jobs/68820855/Senior-Kubernetes-Experte-DevOps-Engineer-w-m-d-
      '';
    };
    strata-inkling-mini-2-eisen = {
      title = "Strata with Inkling Mini 2 on eisen's RX 5700";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-11-26";
      summary = "Test whether strata-engine/Inkling-2-Mini-Strata from HuggingFace loads and serves under Strata on eisen's AMD Radeon RX 5700 (gfx1010, 8 GiB VRAM) without displacing the resident Qwen3.8-Flash-Next MoE pack, and whether it beats the 19.4 tok/s decode baseline at smaller context sizes.";
      refs = {
        hosts = ["eisen"];
        modules = [
          "hosts/eisen/strata.nix"
          "hosts/eisen/llm-server.nix"
        ];
        tasks = ["checks:host"];
        docs = [
          "docs/eisen-llm-architecture.md"
          "hosts/eisen/MANUAL.md"
        ];
      };
      body = ''
        Hypothesis: strata-engine/Inkling-2-Mini-Strata
        (https://huggingface.co/strata-engine/Inkling-2-Mini-Strata) is a
        smaller MoE pack that fits in eisen's remaining page cache alongside the
        resident IQ1_M Coder (58.41 GB) at the 62.7 GiB RAM ceiling, and decodes
        faster at short context because it touches fewer experts per token.

        What to try:
        1. Pull the Inkling Mini 2 pack shards through frieren's aria2 RPC
           (same route as the Qwen3.8 pack — HF CDN throttles eisen directly,
           so fetch on frieren, copy over the tailnet).
        2. Verify shard SHA-256 against HF SHA256SUMS before any load.
        3. Add an Inkling Mini 2 serving block to hosts/eisen/strata.nix on a
           separate port (:8086) so the resident :8085 service stays up while
           the experiment runs.
        4. Benchmark with tools/strata_bench.py --runs 3 on a warm server,
           comparing chat median tok/s, 4K prompt read, and per-turn first
           token against the 2026-11-04 baseline (14.6 tok/s warm IQ1_M,
           19.4 tok/s MTP decode).
        5. Confirm the llama-swap-gaming-guard still stops strata.service on
           Steam launch — both ports must yield VRAM to Proton/Gamescope.

        Exit: tools/strata_bench.py beats the baseline on short context
        (≤4K prompt) without increasing the per-turn prefill stall count, and
        strata.service on :8085 continues serving Qwen3.8-Flash-Next unchanged.
        If the pack does not fit in remaining page cache or decode is slower,
        mark REJECTED with the number that killed it.
      '';
    };
    hisolutions-cv-prose-review-2026-11-27 = {
      title = "HiSolutions AG packet: prose pass, documents gated, CV site republished";
      kind = "handoff";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-27";
      summary = "The review closed, then a prose pass: compounds arrive whole, cv-ats-check fails on the glued text, both PDFs come from one build. matt.bountystash.com serves this corpus (site:check 35/0, six live PDFs hash-equal); nothing sends before 2026-12-07.";
      from = ["freebuff-hisolutions-ag-2026-11-27"];
      refs = {
        modules = [
          "lib/matt/lebenslauf.json"
          "lib/matt/cv-software.de.json"
          "modules/plugins/appflow/packet.nix"
          "scripts/task/cv-ats-check.sh"
          "scripts/task/letter-pdf-check.sh"
        ];
        tasks = ["checks:appflow" "checks:quick"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Closed 2026-11-27. The three debts, and how each closed:
        1. A compound broke at its hyphen. `hyphenate: false` stops Typst's hyphenation only; an
           explicit hyphen is its own break opportunity, and pdftotext's reading order drops it, so
           `Generation-Alter` arrived as `GenerationAlter`, a word no parser matches. Both packet
           templates box letter-only compounds, so `Job-Status`, `Generation-Alter` and
           `Nix-Entwicklungsumgebung` arrive whole.
        2. `cv-ats-check` could not see it: the assertion fired only on a lowercase continuation,
           which `Alter` and `Entwicklungsumgebung` are not, and its reading order had already
           dropped the hyphen. It now also requires every compound the template prints to arrive
           whole. Packet dialect only: the site's German PDFs keep that break.
        3. The letter (07:55) and the CV (08:34) came from two runs; one build stamps both.

        The prose pass: four letter lines (deployment wording, the risk-manager clause, `kein
        Quartalsprojekt`, `kommuniziere`) and both address blocks. Packet: 1 page letter, 2 page CV,
        gates green, 15/39 highlights, 4/10 projects.

        Published: `matt:deploy:prod` (03527414.matt-9pf.pages.dev), `site:check` 35/0,
        `matt:cv:check` 14/0 with all six live PDFs hash-equal, `agents:cv:publish-check` 6/6 after
        the blog's copies were refreshed; its push stays an operator step. Nothing is sent:
        `apps:send` refuses before 2026-12-07. Then hand-submit both PDFs at
        https://karriere.hisolutions.com/jobs/68820855/Senior-Kubernetes-Experte-DevOps-Engineer-w-m-d-
        and record it: `task apps:update -- <id> --status applied`.
      '';
    };

    hisolutions-packet-polish-2026-11-28 = {
      title = "HiSolutions AG packet: the letter is send-ready, the CV came from a stale working copy";
      kind = "open";
      status = "OPEN";
      priority = "P2";
      date = "2026-11-28";
      summary = "HiSolutions AG packet: the 07:52 CV came from a working copy that predated the prose review, so only the letter could ship. The polish has since landed from one current source and the 09:23 packet is send-ready; only the operator hand-submission after 2026-12-07 remains.";
      from = ["hisolutions-cv-prose-review-2026-11-27"];
      refs = {
        modules = [
          "lib/matt/lebenslauf.json"
          "lib/matt/cv-software.de.json"
          "scripts/task/appflow-packet.sh"
          "modules/plugins/appflow/packet.nix"
          "scripts/task/letter-pdf-check.sh"
        ];
        tasks = ["apps:gate:packet" "checks:appflow" "matt:cv:check"];
        docs = [".agents/skills/apps/SKILL.md"];
      };
      body = ''
        Reviewed the 07:52 packet against both corpora and the letter record: selection.json JD mode
        (12 terms, kubernetes 15.4 / cloud 12.5) keeping 2/4 projects and 2/4 Bountystash highlights,
        both document gates green. Decided then: the letter ships as written; the CV was projected
        from a working copy that predates the 2026-11-27 prose fixes, so it did not.

        Delivered since, from one current source (09:23): lebenslauf.pdf 2 p 42,258 B `54ee5a43`,
        "über zwanzig NixOS-Hosts" in place of "dreizehn", the bullets on the corpora's "CI aus der
        Inventardatei", one SOPS spelling in both languages (`c992e792`, `a3657451`), and the
        container/Kubernetes limit stated rather than softened.

        Remaining, operator only: hand-submit both PDFs after 2026-12-07 at
        karriere.hisolutions.com/jobs/68820855 and record `task apps:update -- <id> --status applied`.
      '';
    };

    lebrel-secret-rename-rejected-2026-11-28 = {
      title = "A lebrel secret rename is dropped: it deleted a bound token and nothing reads the new key";
      kind = "decision";
      status = "REJECTED";
      priority = "P3";
      date = "2026-11-28";
      summary = "An uncommitted change renamed morrow-telegram to lebrel and exported LEBREL_API_KEY into hermes' env template on a pre-rekey base without lumi; it deletes a token hosts/lumi.nix binds and nothing reads the new key.";
      refs = {
        modules = ["modules/secrets.yaml" "modules/profiles/hermes.nix" "hosts/lumi.nix"];
        tasks = ["checks:sops:drift" "checks:host"];
        docs = ["docs/sops-rekey.md"];
      };
      body = ''
        The change in the 2026-11-28 pre-merge stash deletes `morrow-telegram`, adds `lebrel`, and
        exports `LEBREL_API_KEY` into the hermes env template. `hosts/lumi.nix` binds
        `morrow-telegram` into zeroclaw-lumi.env, so the deletion breaks a live host, and the
        ciphertext predates the rekey (40 recipients, no lumi).

        Dropped. The ciphertext is archived out of the repo at
        `~/.local/state/nixconfig/secrets-lebrel-uncommitted-20261128.yaml` (mode 600, sha256
        `af0c9d60...`), still decryptable with this host's key, so a revival starts from the value:
        keep `morrow-telegram`, add `lebrel` beside it with `sops set` on current HEAD so the lumi
        recipient carries, name the consumer in the same commit, gate `checks:sops:drift` and its
        `checks:host`.
      '';
    };
    classification-gate-placement = {
      title = "Move the systemd classification gate out of host eval, or keep paying 314 MiB for its guarantee";
      kind = "proposal";
      status = "PROPOSED";
      priority = "P2";
      date = "2026-11-27";
      summary = "systemd-policy costs ~314 MiB of every host eval because its assertion force-reads the full unit set; moving it beside checks:units drops the desktop gate under 1 GiB, but enforcement then depends on wiring the new gate into CI and the deploy chain, which is why this is an operator safety call.";
      from = ["eval-cost-ladder"];
      refs = {
        modules = ["modules/systemd-policy.nix" "scripts/task/chain-profile.sh" "scripts/task/unit-gate.sh" "flake/host-check.nix"];
        tasks = ["checks:units" "checks:host"];
        docs = ["docs/control-plane-vision.md" "docs/nix-patterns.md"];
      };
      body = ''
        Reproduce the costs: `bash scripts/task/chain-profile.sh base nixos dms` with
        and without `systemd-policy` in EXTRA_NIX's hmUserFeatures force. Measured
        2026-11-27: systemd-policy is ~314 MiB of the 1176 MiB desktop gate — the
        only feature whose cost is a full-config force, because its assertion
        reads every user unit plus osConfig.systemd.services, and that read IS
        the check.

        Options:
        A. Status quo — assertion stays in the host eval. Every checks:host, CI
           hostChecks build and deploy re-gate pays the 314 MiB; a violating
           config cannot reach a switch, because every path to one forces
           assertions.
        B. Move beside checks:units — one force, two verdicts; desktop gate drops
           under 1 GiB. Safety then depends entirely on wiring, and checks:units
           is today wired NOWHERE — not CI, not the deploy chain. Moving without
           wiring is a silent enforcement regression. Wiring means the CI
           per-host job, the warm-host/activate re-gate, and a checks:quick
           smoke that keeps both honest.
        C. Enforcement flag (off local, on CI) — rejected: dev/CI drift trains
           bypassing, and the failure surfaces where it is hardest to fix.
        D. Shrink the force — rejected: the force is the check, not overhead.

        Operator decision: is 314 MiB per host eval the price of a guarantee, or
        does the fleet wire B properly? Exit if B: checks:host on a desktop under
        1 GiB AND the classification gate green in CI per host — both, never one.
        No gate change without sign-off.
      '';
    };
    workerbase-devops-submitted-2026-11-27 = {
      title = "Workerbase Senior DevOps Engineer submitted via Arbeitnow";
      kind = "handoff";
      status = "DELIVERED";
      priority = "P2";
      date = "2026-11-27";
      summary = "Arbeitnow's apply button is an Ashby form, not a mailbox, so appflow-send dies on 'names no recipient'. The 1p/2p packet went out through agent-browser on 2026-11-27, ahead of the 2026-12-07 lane hold on operator instruction; ledger applied, follow-up 2026-12-11.";
      refs = {
        modules = ["scripts/task/appflow-send.sh" "scripts/task/appflow-packet.sh"];
        tasks = ["checks:appflow"];
      };
      body = ''
        Ashby c14264f0; CV and letter attached, 72k, start 07.12.2026; Ashby confirmed.
      '';
    };
  };
}
