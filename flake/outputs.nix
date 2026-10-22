{
  inputs,
  self,
  nixpkgs,
}: let
  inherit (nixpkgs) lib;

  # --- assembly primitives ---------------------------------------------------
  # These four were separate files (systems/pkgs-for/host-projection + one file
  # per host kind), each a dozen lines with exactly one consumer: this file.
  # A file whose whole body is wiring between one node and another is not a
  # module, it is a hop — and a hop is what makes a grep lie about what exists.
  systems = {
    default = inputs.flake-utils.lib.defaultSystems;
    checks = ["x86_64-linux"];
  };

  overlays = [
    (import ../overlays/simplex-chat.nix)
    (import ../overlays/nvidia-persistenced-fix.nix)
    (import ../overlays/nushell-plugins-compat.nix)
    # kickstart.nixvim treesitter.nix still references the tmux grammar
    # that nvim-treesitter dropped upstream
    (import ../overlays/nvim-treesitter-tmux.nix)
  ];
  pkgsFor = system: import nixpkgs {inherit system overlays;};

  # The assembler is bound to a nixpkgs at construction time, so a host that
  # pins its own (netbook, on the 25.11 rev it boots) needs its own instance —
  # passing `nixpkgs` into the second call would be silently dropped by `...`.
  mkNixosHostWith = nixpkgs: import ../lib/mk-nixos-host.nix {inherit nixpkgs inputs self;};
  # Compiled fleet inventory (lib/inventory.nix). Parsed once here and shared
  # into module chains, checks and packages — hosts never re-parse inventory.toml.
  inventory = import ../lib/inventory.nix {inherit lib;};
  moduleSets = import ./module-sets.nix {inherit inputs self lib inventory;};
  hostInventory = import ./host-inventory.nix {inherit inputs moduleSets self;};

  # Inventory -> per-kind attrset. The kind is the only thing that decides which
  # assembler a host gets, so it is the only filter the flake needs.
  project = kind: fn: lib.mapAttrs fn (lib.filterAttrs (_: host: host.kind == kind) hostInventory);

  # Documentation + site nav generated from the SAME compiled registry the hosts
  # use (lib/docs.nix). Built for one system: it is markdown only, so the
  # output is system-independent and does not need a per-system fan-out.
  docsGen = import ../lib/docs.nix {
    inherit lib inventory;
    notes = agentsNotesCtl.pages;
  };
  docs = docsGen.mkDocs (pkgsFor "x86_64-linux");
  # Skills are compiled the same way the inventory is: parsed once, validated
  # once, consumed by checks/tasks/bundles. No host config is evaluated.
  skillsCtl = import ../lib/skills.nix {inherit lib;};
  # AGENTS.nix -> validated note index + rendered pages (lib/agents-notes.nix).
  # One source for the decisions, queue and design studies that used to be four
  # root markdown files; consumed by checks, docs and the query task.
  agentsNotesCtl = import ../lib/agents-notes.nix {inherit lib inventory;};
  homeAgentsGen = import ../lib/home-agents.nix {inherit lib inventory;};
  knowledgeGraphCtl = import ../lib/knowledge-graph.nix {
    inherit lib inventory;
    skills = skillsCtl;
  };
  # The rules the docs state, as predicates (flake/policies.nix). Compiled once
  # and asserted by `checks.policies`; docs cite an id instead of explaining it.
  policiesCtl = import ./policies.nix {inherit lib;};
  # The task graph as data (lib/taskfile.nix): names, include edges, violations
  # and a content digest. Pure — no pkgs, no host eval — so
  # `nix eval .#taskfileGraph.version` is a 4 s leaf read, and the same compile
  # feeds the flake check, the parity gate and any future generator.
  taskfileCtl = import ../lib/taskfile.nix {inherit lib;};
  agentDocs = pkgsFor "x86_64-linux";
