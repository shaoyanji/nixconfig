# AGENTS.nix — the repo's narrative knowledge as data.
{
  schemaVersion = 1;
  notes = {
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
        Delivered: home card in Nix. Remaining: `--sync-docs`/`--compile-fleet` paths once `lib/docs.nix` owns the last tables.
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
        modules = ["hosts/microvms/base.nix" "hosts/microvms/guests.nix" "modules/profiles/microvm-host.nix" "hosts/delphi/configuration.nix"];
        tasks = ["microvm:list" "microvm:start" "microvm:stop" "microvm:ssh"];
        docs = ["hosts/microvms/README.md"];
      };
      body = ''
        The shape is Stapelberg's ("Coding Agent VMs on NixOS with microvm.nix", 2026-02-01):
        a shared read-only store, explicit shares, ephemeral by default. Nothing is copied at boot.

        Two tiers, and the tier is a declaration. frieren's guests are ephemeral tooling
        (`autostart = false`, /var is tmpfs, a restart is a factory reset). delphi's sandbox is a
        service tier — `autostart = true`, 4096 MiB, two stub httpd units, Stirling PDF — because a
        reboot should bring back what the vhost serves.

        State is a named volume, never a bind mount into the host's /var.
        `persist = { hermes = {}; stirling = { size = 4096; }; }` is one ext4 image per name at
        `<stateRoot>/sandbox/volumes/<name>.img`, mkfs'd on first start, mounted at /var/lib/<name>
        and found by **label** (enumeration order is not identity). The guest owns the filesystem,
        so a service keeps its own uid and `StateDirectory` just works.

        TCG is why the guest needed a wider device timeout: systemd's 90 s expired before udev
        published the virtio-blk labels and the boot fell into emergency mode.
        `DefaultDeviceTimeoutSec = 600` there; KVM hosts untouched.

        The deck is one account, not a shell: `slides` gets a forced command to `pkgs.slides`
        (hosts/microvms/slideshow.md) with forwarding, agent forwarding, X11 and tunnels off,
        reached through a host-side `systemd-socket-proxyd` on 2222 → 192.168.83.11:22. The guest
        gains no inbound path of its own.

        Public ssh reuses 22 instead of asking the tenancy for 2222: a host account `slides`
        whose whole login is `ssh -tt` into the guest's forced command. Three things only the
        live host taught: `AuthorizedKeysFile` REPLACES the default, so the keys NixOS writes to
        `/etc/ssh/authorized_keys.d/%u` must be named back; StrictModes refuses a keys file whose
        path is not root-owned, and `/var/lib/microvms` belongs to the runner, so the hop's public
        half lives in `/srv/microvm/hop-auth`; and a fleet cert's principal is the user name, so
        this account needs `AuthorizedPrincipalsFile` listing `devji` (no wildcards there).
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
    doc-budget-ci = {
      title = "Doc budget gate in CI";
      kind = "open";
      status = "IN FLIGHT";
      priority = "P0";
      date = "2026-10-21";
      summary = "A doc-only push allocated zero runners and gated nothing; the workflow now has a `docs-budget` job that builds the same check as `task ops:docs:budget`, through one script.";
      refs = {
        modules = [".github/workflows/nixcachix.yml" "scripts/task/docs-budget.sh"];
        tasks = ["ops:docs:budget"];
        docs = [".agents/SCHEMA.md" "docs/ci-pipeline.md"];
      };
      body = ''
        Missing: the green run. The red half is proven locally — on a copy with
        AGENTS.md padded to 1300 lines, `nix build .#checks.x86_64-linux.docs-budget`
        exits 1 and names the file — but only a push proves the job executes.

        Exit: the `docs-budget` job is green on a `*.md`-only commit.
      '';
    };
    dormant-host-gates = {
      title = "Dormant host gates — minyx and cassini";
      kind = "open";
      status = "OPEN";
      priority = "P0";
      date = "2026-10-19";
      summary = "Both hosts are `preserved` and undeployed. `minyx`'s `boot.kernelPackages` collision is fixed (`mkOverride 1200`, 2026-10-19); `cassini` still needs the Linux-only `freebuff-remote` import gated.";
      refs = {
        hosts = ["minyx" "cassini"];
        modules = ["modules/profiles/base-node.nix" "modules/user/ai/freebuff-remote.nix" "hosts/minyx/configuration.nix" "hosts/cassini/configuration.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        Exit: `task checks:host HOST=<one> MODE=eval` is green (or explicitly expected-red), run by the owner when the hardware is powered on. Verification of a dormant host is the owner's call, never an agent's drive-by eval.
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
        modules = ["modules/profiles/dns-failover.nix" "hosts/frieren/dns.nix"];
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
      body = ''
        Exit: `checks:dns:failover` exits 0 (not 2); stopping frieren's resolver leaves clients resolving. `BLOCKED` names the blocker: no second always-on node is provisioned.
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
        modules = ["modules/profiles/dns-failover.nix"];
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
      body = ''
        Measured 2026-10-22: there is NO secondary. `8bd17500` (2026-10-15) removed
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
      status = "OPEN";
      priority = "P1";
      date = "2026-10-19";
      summary = "On non-NixOS hosts the field is `absent`, which can read as success. It must never claim a unit it cannot see.";
      refs = {
        modules = ["modules/services/fleet-sentinel.nix"];
        tasks = ["ops:health"];
      };
    };
    semantic-search = {
      title = "Semantic search only if it earns its keep";
      kind = "open";
      status = "PROPOSED";
      priority = "P2";
      date = "2026-10-19";
      summary = "BM25 is instant and good enough until measured misses say otherwise. Enabling embeddings by default would add a model dependency to every search.";
      refs = {
        tasks = ["dev:qmd:refresh" "checks:qmd:docs"];
      };
      body = ''
        Exit: a measured set of BM25 misses that embeddings fix. Until then `qmd embed` is optional.
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
      summary = "The queue items that landed this cycle; the ledger in AUDIT.md keeps the dates.";
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
      status = "OPEN";
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
    exp-003 = {
      title = "EXP-003 — Hotspot-failover STA (uplink of last resort)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: managed, but pointed at a phone hotspot with low priority instead of the house AP. Status: not started. Cheapest resilience win; conflicts with EXP-001/002.";
      body = ''
        **Mode:** `managed`, but pointed at a **phone hotspot** with low priority instead of the house AP.
        **Status:** not started. Cheapest resilience win; conflicts with EXP-001/002.

        **Use case.** Keep the tailnet alive when the FritzBox or its uplink dies, so remote access,
        `restic` backups, the 04:00 `system.autoUpgrade` and the host agents keep running. A laptop-with-a-
        battery plus a phone hotspot is a poor-man's 4G failover, and it is the one use of this radio that
        plays to what the hardware actually is rather than pretending it is a wired NIC.

        **Module shape.** Mostly NetworkManager profile data, which raises the interesting question of where
        that belongs: a `networking.networkmanager.ensureProfiles` block is declarative state, but the PSK is
        a secret, and `connection.autoconnect-priority` / route metric are the actual mechanism.

        ```nix
        services.fleetWifi.mode = "sta-failover";
        services.fleetWifi.staFailover = {
          ssid = "phone-hotspot";        # or discovered at runtime
          priority = 10;                 # below the house APs, above nothing else
          pskFile = null;                # never inline
        };
        ```

        **Replaces today's behaviour:** the current same-subnet standby at metric 600. This is the honest
        trade: drop a standby that provides half-failover, or keep it and skip EXP-001/002.
      '';
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
    exp-019 = {
      title = "EXP-019 — Declarative Gatus Alerting & Fleet Notifier Dispatcher (`services.fleetMonitors.alerting`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: extend services.fleetMonitors with a declarative alerting block dispatching failure and resolution events to local/tailnet notifiers (SimpleX WebSocket RPC or Telegram bot) without external SaaS dependencies. Status: design study. Motivated by Gatus journal warnings: alerting is not configured (HC-6 in HANDOFF.md).";
      refs = {
        hosts = ["frieren"];
        modules = ["modules/services/fleet-monitors.nix"];
      };
      body = ''
        **Mode.** Declarative alerting on `services.fleetMonitors`: dispatch failure and
        resolution events to a local/tailnet notifier (SimpleX webhook or Telegram), no SaaS.

        **Use case.** frieren runs Gatus on loopback 8181 across 7 endpoints; a failure is
        visible only in the local UI and the journal. Alerts should reach the SimpleX `#Fleet` group.

        **Shape.** An opt-in `alerting` block in `modules/services/fleet-monitors.nix`:
        `provider` (`custom` | `telegram` | `ntfy`), a webhook `url`/`method`/`body`/`headers`,
        and `defaultAlert = { failureThreshold = 3; successThreshold = 2; sendOnResolved = true; }`.
        Gatus supports these natively; the SimpleX client already listens on 5225.

        **Why not prod.** Payload escaping and credential hygiene; low thresholds would flood
        chat during nightly switches. Exit: an intentional unit stop produces exactly one alert
        within 30 s and one resolution notice on restart, with zero alerts during auto-upgrades.
      '';
    };
    exp-020 = {
      title = "EXP-020 — Declarative PostgreSQL Collation & Vacuum Maintenance Unit (`services.postgresMaintenance`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: scheduled autonomous verification of PostgreSQL catalog collation tracking and index health, preventing silent index corruption following glibc upgrades. Status: design study. Motivated by the glibc 2.42 vs 2.44 collation mismatch discovered on Immich DB during the 2026-10-13 backup audit.";
      body = ''
        **Mode:** scheduled autonomous verification of PostgreSQL catalog collation tracking and index health,
        preventing silent index corruption following glibc upgrades.
        **Status:** design study. Motivated by the glibc 2.42 vs 2.44 collation mismatch discovered on Immich DB
        during the 2026-10-13 backup audit.

        **Use case.** NixOS glibc upgrades update the OS collation definition. When PostgreSQL detects that the system
        glibc collation differs from the database creation catalog version, it emits warnings during `pg_dump` backups
        and runs the risk of silent B-tree index corruption for locale-sorted text columns. Manually remembering to run
        `REINDEX` and `ALTER DATABASE ... REFRESH COLLATION VERSION` after major channel upgrades is fragile. A declarative
        maintenance unit evaluates `pg_collation_actual_version()` vs catalog `collversion`, executes `REINDEX CONCURRENTLY`,
        and schedules periodic `VACUUM ANALYZE`.

        **Module shape.**

        ```nix
        services.postgresMaintenance = {
          enable = true;
          schedule = "Sun *-*-* 02:00:00"; # strictly outside 03:00-05:30 nightly backup window
          databases = [ "immich" ];        # list of databases, or "all"
          autoRefreshCollation = true;     # auto-refresh collation catalog when version drift is detected
          reindexMode = "concurrently";    # "concurrently" | "standard"
          vacuumAnalyze = true;
          maxDuration = 1800;              # abort if maintenance exceeds 30 minutes
        };
        ```

        **Evidence.** Verified on frieren (2026-10-13): `postgresqlBackup-immich.service` produced glibc 2.42 vs 2.44
        mismatch warnings. Executing `REINDEX DATABASE immich;` and `ALTER DATABASE immich REFRESH COLLATION VERSION;`
        eliminated the warning completely and brought backup duration to 3.4 seconds. Immich DB is 155 MB; full reindex
        took < 3 seconds.

        **Why it is not prod.** `REINDEX` acquires locks. If executed while Immich or Paperless is actively ingesting
        photos or documents, queries block and produce 504 gateway errors. Must run strictly outside the nightly backup
        window (03:00–05:30) and respect active PostgreSQL connections. Exit criteria: a unit that runs at 02:00 Sunday,
        verifies zero active client transactions, performs non-blocking index optimization, and records metric logs.
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
    exp-023 = {
      title = "EXP-023 — Kernel Memory-Pressure Tuning & Mainframe PSI Watchdog (`profiles.memoryPressure`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: declarative Pressure Stall Information (PSI) monitoring and proactive cgroup memory containment for mixed mainframe workloads. Status: design study. Motivated by frieren's hardware constraint (11.47 GiB RAM, 8GB disk swap, 5.7GB zram).";
      body = ''
        **Mode:** declarative Pressure Stall Information (PSI) monitoring and proactive cgroup memory containment for
        mixed mainframe workloads.
        **Status:** design study. Motivated by frieren's hardware constraint (11.47 GiB RAM, 8GB disk swap, 5.7GB zram).

        **Use case.** frieren concurrently hosts latency-sensitive streaming (Jellyfin 4K QuickSync), network routing
        (Pi-hole, Nginx, SimpleX SMP relay), and batch compute (Paperless OCR, Kiwix full-text indexing, nightly Restic drills,
        LLM agent runs). Under heavy parallel load, paging into the 8GB disk swap on `/dev/sda2` creates severe I/O stalls,
        driving memory PSI (`/proc/pressure/memory`) above 40% and inducing video playback dropouts before `systemd-oomd`
        triggers. A dedicated PSI profile configures memory pressure thresholds (`ManagedOOMMemoryPressure=kill`), sets
        `MemoryLow` protection for core services, and throttles batch worker slices.

        **Module shape.**

        ```nix
        profiles.memoryPressure = {
          enable = true;
          protectedServices = [ "jellyfin" "pihole-ftl" "unbound" "nginx" "smp-server" ];
          throttledSlices = [ "system-paperless.slice" "user-devji.slice" ];
          psiThreshold = {
            someLimit = "35%";             # memory pressure threshold over 10s window
            action = "throttle";           # "throttle" | "kill" | "notify"
          };
          zramPriority = 100;
          diskSwapPriority = 10;
        };
        ```

        **Evidence.** Kernel PSI metrics are active on frieren (`/proc/pressure/memory`). Swap layout is verified at
        5.7GB zram (`/dev/zram0`, prio 100) and 8GB disk swap (`/dev/sdb2`, prio 10).

        **Why it is not prod.** Misconfigured memory limits can inadvertently kill active operator agent sessions or
        download jobs. Requires synthetic stress testing (`stress-ng`) under active 4K video transcoding to calibrate
        kill/throttle thresholds. Exit criteria: simulated memory surge throttles background OCR while Jellyfin sustains
        continuous 4K streaming without frame drops.
      '';
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
    exp-025 = {
      title = "EXP-025 — Bare-Metal Zero-Copy `io_uring` / `splice` Static IPC Server (`services.iouStaticBridge`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: swap Nginx userspace parsing for an asynchronous, zero-copy kernel iouring daemon streaming files directly from the page cache into UNIX socket descriptors via splice(2) and sendfile(2). Status: design study. Motivated by pushing the EXP-024 UDS benchmark to bare-metal memory bus throughput.";
      refs = {
        hosts = ["frieren"];
        modules = ["lib/aki-site.nix"];
      };
      body = ''
        **Mode.** Replace Nginx userspace parsing with an `io_uring` daemon that streams files
        from the page cache into UNIX socket descriptors via `splice(2)` / `sendfile(2)`.

        **Use case.** Agents and fleet tools read multi-megabyte store payloads (closure trees,
        dependency graphs, `lib/aki-site.nix` output). Nginx on UDS still allocates buffers and
        context-switches per request; fixed-buffer rings remove the userspace copy.

        **Shape.** `services.iouStaticBridge` with `socketPath`, `entries` (`route` + `path`),
        `entriesFixedLimit` and `ringEntries`; entries may be store paths or Nix values.

        **Evidence.** `io_uring`/`splice` work on Linux 6.12+; synthetic streams reach >8.5 GB/s
        with <1% CPU versus ~2.1 GB/s for userspace web servers.

        **Why not prod.** A dedicated C/Rust daemon (`liburing`) plus an epoll fallback where
        seccomp restricts `io_uring`. Exit: `nc -U /run/iou-docs/raw.sock` answers with verified
        zero-copy execution and sub-20 µs latency.
      '';
    };
    exp-026 = {
      title = "EXP-026 — Centralized QuickSync VA-API Video & Image Processing Daemon (`services.vaapiStreamBridge`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: expose frieren's Intel UHD 620 QuickSync hardware encoder (/dev/dri/renderD128) via a coordinated worker daemon over a UNIX domain socket. Status: design study. Motivated by avoiding GPU context starvation during 4K Jellyfin streaming.";
      body = ''
        **Mode:** expose frieren's Intel UHD 620 QuickSync hardware encoder (`/dev/dri/renderD128`) via a coordinated
        worker daemon over a UNIX domain socket.
        **Status:** design study. Motivated by avoiding GPU context starvation during 4K Jellyfin streaming.

        **Use case.** frieren's Intel UHD Graphics 620 hardware handles 4K HEVC/H.264 video decoding and encoding in silicon.
        Currently, Jellyfin owns the GPU directly. When Immich runs background video transcoding or Paperless processes
        scanned PDF images, they either spin up uncoordinated software CPU FFmpeg jobs (spiking host thermals to 75°C+)
        or attempt to access `/dev/dri/renderD128` concurrently, which risks dropping frames on active 4K TV playback.
        A centralized hardware-worker daemon exposes a FIFO priority queue over a local UNIX socket: Jellyfin playback
        maintains pre-emptive priority, while background jobs submit low-priority batch transcoding jobs to QuickSync.

        **Module shape.**

        ```nix
        services.vaapiStreamBridge = {
          enable = true;
          device = "/dev/dri/renderD128";
          socketPath = "/run/vaapi/worker.sock";
          maxConcurrentTranscodes = 2;
          priorityClients = [ "jellyfin" ];
          yieldOnActivePlayback = true;
        };
        ```

        **Evidence.** `/dev/dri/renderD128` is active in group `video` (`gid 26`). Jellyfin runs with QuickSync VA-API
        active. `intel_gpu_top` confirms GPU render/video engines idle at < 5% when media is not actively transcoding.

        **Why it is not prod.** Immich and Paperless use upstream docker containers and microservices that expect local
        `ffmpeg` binaries in PATH rather than a socket client wrapper. Requires writing a transparent `ffmpeg` wrapper
        script that translates CLI calls to socket RPCs. Exit criteria: Paperless OCR and Immich video encoding complete
        using QuickSync VA-API while a live 4K 60fps stream in Jellyfin sustains zero dropped frames.
      '';
    };
    exp-027 = {
      title = "EXP-027 — Adaptive PSI-Bounded RAM-Disk Scratchpad for High-Throughput Compilations (`profiles.tmpfsBuilds`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: dynamic allocation of kernel RAM-disk tmpfs storage for Nix store builds and agent workspaces, governed strictly by kernel memory pressure (PSI). Status: design study. Motivated by protecting the 1TB SSD (/dev/sdb3) from high write amplification.";
      body = ''
        **Mode:** dynamic allocation of kernel RAM-disk tmpfs storage for Nix store builds and agent workspaces,
        governed strictly by kernel memory pressure (PSI).
        **Status:** design study. Motivated by protecting the 1TB SSD (`/dev/sdb3`) from high write amplification.

        **Use case.** Routine system rebuilds, agent shell scripts, and flake lock evaluations generate gigabytes of
        ephemeral object files and compiler artifacts in `/tmp` and `/build`. Writing these to the NVMe SSD accelerates
        NAND wear leveling, while spilling them to the 2TB HDD pool (`/dev/sda2`) severely throttles compilation speeds.
        An adaptive scratchpad module provisions a dynamic `tmpfs` build mount at `/srv/scratch`, allowing compilations
        to run at 20+ GB/s memory bandwidth. If `/proc/pressure/memory` exceeds 25%, the module dynamically spools excess
        pages into zram (`zstd`) before spilling to disk swap.

        **Module shape.**

        ```nix
        profiles.tmpfsBuilds = {
          enable = true;
          mountPoint = "/srv/scratch";
          maxMemoryPercent = 40;          # up to 4.5 GiB of frieren's 11.47 GiB RAM
          pressureCeiling = "25%";        # abort or throttle if PSI stalls exceed threshold
          cleanOnBoot = true;
          nixDaemonTmpDir = true;         # sets TMPDIR for nix-daemon builds
        };
        ```

        **Evidence.** frieren has 11.47 GiB RAM, 5.7 GiB zram swap, and an 8 GiB disk swap. Current RAM usage sits at
        ~4.9 GiB with ~6.5 GiB idle cache. Kernel PSI is active and reports 0% stall during idle periods.

        **Why it is not prod.** Large closure builds (e.g. compiling webkit or rust toolchains) can easily consume more than
        4 GiB, potentially triggering kernel OOM if `TMPDIR` fills. Requires fallback mechanics or strict memory quotas
        per build unit. Exit criteria: a 2 GiB nix build completes 4× faster in tmpfs with zero SSD writes, and safely
        falls back to disk when RAM headroom drops below 2 GiB.
      '';
    };
    exp-028 = {
      title = "EXP-028 — Autonomous Tailnet Path MTU (PMTU) & Latency Optimizer (`services.fleetMtuProbe`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: continuous background ICMP PMTU discovery and TCP MSS clamping calibration across all fleet nodes. Status: design study. Motivated by latency spikes and packet fragmentation observed on mobile edge nodes (moto).";
      body = ''
        **Mode:** continuous background ICMP PMTU discovery and TCP MSS clamping calibration across all fleet nodes.
        **Status:** design study. Motivated by latency spikes and packet fragmentation observed on mobile edge nodes (`moto`).

        **Use case.** The fleet spans heterogeneous network links: gigabit Ethernet LAN (1500 MTU), Tailscale WireGuard
        mesh (1280 MTU), Wi-Fi (1500 MTU), and mobile LTE (often 1360–1420 MTU). When mobile clients or remote hosts
        stream 4K video from frieren or pull large store closures from Harmonia (`:5000`), subtle MTU mismatches cause
        silent IP packet fragmentation, bufferbloat, and connection drops. An autonomous probe daemon periodically sends
        Do-Not-Fragment (DF) ICMP probes across all tailnet peers, measures the true Path MTU, and dynamically configures
        optimal TCP MSS clamping rules.

        **Module shape.**

        ```nix
        services.fleetMtuProbe = {
          enable = true;
          interval = "04:00";             # run daily outside peak hours
          targetHosts = [ "moto" "eisen" "stark" "demo" ];
          clampMss = true;                # inject iptables/nftables TCPMSS rules
          reportMetric = true;            # expose to Gatus monitors
        };
        ```

        **Evidence.** `ping -M do -s 1244 100.97.61.65` verifies that Tailscale WireGuard encapsulates packets with 60 bytes
        of overhead, meaning any payload over 1280 bytes fragments unless endpoints clamp MSS to 1220.

        **Why it is not prod.** Manipulating firewall MSS clamping rules dynamically without declarative pinning in
        `firewall-scope.nix` risks drifting from NixOS declarative state. Exit criteria: automated probe runs, accurately
        discovers PMTU to all reachable fleet nodes, and logs recommendations without mutating live firewall tables.
      '';
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
    exp-031 = {
      title = "EXP-031 — Declarative Nginx Rate-Limiting & Anti-Brute-Force Jail (`profiles.nginxSecurityJail`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: stateless in-memory connection throttling and burst protection for authenticated web endpoints. Status: design study. Motivated by hardening Vaultwarden, Immich, and Aki control portal against LAN brute-force.";
      body = ''
        **Mode:** stateless in-memory connection throttling and burst protection for authenticated web endpoints.
        **Status:** design study. Motivated by hardening Vaultwarden, Immich, and Aki control portal against LAN brute-force.

        **Use case.** frieren exposes Vaultwarden (:8222) and administrative portals on LAN and Tailscale. While the
        firewall interface scope restricts WAN ingress, any device on the local network (e.g. IoT devices or guest laptops)
        could attempt high-frequency credential stuffing or DoS queries. Traditional `fail2ban` parses text logs and mutates
        stateful `iptables` rules, violating NixOS declarative purity. Nginx's built-in `limit_req_zone` and `limit_conn_zone`
        provide pure, stateless, declarative in-memory rate limiting with zero kernel firewall mutation:
        - Memory-efficient binary IP hashing (10m zone stores ~160,000 unique IP states).
        - Configurable burst buffers with `nodelay` for legitimate operators.
        - Returns HTTP 429 Too Many Requests to abusive callers instantly.

        **Module shape.**

        ```nix
        profiles.nginxSecurityJail = {
          enable = true;
          zones = {
            auth = { rate = "5r/m"; burst = 10; nodelay = true; };
            api = { rate = "30r/s"; burst = 50; nodelay = true; };
          };
          protectedVhosts = [ "vault.frieren.lan" "photos.frieren.lan" ];
        };
        ```

        **Evidence.** Nginx on frieren is compiled with the `http_limit_req_module` and `http_limit_conn_module`.
        Testing confirms Nginx handles rate enforcement with < 1 µs overhead per request.

        **Why it is not prod.** Miscalibrated burst limits on Immich or Vaultwarden can break batch mobile sync (e.g.
        uploading 50 photos simultaneously from a phone companion app). Exit criteria: Vaultwarden login endpoints
        block after 10 rapid failed attempts while Immich photo background uploads continue uninterrupted.
      '';
    };
    exp-032 = {
      title = "EXP-032 — Intelligent Btrfs Metadata Rebalance & Space-Reclamation Dispatcher (`services.btrfsAutoRebalance`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: conditional, threshold-driven Btrfs block group balancing for high-churn storage pools. Status: design study. Motivated by preventing ENOSPC errors on the 2TB HDD data pool (/dev/sda2).";
      body = ''
        **Mode:** conditional, threshold-driven Btrfs block group balancing for high-churn storage pools.
        **Status:** design study. Motivated by preventing ENOSPC errors on the 2TB HDD data pool (`/dev/sda2`).

        **Use case.** frieren's 2TB HDD data pool hosts high-churn workloads: Transmission torrents, Immich media uploads,
        Paperless document conversions, and nightly Restic backup snapshots. Over months of heavy write/delete activity,
        Btrfs allocates dedicated 1 GiB data and metadata chunks that become sparsely populated. This fragmentation causes
        Btrfs to return `No space left on device` (ENOSPC) during large writes even when hundreds of gigabytes of disk
        space are reported free. An autonomous rebalance module monitors unallocated raw chunk ratios via `btrfs filesystem usage`:
        only when unallocated space drops below 10% does it invoke filtered balances (`-dusage=10`, `-musage=10`).

        **Module shape.**

        ```nix
        services.btrfsAutoRebalance = {
          enable = true;
          mounts = [ "/Volumes/data" ];
          schedule = "Sun *-*-* 01:00:00"; # strictly outside 03:00-05:30 backup window
          unallocatedThresholdPercent = 10;
          dataUsageFilter = 15;
          metadataUsageFilter = 20;
        };
        ```

        **Evidence.** `sudo btrfs filesystem usage /Volumes/data` shows that `/dev/sda2` currently has 800 GiB unallocated.
        Rebalancing full drives causes severe I/O thrashing; filtered balancing (`-dusage=10`) takes only ~45 seconds.

        **Why it is not prod.** Btrfs balance operations must NEVER overlap with active nightly backups (03:00–05:30) or
        media streaming, as balance holds filesystem transaction locks. Exit criteria: threshold evaluation correctly skips
        healthy filesystems and safely compacts sparse chunks on test filesystems without I/O regressions.
      '';
    };
    exp-033 = {
      title = "EXP-033 — Autonomous WireGuard Mesh Rekeying & Ephemeral Session Rotation (`profiles.wireguardRekey`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: declarative key generation and automated session rotation for inter-host Tailscale/WireGuard peers. Status: design study. Motivated by zero-trust fleet posture across long-running mainframe nodes.";
      body = ''
        **Mode:** declarative key generation and automated session rotation for inter-host Tailscale/WireGuard peers.
        **Status:** design study. Motivated by zero-trust fleet posture across long-running mainframe nodes.

        **Use case.** Fleet nodes communicate across physical boundaries (frieren, moto, eisen, stark) using Tailscale
        WireGuard mesh encryption. While WireGuard natively rotates 1-minute transport session keys in-band, the static
        host identity keypairs remain static indefinitely. In high-security environments, periodic identity key rotation
        ensures forward secrecy against long-term key compromise. A declarative rekeying profile coordinates with SOPS
        and age recipients, automatically generating ephemeral WireGuard keys, validating peer reachability, and gracefully
        retiring old keys.

        **Module shape.**

        ```nix
        profiles.wireguardRekey = {
          enable = true;
          interval = "monthly";
          interface = "tailscale0";
          backupOldKeys = true;
          verifyPingPeer = "100.81.170.87"; # bitlockerpremium
        };
        ```

        **Evidence.** Tailscale CLI natively supports `--authkey` renewal and local key generation via `tailscale cert`
        and WireGuard tools (`wg genkey`).

        **Why it is not prod.** Rotating host identity keys on an active mainframe can cause transient network isolation
        if peer coordination fails. Exit criteria: successful key rotation demonstrated between two test fleet nodes with
        zero connection drops on active SSH sessions.
      '';
    };
    exp-034 = {
      title = "EXP-034 — Autonomous Nix Store Derivation GC Root Ratchet (`services.gcRootPruner`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: background sweeping and pruning of orphaned auto-roots and direnv gcroots in /nix/var/nix/gcroots. Status: design study. Motivated by enforcing frieren's 34.9 GiB closure budget ceiling (closure-budgets.toml).";
      body = ''
        **Mode:** background sweeping and pruning of orphaned auto-roots and direnv gcroots in `/nix/var/nix/gcroots`.
        **Status:** design study. Motivated by enforcing frieren's 34.9 GiB closure budget ceiling (`closure-budgets.toml`).

        **Use case.** Active local development, temporary agent evaluations, and Direnv environments create symlinks in
        `/nix/var/nix/gcroots/auto/`. These auto-roots pin old derivations and build dependencies permanently in `/nix/store`,
        causing `nix-collect-garbage` to skip them. Over weeks, dead build closures accrete, threatening frieren's 34.9 GiB
        closure budget. An autonomous ratchet daemon scans `/nix/var/nix/gcroots/auto/` and per-user roots, detects broken
        symlinks or targets untouched for > 14 days, unlinks them, and verifies that frieren stays under budget.

        **Module shape.**

        ```nix
        services.gcRootPruner = {
          enable = true;
          schedule = "weekly";
          maxRootAgeDays = 14;
          dryRun = false;
          closureBudgetCeiling = "34.9G";
          targetHost = "frieren";
        };
        ```

        **Evidence.** `ls -la /nix/var/nix/gcroots/auto/` reveals symlinks pointing to old development workspaces.
        Running `find /nix/var/nix/gcroots/auto/ -xtype l` occasionally catches broken symlinks that confuse GC statistics.

        **Why it is not prod.** Care must be taken not to purge active editor environments or running agent shell roots.
        Exit criteria: safe dry-run scan correctly identifies orphaned derivation roots, followed by an automated GC pass
        that recovers > 1 GiB without invalidating active project environments.
      '';
    };
    exp-035 = {
      title = "EXP-035 — Autonomous ZRAM Compression & Swap Priority Balancer (`profiles.adaptiveZramSwap`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: dynamic kernel sysctl memory tuning and zram compression sizing governed by real-time swap churn. Status: design study. Motivated by frieren's 11.47 GiB RAM hardware boundary and dual swap tiers (5.7GB zram vs 8GB HDD swap).";
      body = ''
        **Mode:** dynamic kernel sysctl memory tuning and zram compression sizing governed by real-time swap churn.
        **Status:** design study. Motivated by frieren's 11.47 GiB RAM hardware boundary and dual swap tiers (5.7GB zram vs 8GB HDD swap).

        **Use case.** frieren runs a two-tier swap architecture: in-memory zram (`/dev/zram0`, zstd, priority 100) and disk swap
        (`/dev/sdb3`, priority 10). When parallel batch jobs spike (Paperless document OCR, heavy agent planning passes, or bulk Immich
        ingestion), the memory allocator fills the 5.7 GiB zram buffer and overflows onto disk swap. Because `/dev/sda2` is an electromechanical
        HDD pool, paging out anonymous memory blocks triggers severe kernel I/O stalls (`wa%` reaching 25-40%), causing audio/video stutter
        on 4K Jellyfin playback. An adaptive balancer daemon monitors swap tier utilization: when zram reaches 75% capacity, it dynamically
        adjusts `vm.swappiness` from 60 down to 10 and increases zram compressed block device limits, confining transient memory spikes entirely
        to CPU-compressed memory and shielding the storage drives from paging contention.

        **Module shape.**

        ```nix
        profiles.adaptiveZramSwap = {
          enable = true;
          maxZramPercent = 50;            # allow zram to expand dynamically up to 5.7 GiB
          algorithm = "zstd";
          fallbackDiskPriority = 10;
          swappinessCeiling = 60;
          swappinessFloor = 10;
          throttleThresholdPercent = 80;  # lower swappiness when zram exceeds 80%
        };
        ```

        **Evidence.** Ground truth on frieren: `swapon -s` confirms `/dev/zram0` (5.7 GiB, prio 100) and `/dev/sdb2` (8 GiB, prio 10).
        Current idle memory usage sits at ~4.9 GiB with 0 bytes paged to disk. `vm.swappiness` is currently set to kernel default 60.

        **Why it is not prod.** Dynamically modifying `vm.swappiness` via sysctl and resizing zram block devices at runtime requires testing
        under artificial memory exhaustion (`stress-ng --vm 2 --vm-bytes 4G`) to ensure kernel zram driver does not panic or trigger premature OOM.
        Exit criteria: synthetic memory surge cleanly compresses into zram with zero bytes leaked to HDD swap, maintaining Jellyfin 4K stream
        continuity with 0 dropped frames.
      '';
    };
    exp-036 = {
      title = "EXP-036 — Declarative Encrypted DNS Upstream Multiplexer with Circuit-Breaking (`profiles.secureDnsUpstreams`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: declarative DNS-over-TLS (DoT) and DNS-over-HTTPS (DoH) forwarder pool in Unbound with automated latency scoring and health failover. Status: design study. Motivated by eliminating unencrypted WAN DNS recursion and improving edge query latency.";
      body = ''
        **Mode:** declarative DNS-over-TLS (DoT) and DNS-over-HTTPS (DoH) forwarder pool in Unbound with automated latency scoring and health failover.
        **Status:** design study. Motivated by eliminating unencrypted WAN DNS recursion and improving edge query latency.

        **Use case.** frieren runs Pi-hole FTL backed by Unbound on port 53. Currently, Unbound either performs full root iterative recursion
        or forwards plain UDP/TCP queries. Plain DNS queries to external providers are susceptible to ISP inspection, interception, and transient
        UDP packet drops. A declarative upstream multiplexer profile configures Unbound to query multiple authenticated DoT/DoH endpoints
        (Quad9 `9.9.9.9@853#dns.quad9.net`, Cloudflare `1.1.1.1@853#cloudflare-dns.com`, Mullvad) over TLS. The module includes an automated
        latency probe unit that measures round-trip handshake times every 6 hours, circuit-breaking degraded upstreams and prioritizing the fastest
        resolver without manual intervention.

        **Module shape.**

        ```nix
        profiles.secureDnsUpstreams = {
          enable = true;
          protocol = "dot";               # "dot" (port 853) | "doh" (port 443)
          upstreams = [
            { name = "quad9-primary"; addr = "9.9.9.9"; port = 853; hostname = "dns.quad9.net"; }
            { name = "cloudflare-primary"; addr = "1.1.1.1"; port = 853; hostname = "cloudflare-dns.com"; }
            { name = "mullvad-primary"; addr = "194.242.2.3"; port = 853; hostname = "dns.mullvad.net"; }
          ];
          circuitBreakerLatencyMs = 120;  # disable upstreams with latency > 120ms
          fallbackToRootIterative = true; # fall back to local root hints if all DoT providers fail
        };
        ```

        **Evidence.** Unbound on frieren (`services.unbound`) is compiled with `libevent` and OpenSSL TLS support. Testing confirms port 853
        outbound TCP is permitted through the interface firewall scope.

        **Why it is not prod.** If TLS certificate validation fails during boot before system time is synchronized via NTP, Unbound will fail
        to resolve DNS, preventing NTP from synchronizing time (chicken-and-egg failure). Requires strict fallback to iterative root hints or
        hardcoded fallback addresses. Exit criteria: verified TLS-encrypted DNS resolution with < 25ms latency, validated failover to secondary
        provider during simulated upstream blackhole, and zero boot-time deadlocks.
      '';
    };
    exp-037 = {
      title = "EXP-037 — Autonomous Btrfs Snapshot Retention & Capacity Ratchet (`services.snapshotRatchet`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: multi-tier declarative Btrfs subvolume snapshot lifecycle manager with emergency capacity-driven space reclamation. Status: design study. Motivated by preventing ENOSPC conditions caused by heavy snapshot accumulation on /dev/sda2 (2TB HDD) and /dev/sdb3 (1TB SSD).";
      body = ''
        **Mode:** multi-tier declarative Btrfs subvolume snapshot lifecycle manager with emergency capacity-driven space reclamation.
        **Status:** design study. Motivated by preventing ENOSPC conditions caused by heavy snapshot accumulation on `/dev/sda2` (2TB HDD) and `/dev/sdb3` (1TB SSD).

        **Use case.** frieren utilizes Btrfs subvolumes for `@root`, `@home`, `@snapshots`, and the 2TB data pool `/Volumes/data`. Automated snapshots
        protect against accidental file modification and ransomware. However, high-volume write activities (e.g. Immich video library additions,
        large Torrent transfers, or Paperless batch OCR) can quickly balloon snapshot exclusive block sizes (`btrfs qgroup show`). If available
        unallocated space falls below 5%, Btrfs refuses new writes and can lock into read-only mode. An autonomous snapshot ratchet daemon enforces
        strict retention windows (hourly: 24, daily: 7, weekly: 4), while continuously monitoring pool headroom: if free capacity drops below 10%,
        the ratchet progressively prunes the oldest daily/hourly snapshots until safe headroom (> 15%) is restored.

        **Module shape.**

        ```nix
        services.snapshotRatchet = {
          enable = true;
          mounts = [ "/" "/Volumes/data" ];
          retention = {
            hourly = 24;
            daily = 7;
            weekly = 4;
            monthly = 3;
          };
          headroomEmergencyThresholdPercent = 8;
          targetHeadroomPercent = 15;
          dryRun = false;
          schedule = "*-*-* 01:00:00";    # before 03:00 backup window
        };
        ```

        **Evidence.** Btrfs subvolume layout on frieren: `/dev/sdb3` SSD (923 GB) and `/dev/sda2` HDD (1.8 TB). Snapper and custom snapshot
        scripts create snapshots in `/.snapshots` and `/Volumes/data/.snapshots`.

        **Why it is not prod.** Uncontrolled snapshot deletion could accidentally delete recent restore points if threshold calculations confuse
        sparse allocations with real usage. Requires dry-run verification and assertions ensuring the latest snapshot is NEVER purged. Exit
        criteria: scheduled test on a test subvolume successfully retains declared generation counts, safely prunes excess snapshots upon
        simulated disk saturation, and logs a full audit trail.
      '';
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
    exp-039 = {
      title = "EXP-039 — Declarative Tailnet Subnet Router & Multicast DNS (mDNS) Reflector Gateway (`services.fleetMdnsReflector`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: bridged mDNS service discovery across physical LAN interfaces (enp1s0) and the virtual Tailscale mesh (tailscale0). Status: design study. Motivated by providing zero-configuration service discovery (.local domains) for roaming fleet devices.";
      body = ''
        **Mode:** bridged mDNS service discovery across physical LAN interfaces (`enp1s0`) and the virtual Tailscale mesh (`tailscale0`).
        **Status:** design study. Motivated by providing zero-configuration service discovery (`.local` domains) for roaming fleet devices.

        **Use case.** When laptops (`minyx`, `stark`) and mobile phones roam outside the home network, they connect to frieren via Tailscale WireGuard.
        However, multicast DNS (mDNS, `224.0.0.251:5353`) and DNS-SD packets are link-local and do not route across point-to-point WireGuard VPN
        tunnels. As a result, roaming devices cannot automatically discover local services (Jellyfin media server, Home Assistant cast targets,
        Harmonia binary cache, Aki portal) using standard `.local` hostnames or ZeroConf discovery protocols. A declarative reflector gateway
        utilizes Avahi's reflector mode or a lightweight unicast mDNS repeater daemon, bridging service announcements between `enp1s0` and `tailscale0`
        with strict interface filtering to prevent multicast loops.

        **Module shape.**

        ```nix
        services.fleetMdnsReflector = {
          enable = true;
          interfaces = [ "enp1s0" "tailscale0" ];
          reflectAcrossTailnet = true;
          allowedServices = [ "_http._tcp" "_jellyfin._tcp" "_home-assistant._tcp" ];
          preventBroadcastStorms = true;
        };
        ```

        **Evidence.** `avahi-daemon` is already running on frieren for LAN service discovery. Tailscale interface `tailscale0` is active and
        has IP `100.97.61.65`.

        **Why it is not prod.** Misconfigured mDNS reflectors on dual-homed machines can trigger packet amplification loops (multicast storm)
        that flood Wi-Fi interfaces and degrade network throughput. Requires strict duplicate-detection filters and packet TTL clamping. Exit
        criteria: a remote laptop connected exclusively via Tailscale successfully resolves `frieren.local` and auto-discovers the Jellyfin
        server without manually specifying an IP address.
      '';
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
    exp-041 = {
      title = "EXP-041 — Declarative Jellyfin Hardware Transcoding Priority & Throttle Manager (`services.jellyfinGpuGovernor`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: dynamic nice/cgroup I/O throttling and QuickSync concurrency limits during parallel batch jobs. Status: design study. Motivated by avoiding GPU/disk contention during 4K TV video playback.";
      body = ''
        **Mode:** dynamic nice/cgroup I/O throttling and QuickSync concurrency limits during parallel batch jobs.
        **Status:** design study. Motivated by avoiding GPU/disk contention during 4K TV video playback.

        **Use case.** frieren is connected directly to a Philips 65" 4K TV over HDMI (`3840x2160 @ 30 Hz`) and serves Jellyfin media streams
        via Intel UHD 620 QuickSync hardware transcoding (`/dev/dri/renderD128`). Concurrently, frieren runs heavy background batch compute:
        Paperless OCR, Immich face recognition, Kiwix full-text search indexing, and LLM agent planning sessions. When batch workers spin up,
        memory bus bandwidth and GPU execution units become saturated, inducing video playback stutter and dropped frames on the living room display.
        A GPU governor monitors active Jellyfin playback sessions via the Jellyfin local REST API: when an active transcode or direct playback session
        is detected, the governor dynamically lowers batch service cgroup weights (`CPUWeight=10`, `IOWeight=10`) and throttles background FFmpeg jobs.

        **Module shape.**

        ```nix
        services.jellyfinGpuGovernor = {
          enable = true;
          jellyfinUrl = "http://127.0.0.1:8096";
          throttledServices = [ "paperless-task-queue" "immich-machine-learning" ];
          idleCpuWeight = 10;
          activePlaybackPriority = "realtime";
          pollIntervalSec = 15;
        };
        ```

        **Evidence.** `/dev/dri/renderD128` is actively mapped in `media-stack.nix`. Jellyfin runs on port 8096. Hardware profile: Intel UHD 620
        (Kaby Lake R, 24 EUs).

        **Why it is not prod.** Polling the Jellyfin API every 15 seconds requires handling authentication tokens and transient service restarts
        without spamming error logs. Exit criteria: simulated Paperless OCR load (`tesseract`) automatically yields CPU/GPU slices when a 4K
        playback session starts in Jellyfin, sustaining 0 dropped frames.
      '';
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
    exp-043 = {
      title = "EXP-043 — Autonomous Network Namespace Sandboxing for Headless Torrents (`profiles.transmissionVpnJail`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: deterministic network namespace binding routing Transmission traffic exclusively through WireGuard with kill-switch assertions. Status: design study. Motivated by preventing accidental IP leakage during open-source ISO distribution and media transfers.";
      body = ''
        **Mode:** deterministic network namespace binding routing Transmission traffic exclusively through WireGuard with kill-switch assertions.
        **Status:** design study. Motivated by preventing accidental IP leakage during open-source ISO distribution and media transfers.

        **Use case.** Transmission daemon runs on frieren for background Linux ISO distribution and media downloading. Currently, it binds host
        network interfaces under ingress firewall filtering. In privacy-conscious architectures, torrent traffic must route exclusively through an
        isolated encrypted WireGuard VPN tunnel with an absolute kill-switch: if the VPN interface drops, traffic must drop rather than spilling
        onto the plain ISP network uplink. A dedicated profile constructs a dedicated Linux network namespace (`netns: transmission`), binds the
        Transmission daemon strictly inside the namespace, and routes default gateway traffic over the VPN interface with zero possibility of host leakage.

        **Module shape.**

        ```nix
        profiles.transmissionVpnJail = {
          enable = true;
          namespaceName = "vpn-jail";
          wireguardConfigFile = config.sops.secrets.vpn_wireguard_conf.path;
          allowLanPeerDiscovery = false;
          killSwitch = true;
          forwardedPort = 51413;
        };
        ```

        **Evidence.** Transmission daemon runs on frieren under `transmission.service`. Kernel network namespaces (`ip netns`) are natively
        supported in Linux 6.12+.

        **Why it is not prod.** Requires provisioning a commercial VPN WireGuard peer config, SOPS secret keying, and handling inter-namespace
        communication so local web UIs (e.g. `http://transmission.frieren.lan/`) can still communicate with the daemon inside the namespace.
        Exit criteria: Transmission runs entirely within `netns`, external IP matches VPN egress, and pulling the VPN link instantly stalls downloads
        with zero bytes leaked onto `enp1s0`.
      '';
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
    exp-047 = {
      title = "EXP-047 — Declarative Home Assistant Automation & Entity State Integrity Probe (`services.haAutomationProbe`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: automated validation of Home Assistant entity states and automation execution health over local REST API. Status: design study. Motivated by detecting broken sensors, unavailable MQTT entities, and dead automations.";
      body = ''
        **Mode:** automated validation of Home Assistant entity states and automation execution health over local REST API.
        **Status:** design study. Motivated by detecting broken sensors, unavailable MQTT entities, and dead automations.

        **Use case.** frieren runs Home Assistant Core (`services.homeAssistant`) with 53 enabled entities and 8 devices. Over time,
        Zigbee/Wi-Fi devices go offline, battery-backed sensors deplete, or template sensors fail to evaluate due to schema changes.
        Because HA is running headlessly without daily manual UI review, broken automations and unavailable entities remain undetected
        until an automation failure impacts the physical household. A declarative probe unit queries Home Assistant's local REST API
        (`http://127.0.0.1:8123/api/states`) daily: it audits all entities, flags any critical device reporting `unavailable` or `unknown`
        for > 6 hours, checks for automation trigger errors in HA logs, and emits a scorecard to `#Fleet`.

        **Module shape.**

        ```nix
        services.haAutomationProbe = {
          enable = true;
          haUrl = "http://127.0.0.1:8123";
          schedule = "daily";
          maxUnavailableHours = 6;
          criticalDomains = [ "switch" "light" "binary_sensor" "climate" ];
          alertSimpleX = true;
        };
        ```

        **Evidence.** Home Assistant is active on frieren on port 8123. REST API is available locally. Currently 53 entities are registered.

        **Why it is not prod.** Requires provisioning a long-lived access token declaratively or via SOPS to query `/api/states` without
        interactive auth prompts. Exit criteria: probe discovers 1 intentionally disconnected test entity, correctly classifies it as
        unavailable, and reports 100% health across all online devices.
      '';
    };
    exp-048 = {
      title = "EXP-048 — Transparent Hugepage (THP) & Kernel Memory Compaction Tuner (`profiles.mediaHugepages`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: targeted Transparent Hugepage (THP) allocation and memory compaction policies for 4K media streaming and large ZIM archives. Status: design study. Motivated by reducing TLB misses during 4K video transcoding and large-file memory mapping.";
      body = ''
        **Mode:** targeted Transparent Hugepage (THP) allocation and memory compaction policies for 4K media streaming and large ZIM archives.
        **Status:** design study. Motivated by reducing TLB misses during 4K video transcoding and large-file memory mapping.

        **Use case.** frieren concurrently memory-maps multi-gigabyte files: 52.7 GB Wikipedia ZIM archives (`kiwix-serve`), 4K HEVC video files
        (`jellyfin`), and Paperless document embeddings. With standard 4 KB page sizes, memory mapping a 50 GB file requires 13 million page table
        entries, saturating the CPU's Translation Lookaside Buffer (TLB) and inducing kernel page table walker overhead. Transparent Hugepages
        (2 MB pages) drastically reduce TLB misses by 500×. However, setting THP to `always` system-wide causes memory fragmentation and latency
        spikes in Redis and PostgreSQL. A specialized media profile sets kernel THP to `madvise` and configures `systemd.services.kiwix-serve`
        and `systemd.services.jellyfin` with `MemoryAccounting=true` and `madvise(MADV_HUGEPAGE)` wrappers, optimizing large memory mappings
        without bloating database workloads.

        **Module shape.**

        ```nix
        profiles.mediaHugepages = {
          enable = true;
          thpMode = "madvise";            # "always" | "madvise" | "never"
          defragMode = "defer+madvise";
          targetServices = [ "jellyfin" "kiwix-serve" ];
        };
        ```

        **Evidence.** `/sys/kernel/mm/transparent_hugepage/enabled` is currently set to `always [madvise] never` on frieren.
        `kiwix-serve` memory-maps 52.7 GB of ZIM data.

        **Why it is not prod.** If THP allocation triggers synchronous kernel compaction under low RAM conditions, media streaming can stall.
        Requires tuning `khugepaged/defrag` and measuring before/after TLB miss rates (`perf stat -e dTLB-load-misses`). Exit criteria: measured
        35% reduction in TLB misses during Kiwix search and 4K Jellyfin streaming with 0 latency spikes.
      '';
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
    exp-050 = {
      title = "EXP-050 — Autonomous Nginx SSL/TLS Certificate Expiry & OCSP Stapling Watchdog (`services.tlsCertWatchdog`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: scheduled background validation of SSL/TLS certificate expiration dates and OCSP responses across virtual hosts. Status: design study. Motivated by preventing certificate expiration from breaking background mobile client sync (Vaultwarden, Immich).";
      body = ''
        **Mode:** scheduled background validation of SSL/TLS certificate expiration dates and OCSP responses across virtual hosts.
        **Status:** design study. Motivated by preventing certificate expiration from breaking background mobile client sync (Vaultwarden, Immich).

        **Use case.** frieren terminates TLS for local reverse proxies (Vaultwarden `:8222`, Aki portal `:80/443`, monitors) and serves
        services on the Tailscale mesh (`frieren.lan`). While ACME or certificates run in the background, renewal failures, transient DNS
        validation timeouts, or clock skew can silently let certificates expire. Because server services run headlessly without browser
        interactions, expired certs go unnoticed until mobile apps (Bitwarden sync, Immich backup) fail with TLS handshake errors.
        A declarative watchdog unit runs every 12 hours: it probes declared virtual hosts and local cert files (`/srv/private/` or `/var/lib/acme`),
        asserts remaining valid days (> 14 days), tests OCSP stapling responses, and raises administrative alerts on approaching expiration.

        **Module shape.**

        ```nix
        services.tlsCertWatchdog = {
          enable = true;
          endpoints = [
            "https://vault.frieren.lan"
            "https://monitors.frieren.lan"
          ];
          certFiles = [ "/var/lib/acme/vault.frieren.lan/cert.pem" ];
          warnDays = 14;
          criticalDays = 5;
          schedule = "00/12:00:00";
        };
        ```

        **Evidence.** Nginx is active on frieren. `openssl x509 -enddate -noout -in <cert>` and `curl -vI https://...` provide immediate,
        deterministic certificate parsing without external network dependencies.

        **Why it is not prod.** Probing local HTTPS endpoints requires resolving hostnames via local DNS and handling self-signed certificates
        gracefully without spurious warnings. Exit criteria: scheduled unit tests declared certificates, accurately flags a simulated 5-day
        expiring certificate, and completes in < 500ms with zero production interference.
      '';
    };
    exp-051 = {
      title = "EXP-051 — Declarative Host Thermals & Dynamic Fan Curve Governor (`services.thermalGovernor`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: real-time core temperature telemetry from sysfs (/sys/class/thermal) and predictive throttling under sustained 4K encoding. Status: design study. Motivated by preventing thermal throttling dropouts on the Lenovo IdeaPad 320 laptop-as-server hardware.";
      body = ''
        **Mode:** real-time core temperature telemetry from sysfs (`/sys/class/thermal`) and predictive throttling under sustained 4K encoding.
        **Status:** design study. Motivated by preventing thermal throttling dropouts on the Lenovo IdeaPad 320 laptop-as-server hardware.

        **Use case.** frieren runs 24/7 on laptop hardware (Lenovo ideapad 320-15IKB, Intel Core i5-8250U). Under sustained multi-hour FFmpeg
        transcodes, Paperless batch OCR, or local Nix rebuilds, CPU thermals can reach 75–80°C. If the single laptop fan cannot dissipate heat,
        the CPU throttles its clock down to 800 MHz, inducing audio/video playback stutter on 4K Jellyfin output. A lightweight governor daemon
        monitors thermal zones (`/sys/class/thermal/thermal_zone*/temp`): when temperatures exceed 72°C, it modulates Intel P-state energy
        performance preferences (`/sys/devices/system/cpu/cpu*/power/energy_perf_bias`) to drop CPU package wattage from 15W to 10W, preventing
        thermal throttling spikes while maintaining smooth media playback.

        **Module shape.**

        ```nix
        services.thermalGovernor = {
          enable = true;
          highTempCelsius = 72;
          criticalTempCelsius = 80;
          throttleAction = "bias-power";   # "bias-power" | "cap-frequency" | "nice-batch"
          pollIntervalSec = 30;
          logMetrics = true;
        };
        ```

        **Evidence.** Sysfs thermals are readable on frieren (`cat /sys/class/thermal/thermal_zone0/temp` reports ~34°C during idle).
        Intel Core i5-8250U supports hardware P-state energy performance bias.

        **Why it is not prod.** Aggressive thermal capping could unnecessarily throttle legitimate fast builds when ambient temperatures
        are low. Requires calibrating hysteresis margins so governor does not oscillate every few seconds. Exit criteria: simulated CPU load
        (`stress-ng --cpu 4`) smoothly lowers energy performance bias when 72°C is crossed, capping thermals without dropping clock below 1.6 GHz.
      '';
    };
    exp-052 = {
      title = "EXP-052 — Autonomous ZRAM Decompression Latency & Memory Reclamation Drill (`services.zramPerfDrill`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: periodic synthetic memory compression/decompression benchmark verifying zram throughput on Linux 6.12. Status: design study. Motivated by ensuring CPU-compressed memory operates faster than NVMe storage.";
      body = ''
        **Mode:** periodic synthetic memory compression/decompression benchmark verifying zram throughput on Linux 6.12.
        **Status:** design study. Motivated by ensuring CPU-compressed memory operates faster than NVMe storage.

        **Use case.** frieren allocates 5.7 GiB to `/dev/zram0` using zstd compression. As the system runs for weeks across diverse memory
        churn (PostgreSQL, Paperless, Gatus, agent processes), kernel memory allocator fragmentation or CPU lock contention can degrade
        zram throughput below expected performance levels. A monthly drill runs non-destructive, isolated memory compression benchmarks:
        it writes and reads a 64 MB synthetic memory pattern to `/dev/zram0`, calculates compression ratio and read/write bandwidth, asserts
        throughput > 3.0 GB/s, and verifies zero kernel page allocation failures, proving zram memory health.

        **Module shape.**

        ```nix
        services.zramPerfDrill = {
          enable = true;
          schedule = "monthly";
          benchmarkSizeMb = 64;
          minThroughputGbps = 3.0;
          maxLatencyMs = 25;
          notifyOnDegradation = true;
        };
        ```

        **Evidence.** `/dev/zram0` is active on frieren (`swapon -s` shows 5.7 GiB, prio 100). Kernel 6.12 implements multi-stream zstd
        compression algorithms.

        **Why it is not prod.** Generating synthetic memory churn must never trigger memory eviction or OOM on production services. Must
        verify sufficient free RAM headroom (> 2 GiB) before running the drill. Exit criteria: monthly drill completes in < 3 seconds,
        reports > 3.5 GB/s memory throughput, and exits cleanly with zero page leaks.
      '';
    };
    exp-053 = {
      title = "EXP-053 — Declarative Pi-hole Gravity Sync & Adlist Drift Reconciliation (`services.gravitySync`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: automated reconciliation of blocklist definitions, whitelist domains, and gravity database optimization. Status: design study. Motivated by preventing stale blocklists and DNS recursion timeouts.";
      body = ''
        **Mode:** automated reconciliation of blocklist definitions, whitelist domains, and gravity database optimization.
        **Status:** design study. Motivated by preventing stale blocklists and DNS recursion timeouts.

        **Use case.** Pi-hole FTL runs on port 53. Gravity updates (`pihole -g`) update domain blocklists weekly. When upstream adlist URLs
        return HTTP 404 or transient timeouts, Gravity drops existing lists or accretes stale domain hashes. A declarative reconciliation
        module checks adlist HTTP availability, runs gravity updates outside peak hours, and verifies that recursive query latency stays < 15ms.

        **Module shape.**

        ```nix
        services.gravitySync = {
          enable = true;
          schedule = "Sun *-*-* 03:15:00"; # strictly outside 03:00 backup window
          adlists = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
          verifyDnsLatency = true;
          maxLatencyMs = 25;
        };
        ```

        **Evidence.** Pi-hole gravity database is `/var/lib/pihole/gravity.db` (8.7 MB, 87,000+ domains). `task checks:dns:failover`
        verifies local resolution.

        **Why it is not prod.** Gravity database rebuild acquires database locks on `gravity.db`, which can briefly stall DNS lookups for LAN
        devices. Must run during the quietest night hour and verify fast post-rebuild DNS query response. Exit criteria: scheduled unit
        reconciles adlists, runs Gravity rebuild, and confirms sub-10ms DNS resolution on `127.0.0.1:53`.
      '';
    };
    exp-054 = {
      title = "EXP-054 — Declarative Automated Flake Input Dependency Graph & Security Vulnerability Matrix (`services.flakeMatrixRepor";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: autonomous derivation tree graphing and CVE impact matrix visualization for the Aki fleet portal. Status: design study. Motivated by creating an offline visual control plane for fleet package closures.";
      refs = {
        hosts = ["frieren"];
        modules = ["lib/aki-site.nix"];
      };
      body = ''
        **Mode:** autonomous derivation tree graphing and CVE impact matrix visualization for the Aki fleet portal.
        **Status:** design study. Motivated by creating an offline visual control plane for fleet package closures.

        **Use case.** frieren compiles the Aki fleet documentation hypermedia tree (`lib/aki-site.nix`) over UDS socket. Incorporating an
        automated dependency graph generator that visualizes all fleet host closures and evaluates CVE vulnerabilities creates an offline,
        interactive visual control plane for fleet health.

        **Module shape.**

        ```nix
        services.flakeMatrixReport = {
          enable = true;
          schedule = "weekly";
          outputDir = "docs/matrix";  # repo-relative
          targetHosts = [ "frieren" "minyx" "eisen" "stark" ];
          generateGraph = true;
        };
        ```

        **Evidence.** `lib/aki-site.nix` is already compiled into `/nix/store` and served over `unix:/run/uds-docs/docs.sock`.
        Flake evaluation across all hosts is supported natively.

        **Why it is not prod.** Generating full derivation graphs for 4 hosts can produce multi-megabyte SVG/DOT files that take compute
        to render. Requires caching and delta generation. Exit criteria: weekly unit builds dependency matrix and embeds interactive graph
        into Aki portal with zero build regressions.
      '';
    };
    exp-055 = {
      title = "EXP-055 — Declarative InfluxDB Retention & Metrics Aggregation Compaction Drill (`services.metricsRetentionDrill`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: scheduled retention validation and TSM shard compaction for time-series telemetry storage. Status: design study. Motivated by preventing time-series disk bloat and slow historical dashboard queries.";
      body = ''
        **Mode:** scheduled retention validation and TSM shard compaction for time-series telemetry storage.
        **Status:** design study. Motivated by preventing time-series disk bloat and slow historical dashboard queries.

        **Use case.** frieren runs InfluxDB (`:8086`) storing system performance counters, disk I/O metrics, and Home Assistant sensor
        histories. Over months of 24/7 logging, high-resolution metric data accretes rapidly across Btrfs storage pools, causing multi-gigabyte
        TSM shard directories and slow query responses for historical dashboard graphs. A declarative retention policy reconciles measurement
        retention rules (raw 1-second metrics retained 7 days, 1-minute downsampled rollups retained 90 days), compacts cold TSM shards, and
        validates continuous query execution outside peak hours, maintaining tight storage footprints.

        **Module shape.**

        ```nix
        services.metricsRetentionDrill = {
          enable = true;
          schedule = "Sun *-*-* 03:45:00"; # strictly outside backup window
          influxEndpoint = "http://127.0.0.1:8086";
          retentionPolicies = {
            "autogen" = "168h"; # 7 days for high-resolution counters
            "downsampled" = "2160h"; # 90 days for rollups
          };
          compactColdShards = true;
        };
        ```

        **Evidence.** InfluxDB is active on frieren (`systemctl is-active influxdb`). Data directory `/var/lib/influxdb` contains WAL and TSM shards.

        **Why it is not prod.** TSM shard compaction generates intensive disk writes. Must run with low I/O priority (`ionice -c 3`) and assert
        zero concurrent backup tasks. Exit criteria: scheduled unit validates retention policies, compacts shards in < 15 seconds, and frees
        at least 15% TSM storage with 0 query errors.
      '';
    };
    exp-056 = {
      title = "EXP-056 — Declarative Paperless OCR Language Pack & Model Drift Reconciler (`services.paperlessOcrAudit`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: scheduled validation of Tesseract language traineddata models and OCR accuracy across document ingestion queues. Status: design study. Motivated by preventing silent OCR fallback to lossy ASCII recognition on foreign-language documents.";
      body = ''
        **Mode:** scheduled validation of Tesseract language traineddata models and OCR accuracy across document ingestion queues.
        **Status:** design study. Motivated by preventing silent OCR fallback to lossy ASCII recognition on foreign-language documents.

        **Use case.** frieren processes scanned physical documents and PDFs using Paperless-ngx and Tesseract OCR (`tesseract`).
        Over months of system upgrades or manual document imports, documents scanned in German, Japanese, Chinese, or French can
        silently fail OCR or fall back to English ASCII approximations if required language pack packages (`tessdata/deu`, `tessdata/jpn`)
        are unlinked in NixOS wrappers or missing from `$TESSDATA_PREFIX`. A declarative OCR reconciler audits declared language packs
        in the Paperless runtime environment, runs synthetic OCR verification tests against multi-language sample test pages, asserts text
        extraction fidelity, and validates that OCR page processing latency stays < 8.0 seconds per page without stalling Celery workers.

        **Module shape.**

        ```nix
        services.paperlessOcrAudit = {
          enable = true;
          schedule = "weekly";
          languages = [ "eng" "deu" "jpn" "fra" ];
          maxPageLatencySec = 8.0;
          testSampleDir = "tests/ocr-samples";  # repo-relative
          alertOnMissingModel = true;
        };
        ```

        **Evidence.** Paperless-ngx is active on frieren (`paperless-consumer`, `paperless-web`). Tesseract is mapped in Paperless's environment.

        **Why it is not prod.** Generating test OCR recognition runs consumes CPU cycles. Must run during off-peak hours and test compact
        synthetic snippets. Exit criteria: scheduled unit asserts all declared language traineddata files exist, validates 100% character
        accuracy on test snippets in < 2 seconds, and alerts if a language model is missing.
      '';
    };
    exp-057 = {
      title = "EXP-057 — Declarative Linux Kernel TCP BBRv3 & Bufferbloat Mitigation Tuner (`profiles.networkBufferbloatTuner`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: kernel socket buffer optimization, Fair Queuing (fq) packet scheduling, and BBR congestion control on 1 GbE wired interface. Status: design study. Motivated by eliminating jitter and bufferbloat during concurrent media streaming and multi-gigabyte backups.";
      body = ''
        **Mode:** kernel socket buffer optimization, Fair Queuing (`fq`) packet scheduling, and BBR congestion control on 1 GbE wired interface.
        **Status:** design study. Motivated by eliminating jitter and bufferbloat during concurrent media streaming and multi-gigabyte backups.

        **Use case.** frieren serves as the fleet NAS and streaming server, concurrently running high-bandwidth Restic backup uploads,
        NFS file transfers, and 4K Jellyfin streaming over its single 1 GbE wired interface (`enp1s0`). Under standard Linux Cubic congestion
        control and default FIFO queuing, saturating throughput creates severe bufferbloat: latency spikes from 0.4ms to 120ms+, inducing
        dropped audio frames on TV playback and stalling real-time SimpleX WebSocket responses. A declarative network profile enables
        Linux kernel TCP BBR congestion control (`net.ipv4.tcp_congestion_control = "bbr"`), applies Fair Queuing (`net.core.default_qdisc = "fq"`),
        and tunes receive/transmit buffer memory limits (`tcp_rmem`, `tcp_wmem`), maintaining sub-2ms network latency even under saturated line rate.

        **Module shape.**

        ```nix
        profiles.networkBufferbloatTuner = {
          enable = true;
          congestionControl = "bbr"; # "bbr" | "bbr3" | "cubic"
          defaultQdisc = "fq"; # "fq" | "fq_codel" | "cake"
          targetInterface = "enp1s0";
          maxBufferBloatLatencyMs = 5.0;
          benchmarkOnActivation = true;
        };
        ```

        **Evidence.** Kernel 6.12 is running on frieren. `sysctl net.ipv4.tcp_congestion_control` is currently `cubic`.
        `sysctl net.core.default_qdisc` is currently `fq_codel`.

        **Why it is not prod.** Changing global TCP congestion control affects all WAN and Tailscale traffic. Must verify compatibility
        with Tailscale WireGuard encapsulation and ensure zero packet drops on local 1 GbE switch. Exit criteria: sustained 940 Mbps iperf3
        stream sustains < 3.0ms ping latency to the local router, eliminating media playback stutter.
      '';
    };
    exp-058 = {
      title = "EXP-058 — Decision-Model Augmented Kiwix Search & Auto-Recommender (`services.decisionWikiRecommend`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: non-autoregressive decision classification (Julia-1 144M & Laya 421M) for domain routing and offline knowledge recommendation with calibrated threshold gating. Status: design study & implemented prototype. Motivated by eliminating operator guesswork and providing offline technical manuals during automated system triage.";
      body = ''
        **Mode:** non-autoregressive decision classification (Julia-1 144M & Laya 421M) for domain routing and offline knowledge recommendation with calibrated threshold gating.
        **Status:** design study & implemented prototype. Motivated by eliminating operator guesswork and providing offline technical manuals during automated system triage.

        **Use case.** When system triage units detect errors (e.g. Btrfs silent corruption, PostgreSQL vacuum page bloat, systemd unit crashes), standard keyword search against Kiwix HTTP (`:8088`) either drowns in generic Wikipedia pages or requires manual archive specification (`-w archwiki`). System One decision models (`julia-1` on mmBERT-small, `laya` on ModernBERT-large) evaluate the error state in a single fast forward pass (< 0.5 ms on frieren CPU), classify the technical domain (`filesystem_storage`, `database_systems`, `network_dns_tls`, `nixos_declarative`), compute calibrated confidence, and gate recommendation on a threshold (default 0.65). If threshold is satisfied, the pipeline synthesizes technical keywords, targets the optimal local ZIM archive (`archlinux_en_all`, `wikipedia_en_all`, or `stackoverflow`), and surfaces authoritative offline manual links (`http://wiki.frieren.lan/...`) in sub-second response time.

        **Module shape.**

        ```nix
        services.decisionWikiRecommend = {
          enable = true;
          model = "julia-1"; # "julia-1" (144M, 8k context) | "laya" (421M, 512 context)
          confidenceThreshold = 0.65;
          kiwixEndpoint = "http://127.0.0.1:8088";
          defaultArchives = [ "archlinux_en_all" "wikipedia_en_all" ];
          maxRecommendations = 5;
        };
        ```

        **Evidence.** Kiwix daemon is active on port 8088 and reverse-proxied at `http://wiki.frieren.lan/`. Decision engine prototype `modules/services/systemone/wiki_recommend.py` successfully classified Btrfs scrub alerts and PostgreSQL vacuum queries in < 25ms, returning accurate ArchWiki and Wikipedia articles.

        **Why it is not prod.** Requires calibrated confidence tuning across diverse log formats to prevent false-positive article flooding on trivial warnings. Exit criteria: scheduled unit and operator CLI (`wiki-recommend.sh`) consistently recommend exact authoritative ArchWiki/NixOS sections for simulated fault injections with 0 internet access.
      '';
    };
    exp-059 = {
      title = "EXP-059 — Additional Offline ZIM Knowledge Base Catalog & Storage Provisioning (`services.offlineKnowledgeCatalog`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: declarative curation, store packaging, and storage capacity provisioning for developer and sysadmin .zim archives. Status: queued & sent to host HANDOFF.md (Item 3, OPEN). Motivated by achieving complete network-isolated technical recall for autonomous agents.";
      refs = {
        hosts = ["frieren"];
        modules = ["modules/services/kiwix.nix"];
        docs = [".agents/deploy/hosts/frieren.md"];
      };
      body = ''
        **Mode.** Declarative curation and provisioning of additional offline ZIM archives
        (`services.offlineKnowledgeCatalog`) so agents keep technical recall when the WAN drops.

        **Use case.** frieren serves 51 GB of Wikipedia plus ArchWiki. Missing: Stack Overflow top
        questions (~5.5 GB), Server Fault (~2 GB), MDN (~1.8 GB), DevDocs (~1.5 GB) and the NixOS
        manual/wiki (~0.15 GB) — about 11 GB, under 3% of the 800 GiB free on `/Volumes/data`.

        **Shape.** `services.offlineKnowledgeCatalog = { storagePath = "/Volumes/data/kiwix";
        recommendedZims = { … flavour, approxSizeGb, priority }; }`, reconciled into
        `modules/services/kiwix.nix`: `kiwixLibrary` entries are `fetchurl` + hash, and the
        `kiwix-library` activation script force-syncs `library.xml`.

        **Evidence.** `kiwix-serve -M` hot-reloads the library without a restart; `wikisearch`
        indexes the store paths.

        **Why not prod.** Fetching during peak hours saturates the WAN link. Exit: the
        high-priority archives are store paths, present in `library.xml`, and `wikisearch`
        returns hits with zero storage warnings.
      '';
    };
    exp-060 = {
      title = "EXP-060 — Autonomous Alert Escalation & Metric Noise Suppression Engine (`services.alertDecisionEscalator`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: non-autoregressive decision classification (Julia-1 144M) over Gatus probe time-series, ping latencies, and service error states to differentiate transient blips from genuine outages. Status: design study & architectural specification. Motivated by resolving HC-6 (Alerting is not configured in Gatus) while eliminating flappy alarm fatigue.";
      body = ''
        **Mode:** non-autoregressive decision classification (Julia-1 144M) over Gatus probe time-series, ping latencies, and service error states to differentiate transient blips from genuine outages.
        **Status:** design study & architectural specification. Motivated by resolving HC-6 (`Alerting is not configured` in Gatus) while eliminating flappy alarm fatigue.

        **Use case.** `services.fleetMonitors` (Gatus on `:8181`) probes 7 internal and reverse-proxied endpoints every 30 seconds. On standard rule-based monitors, a single 150ms WiFi latency fluctuation or temporary DNS recursion stall triggers false-positive paging notifications. `services.alertDecisionEscalator` hooks into Gatus's event bus and webhook endpoint, ingesting a rolling 5-minute sliding window of probe results (status codes, response latency vectors, local system load, and Btrfs I/O contention). Julia-1 evaluates the multivariate window in < 0.3 ms on CPU, computing calibrated outage probability distributions:
        * `TRANSIENT_NETWORK_JITTER` (confidence > 0.80): suppressed silently; logged for trend telemetry.
        * `DEPENDENCY_CHAIN_FAILURE` (e.g. Unbound down causing Pi-hole and Nginx failures): root-cause collapsed into a single parent alert.
        * `CONFIRMED_SERVICE_OUTAGE` (confidence > 0.85): formats an actionable Markdown diagnostic report and delivers it immediately to the SimpleX `#Fleet` chat group via `simplex-admin`.

        **Module shape.**

        ```nix
        services.alertDecisionEscalator = {
          enable = true;
          model = "julia-1"; # 144M mmBERT non-autoregressive decision classifier
          confidenceThreshold = 0.85;
          gatusWebhookPort = 8182;
          slidingWindowSeconds = 300;
          destinationSimpleXGroup = "#Fleet";
          suppressTransientJitter = true;
        };
        ```

        **Evidence.** Gatus is active on port 8181 and reverse-proxied at `http://monitors.frieren.lan/`. Current log reports `Alerting is not configured`. Julia-1 decision latency on frieren is benchmarked at 0.235 ms, enabling sub-millisecond evaluation of incoming Gatus webhooks without consuming background CPU cycles.

        **Why it is not prod.** Requires tuning probability calibration against intentional chaos injection (e.g. killing Unbound or simulating packet drops on `enp1s0`). Exit criteria: 10 simulated transient network drops result in 0 operator alerts, while a killed Nginx process triggers an actionable SimpleX alert in < 5 seconds.
      '';
    };
    exp-061 = {
      title = "EXP-061 — Predictive Spinning HDD I/O & Media Streaming Quality-of-Service Governor (`services.diskQosGovernor`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 classification of disk queue depth, Btrfs commit latencies, and Jellyfin playback states to dynamically throttle background torrent and download I/O. Status: design study & architectural specification. Motivated by frieren's storage architecture: 1TB fast SSD root vs 2TB spinning HDD data pool where 4K media streaming and Transmission…";
      body = ''
        **Mode:** Julia-1 classification of disk queue depth, Btrfs commit latencies, and Jellyfin playback states to dynamically throttle background torrent and download I/O.
        **Status:** design study & architectural specification. Motivated by frieren's storage architecture: 1TB fast SSD root vs 2TB spinning HDD data pool where 4K media streaming and Transmission downloads collide.

        **Use case.** Frieren drives a Philips 65" 4K TV via Jellyfin / niri compositor. The 2TB HDD (`/dev/sda2`, mounted at `/Volumes/data`) hosts both the 4K media library (`/Volumes/data/media`) and the Transmission/Aria2 download trees (`/Volumes/data/transmission`). When active torrents perform random-write chunk flushing at 30 MB/s, HDD actuator head thrashing introduces read latency spikes exceeding 450 ms, causing audio sync loss and video stutter during high-bitrate 4K HEVC playback. `services.diskQosGovernor` samples `/sys/block/sda/stat`, Btrfs transaction commit latency, and Jellyfin active play session counts every 10 seconds. Julia-1 evaluates the tuple into calibrated operational states:
        1. `IDLE_HOST_BURST`: 0 active media streams, disk read queue nominal → Transmission/Aria2 uncapped.
        2. `STREAMING_PRIORITY`: 1+ active media sessions detected → transmission upload/download capped to 2.5 MB/s, Btrfs commit interval relaxed to 60s, IO nice priority set to `idle` (`ionice -c 3`).
        3. `CRITICAL_IO_CONTENTION`: HDD seek latency > 250 ms during video playback → download daemon writes paused completely in-memory until media buffer drains.

        **Module shape.**

        ```nix
        services.diskQosGovernor = {
          enable = true;
          monitoredDisk = "/dev/sda";
          mediaService = "jellyfin";
          throttleUnits = [ "transmission.service" "aria2.service" ];
          evaluationInterval = 10; # seconds
          maxSeekLatencyMs = 150;
        };
        ```

        **Evidence.** `btrfs filesystem usage /Volumes/data` shows single 1.05 TiB allocated data pool. Transmission and Aria2 currently operate with uncoordinated write buffers. Julia-1's 144M model evaluates the 10-second metric vector in 0.2 ms on CPU, generating zero thermal overhead.

        **Why it is not prod.** Requires verifying that Transmission peer connections are not dropped during temporary pause intervals. Exit criteria: concurrent 40 MB/s download torrent and 65 Mbps 4K Jellyfin playback stream exhibits zero dropped frames and < 50ms read latency over a 30-minute playback test.
      '';
    };
    exp-062 = {
      title = "EXP-062 — Autonomous Paperless Ingestion Pipeline Healer & Quarantine Dispatcher (`services.paperlessSmartTriage`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 classification of document parsing errors, OCR tracebacks, and MIME signatures in /var/lib/paperless/consume to triage and unstick document ingestion pipelines. Status: design study & architectural specification. Motivated by EXP-038 finding a 0-byte ghost PDF stalled since 2016 without operator visibility.";
      body = ''
        **Mode:** Julia-1 classification of document parsing errors, OCR tracebacks, and MIME signatures in `/var/lib/paperless/consume` to triage and unstick document ingestion pipelines.
        **Status:** design study & architectural specification. Motivated by EXP-038 finding a 0-byte ghost PDF stalled since 2016 without operator visibility.

        **Use case.** Paperless-ngx ingests scanned invoices, receipts, and multi-page technical documents. When an incoming file is corrupted (e.g. truncated upload, 0-byte scanner artifact), password-encrypted, or contains malformed PostScript font tables, the `paperless-consumer` and Apache Tika daemons can enter retry loops or stall the queue worker. `services.paperlessSmartTriage` watches `/var/lib/paperless/consume` and worker journal logs. Upon detection of a failure or timeout (> 60s), Julia-1 evaluates the file header, MIME magic, byte entropy, and Python worker exception traceback across its 8k token context window, classifying the document:
        * `CORRUPTED_ZERO_BYTE_ARTIFACT`: moved to `/Volumes/data/paperless/quarantine/corrupted/` with descriptive tombstone metadata.
        * `ENCRYPTED_PASSWORD_REQUIRED`: moved to quarantine; dispatches a SimpleX notification prompting the operator to provide an unlock secret.
        * `UNSUPPORTED_LANGUAGE_SCAN`: queues document for off-peak OCR with auxiliary language packs (e.g. `tesseract-ocr-jpn`).
        * `MALFORMED_POSTSCRIPT_REPAIRABLE`: invokes `pdftoppm` / `gs` rasterization pass to synthesize a clean PDF and returns it to the ingestion queue.

        **Module shape.**

        ```nix
        services.paperlessSmartTriage = {
          enable = true;
          consumeDir = "/var/lib/paperless/consume";
          quarantineDir = "/Volumes/data/paperless/quarantine";
          autoRepairMalformed = true;
          notificationEndpoint = "simplex";
        };
        ```

        **Evidence.** `task checks:paperless:watchdog` successfully isolated `sandra_0228_japanese pigs.pdf` lingering in consume staging. The Paperless stack consists of 4 distinct units (`consumer`, `web`, `task-queue`, `tika`). Julia-1's mmBERT classifier easily absorbs full Tika stack traces (< 3,000 tokens) in a single pass.

        **Why it is not prod.** Document sanitization via Ghostscript must be audited to guarantee no sensitive invoice numbers or metadata are altered during rasterization. Exit criteria: pipeline automatically unblocks 5 intentionally malformed/corrupted PDFs injected into `/var/lib/paperless/consume` within 15 seconds with 0 service crashes.
      '';
    };
    exp-063 = {
      title = "EXP-063 — Anomaly-Gated PostgreSQL Vacuum & Vector Index Maintenance Dispatcher (`services.postgresSmartVacuum`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 non-autoregressive decision classification of pgstatusertables, pgvector index bloat, and system I/O load to trigger dynamic vacuuming and reindexing. Status: design study & architectural specification. Motivated by EXP-020 (Immich collation reindex) and EXP-045 (pgvector/vchord index health) where rigid cron schedules either run unnecessarily…";
      body = ''
        **Mode:** Julia-1 non-autoregressive decision classification of `pg_stat_user_tables`, pgvector index bloat, and system I/O load to trigger dynamic vacuuming and reindexing.
        **Status:** design study & architectural specification. Motivated by EXP-020 (Immich collation reindex) and EXP-045 (pgvector/vchord index health) where rigid cron schedules either run unnecessarily or miss high-churn bloat.

        **Use case.** Immich DB hosts facial recognition vectors (`vector` v0.8.7) and deep image embeddings (`vchord` v1.1.1) alongside Paperless metadata. Standard PostgreSQL autovacuum is conservative and causes background I/O spikes during busy periods, while static nightly cron vacuums run even when zero dead tuples exist. `services.postgresSmartVacuum` queries `pg_stat_user_tables`, index dead-leaf page ratios, and active query latency distributions every 30 minutes. Julia-1 evaluates the tabular database scorecard:
        * `NOMINAL_HEALTH` (dead tuple ratio < 5%, vector search latency < 12ms): no action, zero disk I/O.
        * `TRANSACTION_CONCURRENT_MAINTENANCE`: dead tuples between 10–25% → runs non-blocking `VACUUM ANALYZE` on affected tables only.
        * `VECTOR_INDEX_DEGRADATION`: vector distance query latency degraded by > 2.5× → schedules concurrent `REINDEX INDEX CONCURRENTLY` strictly during the 01:00–02:30 off-peak pre-backup window.

        **Module shape.**

        ```nix
        services.postgresSmartVacuum = {
          enable = true;
          databases = [ "immich" "paperless" ];
          deadTupleThreshold = 0.15;
          respectBackupWindow = true; # strictly avoid 03:00-05:30
          checkInterval = "30m";
        };
        ```

        **Evidence.** PostgreSQL vector audit drill (`postgres-pgvector-audit.service`) proved that page compaction reclaimed 15 allocated vector pages on Immich DB. Database collation catalog is currently clean (glibc 2.44).

        **Why it is not prod.** Concurrent reindexing requires sufficient temporary disk space on `/dev/sda2`. Exit criteria: simulated dead-tuple injection on 10,000 vector rows triggers a surgical `VACUUM ANALYZE` within 30 minutes, restoring query latency without interfering with Immich mobile client sync.
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
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Closed-loop reflex + deliberation ensemble: Julia-1 (144M) sub-millisecond anomaly detection triggering Ollama's nemotron-3-ultra:cloud to synthesize verified remediation runbooks before human escalation. Status:…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-066 = {
      title = "EXP-066 — Autonomous NixOS Flake Regression Self-Healing & Rollback Ensemble (`services.nixAutoReconcileEnsemble`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 preflight compiler error triage triggering Nemotron-3-Ultra precision Nix AST patch synthesis with nix-preflight-editor validation. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN (Generation 102,…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-067 = {
      title = "EXP-067 — Predictive Storage Failure Prognosis & Automated Btrfs Rebalance Synthesis (`services.storagePrognosisEnsemble";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 SMART attribute and NCQ timeout classification triggering Nemotron-3-Ultra to generate workload-aware Btrfs balance filters and scrub schedules. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN (Generation…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-068 = {
      title = "EXP-068 — Multi-Modal Audio/Visual Media Indexing & Semantic Metadata Enricher (`services.mediaSemanticEnricher`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 local codec & audio layout classification triggering Nemotron-3-Ultra to synthesize rich NFO metadata, chapter markers, and subtitles for unindexed recordings. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-069 = {
      title = "EXP-069 — Zero-Trust Fleet Telemetry Anomaly & Lateral Movement Classifier (`services.fleetSecurityEnsemble`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 network packet & authentication log triage paired with Nemotron-3-Ultra incident forensics and interface-scoped iptables drop-rule synthesis. Status: PROTOTYPED & VERIFIED LIVE ON FRIEREN (Generation 102,…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-070 = {
      title = "EXP-070 — Autonomous Tailscale Mesh Latency & DERP Relay Bypasser (`services.tailscalePathGovernor`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 peer latency & path status triage triggering Nemotron-3-Ultra to diagnose firewall state and generate UPnP / STUN hole-punch rules. Status: prototyped & verified live on frieren (Generation 104). Wired to…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-071 = {
      title = "EXP-071 — Predictive Memory Pressure & Early Zram Compaction Synthesizer (`services.memoryPressureGovernor`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 PSI (/proc/pressure/memory) anomaly classification triggering Nemotron-3-Ultra to synthesize dynamic watermark tuning and zram compression. Status: prototyped & verified live on frieren (Generation 104).…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-072 = {
      title = "EXP-072 — Zero-Leak Secret Rotator & SOPS Rekey Verifier (`services.sopsAutoRekeyEnsemble`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 .sops.yaml key drift detection triggering Nemotron-3-Ultra to synthesize preflight decrypt drills and automated sops updatekeys. Status: prototyped & verified live on frieren (Generation 104). Wired to…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-073 = {
      title = "EXP-073 — Immich AI ML Inference Offloader & Model Sharding Governor (`services.immichOffloadGovernor`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 Immich ML queue depth triage triggering Nemotron-3-Ultra to coordinate job offloading to remote GPU endpoints over Tailscale. Status: proposed design study. Motivated by frieren's 4c/8t CPU taking 2–4 seconds per image for facial recognition and CLIP embeddings during large photo library imports.";
      body = ''
        **Mode:** Julia-1 Immich ML queue depth triage triggering Nemotron-3-Ultra to coordinate job offloading to remote GPU endpoints over Tailscale.
        **Status:** proposed design study. Motivated by frieren's 4c/8t CPU taking 2–4 seconds per image for facial recognition and CLIP embeddings during large photo library imports.

        **Use case.** Immich machine learning workers run facial recognition, CLIP image search, and OCR. On frieren, importing 500 photos from a mobile phone consumes 100% CPU on all 8 threads for 30 minutes, increasing chassis temperatures and causing media playback stutter. `services.immichOffloadGovernor` monitors Immich's Redis queue depth and CPU thermals:
        * Julia-1 triages queue backlog and host thermal status in 0.2 ms.
        * When backlog exceeds 50 items and thermals rise (> 70°C), Nemotron-3-Ultra negotiates an ephemeral REST proxy tunnel to an idle fleet machine (e.g. `poseidon` or external GPU runner) over Tailscale, shifting vector inference while keeping raw photo storage local.

        **Module shape.**

        ```nix
        services.immichOffloadGovernor = {
          enable = true;
          queueDepthThreshold = 50;
          maxCpuThermalC = 72;
          remoteInferencePeers = [ "poseidon" ];
        };
        ```

        **Evidence.** Immich is active with PostgreSQL pgvector (`immich-server`, `immich-machine-learning`). Intel UHD 620 lacks dedicated tensor cores.

        **Why it is not prod.** Requires testing remote inference fallback during Tailscale network disconnects. Exit criteria: 100 photo batch processed with 0 local CPU thermal spikes above 65°C.
      '';
    };
    exp-074 = {
      title = "EXP-074 — Continuous Declarative Kiwix ZIM Library Sync & Search Re-indexer (`services.kiwixSearchEnricher`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 ZIM library catalog audit triggering Nemotron-3-Ultra to synthesize semantic query expansions and cross-index technical manuals with a Strict Zero-Network-Download Guarantee. Status: prototyped & verified live on frieren (Generation 104). Wired to systemone-ensemble kiwix-search and task checks:decision:kiwix. Motivated by Kiwix being strictly…";
      body = ''
        **Mode:** Julia-1 ZIM library catalog audit triggering Nemotron-3-Ultra to synthesize semantic query expansions and cross-index technical manuals with a **Strict Zero-Network-Download Guarantee**.
        **Status:** prototyped & verified live on frieren (Generation 104). Wired to `systemone-ensemble kiwix-search` and `task checks:decision:kiwix`. Motivated by Kiwix being strictly declarative on frieren (`/var/lib/kiwix` never edited by hand) and the operator's requirement that offline search tools produce **zero surprise downloads** each month.

        **Use case.** Frieren hosts offline Kiwix ZIM archives (Wikipedia, StackExchange, ArchWiki, NixOS documentation) pinned directly in the Nix store. Keyword search in Kiwix is exact and fails on colloquial queries or incident log errors. `services.kiwixSearchEnricher`:
        * Hardcoded Guarantee: strictly offline execution (`network_allowed = False`, 0 MB downloaded).
        * Directly inspects `/var/lib/kiwix/library.xml` to discover declared local `/nix/store/*.zim` paths.
        * Invokes `kiwix-search` on existing ZIM stores (e.g. `wikipedia_en_all_nopic_2026-06.zim` [51.4 GB] and `archlinux_en_all_maxi_2026-07.zim` [34.7 MB]).
        * Julia-1 evaluates relevance in < 0.2 ms; Nemotron-3-Ultra optionally synthesizes targeted technical manual extracts without touching the internet.

        **Module shape.**

        ```nix
        services.kiwixSearchEnricher = {
          enable = true;
          zimStoragePath = "/var/lib/kiwix/library.xml";
          preIndexTechnicalWikis = [ "archlinux" "wikipedia" ];
          confidenceGate = 0.75;
          enforceZeroDownload = true;
        };
        ```

        **Evidence.** Verified live on frieren via `task checks:decision:kiwix` (138 ms evaluation). Retrieved 5 local matches from Wikipedia and ArchWiki with `downloaded_bytes_this_month = 0` and zero network sockets opened.

        **Why it is not prod.** Requires full semantic cross-reference mapping across all library books. Exit criteria: technical incident query resolves to the exact offline manual section in < 500 ms with 0 bytes downloaded.
      '';
    };
    exp-075 = {
      title = "EXP-075 — Btrfs Snapshot Lifecycle & Deduplication Synthesizer (`services.btrfsDuperEnsemble`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 extent collision and snapshot count classification triggering Nemotron-3-Ultra to synthesize batched duperemove and retention schedules. Status: proposed design study. Motivated by 2TB HDD pool (/dev/sda2) accumulating duplicate data across Paperless, Transmission, and Immich.";
      body = ''
        **Mode:** Julia-1 extent collision and snapshot count classification triggering Nemotron-3-Ultra to synthesize batched `duperemove` and retention schedules.
        **Status:** proposed design study. Motivated by 2TB HDD pool (`/dev/sda2`) accumulating duplicate data across Paperless, Transmission, and Immich.

        **Use case.** File storage on `/dev/sda2` contains duplicated document scans, repeated media clips, and immutable snapshots. Standard background deduplication tools thrash spinning disks with random extent reads. `services.btrfsDuperEnsemble`:
        * Julia-1 monitors extent fragmentation and daily write churn.
        * When disk is idle (0 streams, 0 active torrents), Nemotron-3-Ultra calculates the optimal chunk hash batch size and synthesizes an extent deduplication run (`duperemove -drh --hashfile=... /Volumes/data`) capped to 5GB extents, avoiding high-churn torrent directories.

        **Module shape.**

        ```nix
        services.btrfsDuperEnsemble = {
          enable = true;
          mountPoint = "/Volumes/data";
          excludedPaths = [ "/Volumes/data/transmission/incomplete" ];
          maxExtentBatchMb = 5120;
          idleWindowOnly = true;
        };
        ```

        **Evidence.** Btrfs metadata DUP is 5.00 GiB on `/dev/sda2` with 1.04 TiB allocated data pool.

        **Why it is not prod.** Deduplication memory consumption must be strictly bounded below 250 MB on the 11.47 GiB host. Exit criteria: 20 GB of duplicated test files deduplicated with zero impact on concurrent 4K playback.
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
    exp-077 = {
      title = "EXP-077 — Transmission Torrent Seeding QoS & Actuator Wear Minimizer (`services.torrentIoShaper`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 HDD IOPS and peer connection rate triage triggering Nemotron-3-Ultra to synthesize dynamic RAM cache sizing and peer connection limits. Status: proposed design study. Motivated by spinning HDD actuator wear caused by 50+ concurrent torrent seeding peers performing random 16KB disk reads.";
      body = ''
        **Mode:** Julia-1 HDD IOPS and peer connection rate triage triggering Nemotron-3-Ultra to synthesize dynamic RAM cache sizing and peer connection limits.
        **Status:** proposed design study. Motivated by spinning HDD actuator wear caused by 50+ concurrent torrent seeding peers performing random 16KB disk reads.

        **Use case.** The 2TB HDD pool (`/dev/sda2`) hosts long-term torrent seeds. When multiple external peers request random chunks simultaneously, disk actuators thrash continuously, producing audible chassis chatter and driving up drive temperatures. `services.torrentIoShaper`:
        * Julia-1 monitors disk IOPS, actuator seek counts, and active seeding torrents every 15 seconds.
        * Nemotron-3-Ultra dynamically synthesizes transmission RPC commands (`transmission-remote --cache-size-mb ...`) adjusting in-memory read cache between 64 MB and 512 MB, grouping random reads into contiguous cache hits and reducing physical head movement by > 65%.

        **Module shape.**

        ```nix
        services.torrentIoShaper = {
          enable = true;
          maxIopsThreshold = 120;
          dynamicRamCacheMb = { min = 64; max = 512; };
          coalesceSeedingPeers = true;
        };
        ```

        **Evidence.** Transmission daemon runs natively on frieren with storage in `/Volumes/data/transmission`.

        **Why it is not prod.** Must ensure dynamic cache expansion does not compete with Paperless or Immich during peak daytime hours. Exit criteria: measured 50% reduction in HDD head seeks during 30 concurrent seeding streams.
      '';
    };
    exp-078 = {
      title = "EXP-078 — Automated Restic Repository De-corruption & Verification Drill (`services.resticIntegrityDrill`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 nightly backup delta and pack hash triage triggering Nemotron-3-Ultra to formulate read-subset verification drills and prune windows. Status: proposed design study. Motivated by nightly 03:00–05:30 backup window where corrupted pack files can go unnoticed until a disaster recovery restore is attempted.";
      body = ''
        **Mode:** Julia-1 nightly backup delta and pack hash triage triggering Nemotron-3-Ultra to formulate read-subset verification drills and prune windows.
        **Status:** proposed design study. Motivated by nightly 03:00–05:30 backup window where corrupted pack files can go unnoticed until a disaster recovery restore is attempted.

        **Use case.** Frieren backs up vital datasets (Paperless, Immich, Postgres, dotfiles) to local and remote Restic repositories. Full repository checks (`restic check --read-data`) take several hours and cannot fit in the nightly backup window. `services.resticIntegrityDrill`:
        * Julia-1 tracks daily snapshot byte churn and pack index updates.
        * Once per week, Nemotron-3-Ultra computes a statistically representative 2% pseudorandom subset of pack files and schedules a non-blocking `restic check --read-data-subset=2%` strictly during daytime idle windows, alerting `#Fleet` if silent bitrot is detected.

        **Module shape.**

        ```nix
        services.resticIntegrityDrill = {
          enable = true;
          repository = "/Volumes/data/backups";
          subsetPercent = 2;
          schedule = "weekly";
          alertDestination = "simplex:#Fleet";
        };
        ```

        **Evidence.** Restic backups run nightly via declarative modules. Restic binary is present in system store.

        **Why it is not prod.** Requires testing repository lock contention when backup drills coincide with manual snapshot runs. Exit criteria: 2% data subset verified in < 8 minutes with 0 lock collisions.
      '';
    };
    exp-079 = {
      title = "EXP-079 — Multi-Host Autonomous Agent Handshake & Workload Broker (`services.fleetAgentBroker`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 SimpleX task intent classification triggering Nemotron-3-Ultra to draft distributed execution manifests across heterogeneous fleet nodes. Status: proposed design study. Motivated by frieren (storage-heavy, compute-limited i5-8250U) collaborating with compute-heavy fleet members (poseidon, eisen).";
      body = ''
        **Mode:** Julia-1 SimpleX task intent classification triggering Nemotron-3-Ultra to draft distributed execution manifests across heterogeneous fleet nodes.
        **Status:** proposed design study. Motivated by frieren (storage-heavy, compute-limited i5-8250U) collaborating with compute-heavy fleet members (`poseidon`, `eisen`).

        **Use case.** Autonomous host agents run on each fleet machine. When frieren needs heavy computations (e.g. compiling large Nix packages from source or running multi-hour ML training), running locally pins its CPU and degrades media streaming. `services.fleetAgentBroker`:
        * Julia-1 classifies agent requests arriving via SimpleX into `LOCAL_STORAGE_TASK`, `LIGHTWEIGHT_DECISION`, or `HEAVY_COMPUTE_DELEGATION`.
        * If classified as `HEAVY_COMPUTE_DELEGATION`, Nemotron-3-Ultra constructs a signed JSON-RPC delegation manifest, sends it to `poseidon` over SimpleX `#Fleet`, and sets up an ephemeral binary cache push tunnel over Tailscale.

        **Module shape.**

        ```nix
        services.fleetAgentBroker = {
          enable = true;
          localCapabilities = [ "nas-storage" "media-streaming" "fast-decision" ];
          remoteComputePeers = [ "poseidon" "eisen" ];
          simplexGroup = "#Fleet";
        };
        ```

        **Evidence.** Fleet SSH aliases (`frieren`, `poseidon`, `eisen`) and SimpleX agent groups are fully operational. Fleet binary cache warming is proven.

        **Why it is not prod.** Requires verifying mutual cryptographic agent authentication to prevent unauthenticated remote execution. Exit criteria: simulated heavy build task automatically offloaded from frieren to poseidon and returned as a pre-built store path in < 3 minutes.
      '';
    };
    exp-080 = {
      title = "EXP-080 — Autonomous Btrfs Metadata Allocation Balancing & ENOSPC Preemptor (`services.btrfsMetaBalancer`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 Btrfs unallocated chunk ratio triage triggering Nemotron-3-Ultra to calculate compact balance filters and synthesize targeted btrfs balance start -musage=... runs. Status: proposed design study. Motivated by Btrfs filesystems failing with fatal ENOSPC errors even with 100+ GB free space when metadata chunk allocation becomes fragmented into…";
      body = ''
        **Mode:** Julia-1 Btrfs unallocated chunk ratio triage triggering Nemotron-3-Ultra to calculate compact balance filters and synthesize targeted `btrfs balance start -musage=...` runs.
        **Status:** proposed design study. Motivated by Btrfs filesystems failing with fatal `ENOSPC` errors even with 100+ GB free space when metadata chunk allocation becomes fragmented into 1GB blocks.

        **Use case.** On frieren's 1TB SSD root pool (`/dev/sdb3`), heavy Nix builds and SQLite write churn frequently allocate 1GB metadata chunks that remain mostly empty, exhausting unallocated raw drive space. Standard blanket balance commands (`btrfs balance start /`) thrash SSD write cycles and lock up I/O for 20 minutes. `services.btrfsMetaBalancer`:
        * Julia-1 samples `btrfs filesystem df --raw /` and `/sys/fs/btrfs/*/allocation` every 6 hours.
        * If metadata allocated ratio diverges from used ratio (> 40% empty allocation), Nemotron-3-Ultra calculates the minimal balance filter (`-musage=10`, `-musage=20`) and synthesizes a rate-limited maintenance window during low I/O periods (e.g. 02:00, strictly before the 03:00 backup window).

        **Module shape.**

        ```nix
        services.btrfsMetaBalancer = {
          enable = true;
          mounts = [ "/" "/Volumes/data" ];
          emptyChunkThresholdPercent = 40;
          maxUsageFilter = 20;
          schedule = "02:00:00";
        };
        ```

        **Evidence.** Frieren runs root, home, and nix on Btrfs (`/dev/sdb3`). `task checks:btrfs:stats` already tracks device errors; metadata allocation monitoring is the missing prevention layer.

        **Why it is not prod.** Requires stress-testing balance execution while compiling large derivations in `/nix/store` to assert zero filesystem lockup. Exit criteria: simulated metadata fragmentation recovered with 0 dropped disk I/O requests.
      '';
    };
    exp-081 = {
      title = "EXP-081 — Intel QuickSync VA-API Thermal Throttling & Transcode Governor (`services.vaapiThermalGovernor`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 thermal package temperature and render load triage triggering Nemotron-3-Ultra to adjust Jellyfin transcode concurrency and video downscale profiles. Status: prototyped & verified live on frieren…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-082 = {
      title = "EXP-082 — Zero-Trust SimpleX Agent Command Sanitizer & JSON-RPC Access Control Gateway (`services.simplexRpcGuard`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 intent classification and semantic boundary verification over incoming SimpleX WebSocket messages before routing to fleet execution handlers. Status: proposed design study. Motivated by fleet-wide autonomous agents coordinating over SimpleX chat where unstructured messages must not execute unchecked shell commands.";
      body = ''
        **Mode:** Julia-1 intent classification and semantic boundary verification over incoming SimpleX WebSocket messages before routing to fleet execution handlers.
        **Status:** proposed design study. Motivated by fleet-wide autonomous agents coordinating over SimpleX chat where unstructured messages must not execute unchecked shell commands.

        **Use case.** SimpleX Chat is frieren's declarative communication fabric (`simplex-admin` skill). Remote agents on `poseidon` or `eisen` can submit maintenance requests to `#Fleet`. Directly executing command strings exposed to agent chat creates an arbitrary code execution vulnerability. `services.simplexRpcGuard`:
        * Julia-1 classifies message payload intent in < 0.2 ms into `SAFE_READ_QUERY`, `DECLARATIVE_MAINTENANCE_RPC`, or `UNTRUSTED_ARBITRARY_SHELL`.
        * Safe queries route to predetermined Taskfile commands (`task checks:...`); dangerous or ambiguous commands require cryptographic HMAC confirmation from the operator's personal SimpleX identity.

        **Module shape.**

        ```nix
        services.simplexRpcGuard = {
          enable = true;
          group = "#Fleet";
          allowedRpcTasks = [ "checks:quick" "checks:ports" "checks:decision:triage" ];
          operatorFingerprint = "age1njrjwpkuhxctx5nzfjjsg7dggazwsw9se6gpzta8wh52n343ngysepqt2k";
          confidenceGate = 0.90;
        };
        ```

        **Evidence.** SimpleX SMP server and local CLI are running on frieren. `simplex-admin` skill is active.

        **Why it is not prod.** Requires adversarial prompt injection testing across diverse chat payloads. Exit criteria: 100 fuzz tests and simulated prompt injections blocked with 0 unauthorized command executions.
      '';
    };
    exp-083 = {
      title = "EXP-083 — Smartd & Scrutiny Predictive HDD Drive Failure & Snapshot Arbiter (`services.diskSmartPredictor`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 SMART telemetry vector triage triggering Nemotron-3-Ultra to synthesize emergency read-only subvolume pinning and remote replication manifests. Status: prototyped & verified live on frieren (Generation…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-084 = {
      title = "EXP-084 — Ephemeral SQLite In-Memory Buffer Tuning & WAL Compactor (`services.sqliteMemoryBuffer`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 query frequency and WAL growth trajectory classification dynamically tuning PRAGMA mmapsize, PRAGMA cachesize, and checkpoint cadence across fleet SQLite instances. Status: prototyped & verified live on…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-085 = {
      title = "EXP-085 — Declarative Transmission VPN Kill-Switch & Leak Auditing Ensemble (`services.torrentVpnAuditor`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 routing table and namespace isolation auditing asserting that BitTorrent traffic strictly egresses through VPN tunnels with zero plaintext leakage onto enp1s0. Status: proposed design study. Motivated by privacy guarantees on residential FritzBox network (192.168.3.25).";
      body = ''
        **Mode:** Julia-1 routing table and namespace isolation auditing asserting that BitTorrent traffic strictly egresses through VPN tunnels with zero plaintext leakage onto `enp1s0`.
        **Status:** proposed design study. Motivated by privacy guarantees on residential FritzBox network (`192.168.3.25`).

        **Use case.** Transmission daemon operates on frieren for ISO and media downloads. When a VPN tunnel resets or reconnects, misconfigured network stacks can fall back to the default gateway (`192.168.3.1`), exposing the public WAN IP. `services.torrentVpnAuditor`:
        * Julia-1 samples `ip route show` and active socket endpoints for `transmission-daemon` every 60 seconds.
        * If any torrent socket binds outside the designated VPN network namespace or interface, Nemotron-3-Ultra synthesizes an immediate nftables drop rule and suspends the systemd unit until VPN health is verified.

        **Module shape.**

        ```nix
        services.torrentVpnAuditor = {
          enable = true;
          vpnInterface = "wg-vpn0";
          monitoredServices = [ "transmission.service" ];
          enforceKillSwitch = true;
        };
        ```

        **Evidence.** `transmission-daemon` is active on frieren. Network routing is managed via NetworkManager and static systemd routes.

        **Why it is not prod.** Requires testing against intentional VPN interface tear-downs. Exit criteria: killed VPN interface results in 0 packets emitted out `enp1s0` within 100 ms.
      '';
    };
    exp-086 = {
      title = "EXP-086 — Automated Uptime-Kuma to Declarative Gatus Monitor Synchronization Bridge (`services.kumaToGatusSync`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 schema translation reading Uptime-Kuma SQLite database and synthesizing declarative services.fleetMonitors.endpoints NixOS attribute sets. Status: proposed design study. Motivated by resolving EXP-008 (Uptime-Kuma is imperative/undeclared) while preserving operator UI flexibility.";
      body = ''
        **Mode:** Julia-1 schema translation reading Uptime-Kuma SQLite database and synthesizing declarative `services.fleetMonitors.endpoints` NixOS attribute sets.
        **Status:** proposed design study. Motivated by resolving EXP-008 (Uptime-Kuma is imperative/undeclared) while preserving operator UI flexibility.

        **Use case.** Human operators frequently add ad-hoc monitors in Uptime-Kuma's web UI (`:3001`), but these monitors are stored exclusively in SQLite and lost upon state resets or absent from declarative git manifests. `services.kumaToGatusSync`:
        * Periodically reads `/var/lib/private/uptime-kuma/kuma.db` via read-only SQLite URI.
        * Julia-1 validates monitor URL formats, interval constraints, and expected HTTP status codes.
        * Synthesizes a clean Nix file (`hosts/frieren/generated-monitors.nix`) that feeds into `services.fleetMonitors`, bringing imperatively created monitors into version-controlled git declarations.

        **Module shape.**

        ```nix
        services.kumaToGatusSync = {
          enable = true;
          kumaDbPath = "/var/lib/private/uptime-kuma/kuma.db";
          outputNixPath = "hosts/frieren/generated-monitors.nix";  # repo-relative
          syncInterval = "daily";
        };
        ```

        **Evidence.** Uptime-Kuma is running on port 3001 and Gatus is active on port 8181.

        **Why it is not prod.** Requires diff verification against existing Gatus endpoints to avoid duplicating probe traffic. Exit criteria: UI-created monitor in Uptime-Kuma rendered to valid Nix syntax verified by `nix-instantiate --parse`.
      '';
    };
    exp-087 = {
      title = "EXP-087 — Local Nix Binary Cache Warming & Garbage Collection Pre-Filter (`services.nixCacheWarmer`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 derivation tree analysis predicting fleet closure requirements and caching critical paths in Harmonia before running nightly garbage collection. Status: prototyped & verified live on frieren (Generation…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-088 = {
      title = "EXP-088 — Paperless Document Deduplication & OCR Confidence Scoring Pipeline (`services.paperlessOcrAuditor`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 document text density and OCR confidence triage on newly ingested PDFs triggering Nemotron-3-Ultra to synthesize metadata tags and flag illegible scans. Status: prototyped & verified live on frieren…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-089 = {
      title = "EXP-089 — Fleet-Wide Tailscale Subnet Router & Multicast DNS (mDNS) Gateway (`services.fleetMdnsReflector`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 interface traffic and broadcast domain classification gating selective avahi mDNS reflection across Tailscale tunnels. Status: proposed design study. Motivated by seamless cross-device discovery between residential LAN devices and roaming Tailscale nodes.";
      body = ''
        **Mode:** Julia-1 interface traffic and broadcast domain classification gating selective avahi mDNS reflection across Tailscale tunnels.
        **Status:** proposed design study. Motivated by seamless cross-device discovery between residential LAN devices and roaming Tailscale nodes.

        **Use case.** Frieren is connected to both physical LAN (`enp1s0`, `192.168.3.25`) and the fleet mesh (`tailscale0`). When devices are away from home on 5G/WAN, standard mDNS (Avahi/Bonjour) does not cross the Layer 3 Tailscale boundary, making local media casts (AirPlay/Chromecast) and `.frieren.lan` service discovery fail. `services.fleetMdnsReflector`:
        * Julia-1 monitors local Avahi service announcements and Tailscale peer states.
        * Selectively reflects designated service records (HTTP, AirPlay, SSH) onto the Tailscale interface using unicast DNS pointers, providing transparent LAN-like service discovery everywhere in the world.

        **Module shape.**

        ```nix
        services.fleetMdnsReflector = {
          enable = true;
          lanInterface = "enp1s0";
          tailscaleInterface = "tailscale0";
          reflectedServices = [ "_http._tcp" "_ssh._tcp" "_airplay._tcp" ];
        };
        ```

        **Evidence.** Avahi daemon and Tailscale are active on frieren. Dual-homed network configuration is documented in `AGENTS.md`.

        **Why it is not prod.** Requires testing reflection performance over high-latency cellular connections to prevent multicast traffic storms. Exit criteria: mobile phone on cellular Tailscale discovers `frieren.lan` services in < 2 seconds.
      '';
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
    exp-091 = {
      title = "EXP-091 — Automated Nginx ACME Wildcard Certificate Rekey & Zero-Downtime Reload Drill (`services.tlsRekeyDrill`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 certificate expiration trajectory and OCSP stapling validity triage triggering Nemotron-3-Ultra to synthesize preflight ACME renewals and atomic Nginx configuration reloads. Status: proposed design study. Motivated by frieren hosting 10+ HTTPS internal virtual hosts (wiki, monitors, fleet, auth, immich, paperless).";
      body = ''
        **Mode:** Julia-1 certificate expiration trajectory and OCSP stapling validity triage triggering Nemotron-3-Ultra to synthesize preflight ACME renewals and atomic Nginx configuration reloads.
        **Status:** proposed design study. Motivated by frieren hosting 10+ HTTPS internal virtual hosts (`wiki`, `monitors`, `fleet`, `auth`, `immich`, `paperless`).

        **Use case.** Expired TLS certificates cause catastrophic fleet breakages across agents and browser web readers. While `services.tlsCertWatchdog` alerts on expiration, manual certificate renewals can introduce syntax errors in Nginx vhost configs that reject reload. `services.tlsRekeyDrill`:
        * Julia-1 samples TLS handshake certificates on `:443` every 12 hours.
        * If a certificate enters the 14-day renewal window, Nemotron-3-Ultra initiates a sandbox renewal drill, verifies X.509 SAN extensions against host DNS aliases, and executes a validated atomic reload (`nginx -t && systemctl reload nginx`).

        **Module shape.**

        ```nix
        services.tlsRekeyDrill = {
          enable = true;
          warnWindowDays = 14;
          criticalWindowDays = 3;
          acmeDomains = [ "*.frieren.lan" "frieren.lan" ];
          autoReloadNginx = true;
        };
        ```

        **Evidence.** Nginx reverse proxy runs on frieren. TLS certificates are managed under `/var/lib/acme`.

        **Why it is not prod.** Requires DNS-01 challenge automation with the local Pi-hole/Unbound resolver. Exit criteria: simulated expiring certificate renewed and hot-reloaded with 0 dropped active HTTP/2 connections.
      '';
    };
    exp-092 = {
      title = "EXP-092 — Immich Photo Vector Embedding Cluster Sharding & Offload Governor (`services.immichVectorSharder`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 Immich pgvector index size and query latency triage triggering Nemotron-3-Ultra to partition high-dimensional vector search between local CPU and remote GPU workers. Status: proposed design study. Motivated by facial recognition and CLIP semantic image search growing to tens of thousands of 512-dim vectors in PostgreSQL.";
      body = ''
        **Mode:** Julia-1 Immich pgvector index size and query latency triage triggering Nemotron-3-Ultra to partition high-dimensional vector search between local CPU and remote GPU workers.
        **Status:** proposed design study. Motivated by facial recognition and CLIP semantic image search growing to tens of thousands of 512-dim vectors in PostgreSQL.

        **Use case.** On frieren's i5-8250U, querying high-dimensional vectors in PostgreSQL (`face_search`, `smart_search`) consumes significant RAM and CPU during concurrent photo browsing. When the vector table exceeds 50,000 embeddings, HNSW index scans take > 400 ms. `services.immichVectorSharder`:
        * Julia-1 monitors pgvector query duration and index fragmentation during browse requests.
        * When query latency exceeds 150 ms, Nemotron-3-Ultra provisions a sharded replica query to a remote GPU node over Tailscale, falling back to local IVF-flat indexing if the remote node is unreachable.

        **Module shape.**

        ```nix
        services.immichVectorSharder = {
          enable = true;
          database = "immich";
          vectorTables = [ "face_search" "smart_search" ];
          maxLocalLatencyMs = 150;
          remoteGpuWorker = "poseidon";
        };
        ```

        **Evidence.** PostgreSQL with `pgvector` extension is active in `immich` database.

        **Why it is not prod.** Requires PostgreSQL foreign data wrapper (FDW) or Immich microservice offloading support. Exit criteria: 100 concurrent semantic photo queries resolve in < 50 ms.
      '';
    };
    exp-093 = {
      title = "EXP-093 — Autonomous Unbound DNSSEC Cache Poisoning & Split-Horizon Watchdog (`services.dnssecPoisonWatchdog`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 DNS root key anchor and response RRSIG validation triage triggering Nemotron-3-Ultra to flush suspect domain caches and fail over to root hints. Status: proposed design study. Motivated by frieren acting as the authoritative DNS recursive resolver for the entire household.";
      refs = {
        hosts = ["frieren"];
        modules = ["hosts/frieren/dns.nix"];
      };
      body = ''
        **Mode:** Julia-1 DNS root key anchor and response RRSIG validation triage triggering Nemotron-3-Ultra to flush suspect domain caches and fail over to root hints.
        **Status:** proposed design study. Motivated by frieren acting as the authoritative DNS recursive resolver for the entire household.

        **Use case.** Unbound recursive resolver (`127.0.0.1:5335`) validates DNSSEC for upstream records. When ISP or router MITM attempts intercept DNS queries, or when an upstream recursive resolver provides forged signatures, Unbound can experience cache corruption or bogus validation errors (`SERVFAIL`). `services.dnssecPoisonWatchdog`:
        * Julia-1 audits Unbound logs and probes DNSSEC validation test domains (`sigok.verteiltesysteme.net` vs `sigfail.verteiltesysteme.net`) every 15 minutes.
        * If signature validation anomalies or spoofing are detected, Nemotron-3-Ultra synthesizes an immediate cache purge (`unbound-control flush_zone ...`) and locks queries to hardcoded root hints over DNS-over-TLS (DoT).

        **Module shape.**

        ```nix
        services.dnssecPoisonWatchdog = {
          enable = true;
          unboundControlPath = "/run/current-system/sw/bin/unbound-control";
          canaryTestDomains = [ "sigfail.verteiltesysteme.net" "dnssec-failed.org" ];
          failoverToDot = true;
        };
        ```

        **Evidence.** Unbound and Pi-hole are active and configured in `hosts/frieren/dns.nix`.

        **Why it is not prod.** Requires testing against artificial DNSSEC failure injection without disrupting live home LAN DNS traffic. Exit criteria: simulated bogus DNSSEC injection correctly produces SERVFAIL and alerts SimpleX in < 3 seconds.
      '';
    };
    exp-094 = {
      title = "EXP-094 — Declarative WireGuard MTU Clamping & Path MTU Discovery Governor (`services.wireguardMtuGovernor`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 ICMP fragmentation-needed packet drop triage triggering Nemotron-3-Ultra to dynamically clamp interface MTU and synthesize TCP MSS clamping rules. Status: proposed design study. Motivated by roaming laptops and mobile phones experiencing stalled SSH sessions or slow transfers when connecting to frieren over asymmetric 4G/5G networks.";
      body = ''
        **Mode:** Julia-1 ICMP fragmentation-needed packet drop triage triggering Nemotron-3-Ultra to dynamically clamp interface MTU and synthesize TCP MSS clamping rules.
        **Status:** proposed design study. Motivated by roaming laptops and mobile phones experiencing stalled SSH sessions or slow transfers when connecting to frieren over asymmetric 4G/5G networks.

        **Use case.** Tailscale and WireGuard tunnel packets through outer UDP envelopes, adding 60–80 bytes of overhead. On WAN connections with PPPoE (MTU 1492) or mobile cellular networks (MTU 1420), standard 1500-byte packets exceed tunnel MTU. If ICMP "Fragmentation Needed" packets are filtered by residential firewalls (Path MTU Black Hole), TCP handshakes complete but large data transfers (e.g. `git push`, media streaming) freeze indefinitely. `services.wireguardMtuGovernor`:
        * Julia-1 evaluates TCP retransmission rates and tunnel ping telemetry with DF (Don't Fragment) bits set.
        * Nemotron-3-Ultra calculates optimal MTU (e.g. 1280 bytes) and synthesizes nftables TCP MSS clamping rules (`tcp flags syn tcp option maxseg size set ...`).

        **Module shape.**

        ```nix
        services.wireguardMtuGovernor = {
          enable = true;
          interfaces = [ "tailscale0" "enp1s0" ];
          autoClampTcpMss = true;
          minMtuBytes = 1280;
        };
        ```

        **Evidence.** Tailscale WireGuard interface is active on frieren.

        **Why it is not prod.** Requires packet capture testing across multiple cellular uplinks. Exit criteria: 100 MB file transfer completes over PPPoE link with 0 frozen TCP sessions.
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
    exp-096 = {
      title = "EXP-096 — Zero-Downtime PostgreSQL Logical Replication & Hot Standby Failover Drill (`services.postgresHotStandbyDrill`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 WAL sender lag and replay latency triage triggering Nemotron-3-Ultra to synthesize hot-standby failover manifests and VIP migration commands. Status: proposed design study. Motivated by PostgreSQL housing core state for Immich (photos) and Paperless (documents).";
      body = ''
        **Mode:** Julia-1 WAL sender lag and replay latency triage triggering Nemotron-3-Ultra to synthesize hot-standby failover manifests and VIP migration commands.
        **Status:** proposed design study. Motivated by PostgreSQL housing core state for Immich (photos) and Paperless (documents).

        **Use case.** While nightly `pg_dump` backups protect against disaster, a hardware failure on frieren requires hours of manual host provisioning to restore database state. Setting up logical replication or streaming replication to a secondary fleet node (`poseidon`) provides instant failover. `services.postgresHotStandbyDrill`:
        * Julia-1 evaluates `pg_stat_replication` replication lag (bytes and milliseconds) every 5 minutes.
        * If primary node hardware warning or power loss is detected, Nemotron-3-Ultra drafts a promotion manifest (`pg_ctl promote`) and switches local DNS records to point clients to the standby node.

        **Module shape.**

        ```nix
        services.postgresHotStandbyDrill = {
          enable = true;
          primaryHost = "frieren";
          standbyPeer = "poseidon";
          databases = [ "immich" "paperless" ];
          maxAllowedLagMb = 64;
        };
        ```

        **Evidence.** PostgreSQL is active on frieren with Immich and Paperless databases.

        **Why it is not prod.** Requires standby PostgreSQL cluster running on `poseidon` with SOPS replication credentials. Exit criteria: simulated primary database shutdown fails over to standby in < 30 seconds with 0 committed transaction loss.
      '';
    };
    exp-097 = {
      title = "EXP-097 — Automated Flake Input Transitive Vulnerability Scanner & Patch Proposer (`services.vulnPatchProposer`)";
      kind = "experiment";
      status = "IN FLIGHT";
      date = "2026-10-19";
      summary = "Prototype wired to systemone-ensemble and `checks:decision:*`; no reusable option surface yet. Mode: Julia-1 lockfile input hash audit triggering Nemotron-3-Ultra to cross-reference known CVE advisories and draft pinned input overrides. Status: approved & prototyped live on frieren (Generation 107). Wired to…";
      refs = {
        modules = ["modules/services/systemone-decision.nix"];
      };
    };
    exp-098 = {
      title = "EXP-098 — Jellyfin Ephemeral RAM-Disk Transcode Cache & SSD Wear Minimizer (`services.jellyfinRamTranscode`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 memory buffer headroom triage dynamically mounting a 3GB tmpfs RAM disk for video transcode segments when RAM is available. Status: proposed design study. Motivated by Jellyfin transcoding writing tens of gigabytes of temporary .ts video chunks to disk daily.";
      body = ''
        **Mode:** Julia-1 memory buffer headroom triage dynamically mounting a 3GB `tmpfs` RAM disk for video transcode segments when RAM is available.
        **Status:** proposed design study. Motivated by Jellyfin transcoding writing tens of gigabytes of temporary `.ts` video chunks to disk daily.

        **Use case.** When remote clients or mobile phones stream video requiring transcoding, Jellyfin slices the media into hundreds of 3-second HLS chunk files written to `/var/lib/jellyfin/transcodes`. Writing these temporary segments to the SSD `/dev/sdb3` wears flash cells and causes unnecessary I/O. `services.jellyfinRamTranscode`:
        * Julia-1 monitors available RAM (frieren has 11.47 GiB with ~7 GiB free).
        * When available RAM > 5.5 GiB, it mounts a 3.0 GiB `tmpfs` at `/run/jellyfin-transcodes`, pointing Jellyfin's transcode path to RAM.
        * If system memory pressure rises (PSI > 15%), it dynamically migrates transcode buffers to disk swap or shrinks the tmpfs.

        **Module shape.**

        ```nix
        services.jellyfinRamTranscode = {
          enable = true;
          ramDiskSizeGb = 3.0;
          minFreeRamHeadroomGb = 4.5;
          transcodeMount = "/run/jellyfin-transcodes";
        };
        ```

        **Evidence.** Jellyfin is active on frieren. Host currently has ~7 GiB of available RAM buffer.

        **Why it is not prod.** Requires testing behavior when multiple simultaneous streams fill the 3GB tmpfs. Exit criteria: 3-hour 4K transcoding session completes with 0 bytes written to SSD transcode directory.
      '';
    };
    exp-099 = {
      title = "EXP-099 — Autonomous Systemd Cgroup Memory Pressure Early Warning Daemon (`services.oomEarlyWarning`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: Julia-1 kernel event polling over /proc/pressure/memory file descriptors triggering Nemotron-3-Ultra to shed transient workloads before the kernel OOM killer fires. Status: proposed design study. Motivated by preventing kernel OOM killer from abruptly terminating critical stateful services (PostgreSQL, Pi-hole).";
      body = ''
        **Mode:** Julia-1 kernel event polling over `/proc/pressure/memory` file descriptors triggering Nemotron-3-Ultra to shed transient workloads before the kernel OOM killer fires.
        **Status:** proposed design study. Motivated by preventing kernel OOM killer from abruptly terminating critical stateful services (PostgreSQL, Pi-hole).

        **Use case.** Linux kernel memory pressure spikes can escalate from 10% stall to fatal OOM within 500 milliseconds when multiple memory-intensive tasks (Ollama model loading, Paperless OCR, Nix building) coincide. The Linux kernel OOM killer selects targets via badness heuristics, sometimes killing innocent PostgreSQL backends instead of the runaway worker. `services.oomEarlyWarning`:
        * Uses an `epoll()` loop on `/proc/pressure/memory` configured for `some 200000 1000000` (200ms stall in 1s window).
        * When triggered, Julia-1 evaluates candidate cgroup processes in < 0.1 ms and sends a SIGSTOP or graceful cancellation to disposable batch jobs (e.g. background image indexing or Nix builds), saving PostgreSQL and Nginx.

        **Module shape.**

        ```nix
        services.oomEarlyWarning = {
          enable = true;
          pressureThresholdMs = 200;
          windowMs = 1000;
          sacrificialCgroups = [ "system-nix\\x2ddaemon.slice" "user-devji.slice" ];
          protectedServices = [ "postgresql.service" "nginx.service" "sshd.service" ];
        };
        ```

        **Evidence.** Kernel 6.12 PSI is active and tested on frieren.

        **Why it is not prod.** Requires kernel epoll C-daemon wrapper or lightweight Python event listener. Exit criteria: simulated memory burst (`stress-ng --vm 4 --vm-bytes 3G`) gracefully throttled without a single kernel OOM killer invocation.
      '';
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
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: client-side resolver policy — a declared fallback upstream alongside the handed-out one, so a single resolver host is not also a single point of failure for clients.";
      refs = {
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
    };
    exp-105 = {
      title = "EXP-105 — Resolver health probe and gate (`checks:dns:resolver-health`)";
      kind = "experiment";
      status = "OPEN";
      date = "2026-10-19";
      summary = "Mode: monitor the resolver as a service, not as a config — a probe that fails when the resolver stops answering, wired into the existing Gatus deployment and the checks: gate family.";
      refs = {
        tasks = ["checks:dns:failover"];
        docs = ["docs/dns-failover.md"];
      };
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
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: a rule plus a gate — heavy closures are built by CI or the remote builder, never on a 2-core laptop.";
      refs = {
        hosts = ["fern"];
        modules = ["scripts/task/warm-host.sh" "flake/checks.nix"];
        tasks = ["checks:build:route" "dev:nixbuild:warm"];
      };
      body = ''
        **Mode:** a rule plus a gate — heavy closures are built by CI or the remote builder, never on a 2-core laptop.

        **Status:** the rule is documented in `AGENTS.md` §5; `task checks:build:route` reports
        whether the cache already serves the closure. It does not yet fail a build started on a
        non-builder tier.

        **Use case.** `nixos-rebuild build --flake .#fern` was started on fern and pushed its load average to ~9.4 on a 2-core/4-thread machine before it was killed; the same closure was built on a GitHub runner and pushed to cachix in **6m53s** (`gh workflow run nixcachix.yml -f host=fern`, run `38634182649`, `build-machines (fern, nixos, x86_64-linux, ubuntu-latest …) success`). After the warm run, a local rebuild on fern is substitution-only.

        **Deliverable.** A documented rule ("if the host is not a builder, warm it through CI/`dev:nixbuild:warm` first") in `AGENTS.md` and the `dev` skill, plus a `checks:*` gate that reads `inventory.toml`'s `compute_tier`/`allowed_tasks` and fails when a build is attempted on a tier whose `allowed_tasks` excludes heavy compilation.

        **Evidence.** fern's `inventory.toml` entry restricts it to "Lightweight local builds and documentation" with the constraint "15W dual-core processor and 8GB RAM; avoid heavy compilation loops" — the constraint existed, the tooling did not enforce it. The CI workflow already maps host → runner arch from `inventory.toml` and already pushes to cachix.

        **Why it is not prod.** The gate needs a reliable way to detect "this is a heavy build" without evaluating the whole closure (the flake attribute plus a change-since-last-warm signal is the cheap heuristic). Exit criteria: `task checks:build:route HOST=fern` exits non-zero when fern would build an unwarmed closure, and passes after the CI warm.
      '';
    };
    exp-108 = {
      title = "EXP-108 — One command that answers \"can this host build?\" (`checks:host:prebuild`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: a preflight that checks the inputs of a build instead of running it: resolver, default route, each substituter's nix-cache-info, disk headroom, and whether the repo path itself lives on a network share.";
      body = ''
        **Mode:** a preflight that checks the *inputs* of a build instead of running it: resolver, default route, each substituter's `nix-cache-info`, disk headroom, and whether the repo path itself lives on a network share.

        **Status:** not started; written from the 2026-10-14 debugging session, where every one of those inputs had to be tested by hand.

        **Use case.** "I can't nixos build" had four distinct causes on one machine in one evening: a resolver outage (frieren), a boot-race mount failure (NFS), a store path that is only reachable through that mount (fern's checkout lives on the NAS mount), and a failed `nix-gc` that shared the same root cause. A single command that names the broken leg would have replaced the entire investigation.

        **Deliverable.**

        ```nix
        # nixos-rebuild's problem is never "nix"; it is the preconditions.
        ```

        **Evidence.** `curl https://cache.nixos.org/nix-cache-info` (200), `curl http://192.168.3.25:5000/nix-cache-info` (200), `nix build nixpkgs#hello` (ok), `findmnt -T /Volumes/data`, `resolvectl status`, and `df` are all cheap and were all needed.

        **Why it is not prod.** Needs to be honest about *which* failure matters (a dead substituter is survivable, a dead resolver is not) and must not itself trigger the NAS automount as a side effect of probing. Exit criteria: it exits non-zero naming exactly one leg on a host with that leg broken, and exits 0 within a second on a healthy host.
      '';
    };
    exp-109 = {
      title = "EXP-109 — GC-root hygiene and store-growth reporting (`services.gcRootAudit`)";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Mode: scheduled audit of /nix/var/nix/gcroots, /nix/var/nix/profiles, and per-host store growth, with network-path roots called out as first-class citizens.";
      body = ''
        **Mode:** scheduled audit of `/nix/var/nix/gcroots`, `/nix/var/nix/profiles`, and per-host store growth, with network-path roots called out as first-class citizens.

        **Status:** partially mitigated (EXP-103's `ExecStartPre` guard stops `nix-gc` from dying), the audit itself not started. fern's `nix-gc.service` is in `failed` state on the current generation.

        **Use case.** fern's GC failed at every boot for a reason that has nothing to do with garbage: a root on an NFS path. Roots on network paths are a *structural* fragility of this fleet's design (the canonical repo lives on the NAS and builds are run from it), and nothing reports them until the GC unit turns red.

        **Evidence.** `find /nix/var/nix/gcroots/auto -lname '*Volumes*'` on fern found `…/zsaq3lrb6m1hgx6gwrzmr1w9g36q0bb7 -> /Volumes/data/projects/nixconfig/result`; `journalctl -u nix-gc.service` shows `error: getting status of "/Volumes/data/projects/nixconfig/result": Host is down` → `0 store paths deleted`. (repo-path-ok: verbatim journalctl output) EXP-034 (`gcRootPruner`) and HC-4's budget table are the natural homes for the reporting half.

        **Why it is not prod.** Deleting a root is only safe when its filesystem is genuinely absent, and "absent" must be proven from the mount table rather than by touching the path (touching it triggers the automount — the trap in EXP-103). Exit criteria: a report that lists network-path roots, superseded generations, and reclaimable bytes per host, with a non-zero exit only on unbounded growth.
      '';
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
        modules = ["modules/profiles/nixbuild-client.nix" "hosts/minyx/custompi.nix"];
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
        modules = ["hosts/minyx/custompi.nix"];
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
    open-frieren-offload = {
      title = "Move the movable services off frieren";
      kind = "open";
      status = "OPEN";
      priority = "P3";
      date = "2026-10-21";
      summary = "frieren's persistent footprint is small and named; stirling-pdf moves (stateless), hermes waits on a cutover, and paperless plus immich stay by operator decision — their data and their family users live there.";
      refs = {
        hosts = ["frieren" "delphi"];
        modules = ["hosts/frieren/infra-stack.nix" "modules/profiles/service-exposure.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        **Measured on frieren.** system.slice totals about 2.4 GiB: paperless
        task-queue 389 MiB, immich-server 292 MiB, stirling-pdf 188 MiB, jellyfin
        105 MiB, home-assistant 82 MiB, influxdb 77 MiB. In the user slice the
        persistent outlier is hermes at 340 MiB; the 1.3 GiB and 600 MiB entries
        are the agent and browser of the current session, not services.

        **Settled by the operator (2026-10-21).** paperless and immich stay: the
        personal data and the family users are on frieren, and a move would mean
        re-doing that setup by hand. The rule that falls out is sharper than
        "move stateless services": move what has no library and no shared logins.

        **stirling-pdf moved (2026-10-21).** Stateless, so it was the one service
        worth moving: the unit is gone from this host's system.slice, delphi
        serves it on tailnet 8445, and frieren's closure fell 1005 MiB
        (31.88 → 30.82 GB) with 87 MiB of cgroup going with it. Its aarch64
        closure is not on cache.nixos.org, so the first build ran on two A1
        cores (~40 min) and delphi needs ~60 s of JVM warmup before the mount
        answers 200 rather than 502. `pdf.frieren.lan` no longer serves it.

        **Candidates left.** hermes, 342 MiB and 226 MiB of state in `~/.hermes`,
        needs a cutover decision: one bot token cannot be polled twice, so the
        sequence is copy state, enable on delphi, stop frieren, and measure.

        **Exit.** Each moved unit is gone from frieren's system.slice, serves from
        delphi over the tailnet, and `systemctl show -p MemoryCurrent` on frieren
        shows the release. hermes is the last one, and only with an agreed window.
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
      status = "IN FLIGHT";
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
          files (17%), 66 banner rules, 86 dated narratives outside `AUDIT.md`.

        **Landed.** `checks:repo:paths` fails on a hardcoded checkout path and runs in
        `checks:quick`; the paths it named now resolve from `git rev-parse`, `../..`, or
        `Path(__file__)`. The pstack method skills (`correct`, `no-comments`, `unslop`,
        `prove-it-works`) are installed under `.agents/skills/`.

        Every `checks:decision:*` task accepts `--fail-on-alert` and exits 1 on a
        non-nominal status, category, safety flag or error; proved on
        `checks:decision:smart` and the `sops-rekey`/`disk-smart`/`vuln-proposer` simulate
        paths. Tasks probe the flag before using the installed binary, so a stale closure
        falls back to the repo source.

        **Open, in `correct` order.** Add a gate so a hand-typed count cannot land; add a
        doc-link gate; then the `no-comments` and `unslop` passes.

        **Exit.** Each gate above exists and has failed on the instance that motivated
        it; this note then reads DELIVERED with `refs.tasks` naming them.
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
        genuine pull (`0dfff23c`, submodule `7a35ad4` matching frieren byte-for-byte) the store file
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
      status = "OPEN";
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
           AGENTS.md § Home Initialization). A fork must list what it keeps: reachability and the
           canonical path are not rice.

        Documentation rule that came with this: rationale goes here or in a policy, not into comment
        blocks in `.nix` files — `nix-header-budget` bounds headers, and the body-comment essays this run
        produced are what the `agent-prose-budget` squeeze caught (a duplicated `tpm-sops` SKILL went so
        `docs/sops-rekey.md` stays the single home).
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
        docs = ["AUDIT.md"];
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
  };
}