in {
  packages = import ./packages.nix {
    inherit inputs lib systems pkgsFor inventory self;
  };

  apps = lib.genAttrs systems.default (_: {});

  # `checks` is the CHEAP set — it must never force a host configuration (see
  # the budget rule at the top of flake/checks.nix).
  checks = import ./checks.nix {
    inherit lib systems pkgsFor self hostInventory skillsCtl agentsNotesCtl policiesCtl taskfileCtl;
  };

  # `nix eval --json .#taskfileGraph.names` / `.version` — the graph, without a
  # derivation and without `task` installed.
  taskfileGraph = taskfileCtl;

  # `nix eval .#policies.uncitedPolicies` — the docs' rule registry as data.
  inherit (policiesCtl) policies ids citedIds danglingCitations uncitedPolicies unenforcedHardRules;

  # Per-host evaluation gate, one host per attribute so a run costs one host's
  # worth of evaluator heap instead of the whole fleet's. Not part of `checks`
  # because `nix flake check` forces every attribute of that output in a single
  # process. Drive it with `task checks:host:HOST=` (one) or `task checks:hosts`
  # (sequential sweep); CI runs the affected hosts.
  hostChecks = import ./host-checks.nix {
    inherit lib systems pkgsFor self hostInventory;
  };

  # Per-host RUNTIME gate: boot the host's real module graph in a VM and fail
  # unless stage-1 reaches stage-2 (`task checks:boot HOST=<host>`). Separate
  # output for the same reason as `hostChecks` — one boot test is one full host
  # evaluation plus a QEMU run, and `nix flake check` forces every attribute of
  # `checks` in a single process. See flake/boot-checks.nix for what it does and
  # does not prove.
  hostBootChecks = import ./boot-checks.nix {
    inherit lib inputs systems pkgsFor self hostInventory;
  };

  devShells = import ./devshells.nix {
    inherit lib systems pkgsFor self;
  };

  # --- the three host assemblers --------------------------------------------
  # One per kind, because the kind decides the assembler: nixpkgs.nixosSystem,
  # nix-darwin's darwinSystem, and a standalone home-manager configuration that
  # builds its own pkgs. Per-host specialArgs from host-inventory override the
  # { inherit inputs self; } default (see lib/mk-nixos-host.nix).
  nixosConfigurations = project "nixos" (hostName: host:
    (mkNixosHostWith (host.nixpkgs or nixpkgs)) {
      inherit hostName;
      inherit (host) system modules;
      specialArgs = host.specialArgs or {inherit inputs self;};
    });

  darwinConfigurations = project "darwin" (_: host:
    inputs.nix-darwin.lib.darwinSystem {
      inherit (host) system modules;
      specialArgs = host.specialArgs or {inherit inputs self;};
    });

  homeConfigurations = project "home" (name: host:
    inputs.home-manager.lib.homeManagerConfiguration {
      # `fleetHost` is the attrs key, which is the inventory name — the same key
      # `.#homeAgents` uses, so `~/AGENTS.md` resolves for every standalone host.
      extraSpecialArgs =
        (host.extraSpecialArgs or {})
        // {
          inherit self;
          fleetHost = name;
        };
      # Standalone HM hosts build their own pkgs; apply the repo overlays so
      # kickstart-nixvim's treesitter config resolves the tmux grammar that
      # nvim-treesitter dropped upstream.
      pkgs = nixpkgs.legacyPackages.${host.system}.extend (
        import ../overlays/nvim-treesitter-tmux.nix
      );
      inherit (host) modules;
    });

  # Expose the package set, including overlays, for convenience.
  darwinPackages = self.darwinConfigurations.cassini.pkgs;

  # `nix build .#docs` — the generated markdown tree (fleet inventory, modules
  # registry, per-host pages) as a store path. The rendered site is
  # `.#fleet-docs-site` (lib/aki-site.nix), built natively from the compiled
  # registry and the knowledge graph; the Python renderer that used to live in
  # docs-site/ is retired (docs/docs-pipeline-audit.md §4).
  inherit docs;

  # Fast, cached entry point: `nix eval .#inventory.hosts.<host>.role` reads the
  # compiled registry WITHOUT evaluating a single host configuration.
  inherit inventory;

  # --- agent context plane --------------------------------------------------
  # `nix eval .#agentSkills.count` / `.#agentSkills.byTag.nix` are the live
  # index; `.agents/README.md` routes to it instead of keeping a second table.
  inherit (skillsCtl) indexJson;
  agentSkills = skillsCtl.index;

  # `~/AGENTS.md` per host: fleet preamble + compiled host card + persona.
  # Consumed by the home activation script as a store symlink.
  #
  # `builtins.toFile`, not `agentDocs.writeText`: this artifact is pure text, and
  # a derivation pinned to x86_64 (`agentDocs = pkgsFor "x86_64-linux"`) cannot
  # be built at all on an aarch64 host — installing delphi failed on
  # `AGENTS-delphi.md.drv` with "required system x86_64-linux" (2026-10-20).
  # toFile has no builder, so the same text is available on every architecture.
  homeAgents = lib.genAttrs (builtins.attrNames hostInventory) (
    h: builtins.toFile "AGENTS-${h}.md" (homeAgentsGen.mkText h)
  );

  # AGENTS.nix as a query surface: `nix eval .#agentsNotes.index` (no host
  # eval), `nix build .#agentsNotes.file` for the fixed JSON artifact.
  agentsNotes = {
    inherit (agentsNotesCtl) schemaVersion counts issues ok index notes byHost byModule byTask byDoc byStatus lineage origins frontier open;
    file = agentDocs.writeText "agents-notes.json" agentsNotesCtl.json;
    json = agentsNotesCtl.json;
  };

  # Structural projection: hosts × skills × docs × mentions. `jq`-queryable
  # today, Cypher-exportable if an external graph database ever exists.
  # `file` is the static artifact: a store path holding the same JSON, so a
  # consumer (ops:ask, a systemd unit, a CI job) can read a fixed document
  # instead of evaluating the flake — `nix build .#knowledgeGraph.file`.
  knowledgeGraph = {
    inherit (knowledgeGraphCtl) graph json cypher;
    file = agentDocs.writeText "knowledge-graph.json" knowledgeGraphCtl.json;
  };

  # A store-path bundle for home/fleet materialization: every skill tree plus
  # the compiled index. `modules/user/ai/skills/default.nix` links from here.
  agentSkillsBundle = agentDocs.runCommand "agent-skills-bundle" {} ''
    mkdir -p $out
    cp -a ${../.agents/skills} $out/skills
    cp ${agentDocs.writeText "agent-skills-index.json" skillsCtl.indexJson} $out/index.json
    chmod -R u+w $out
  '';
}
