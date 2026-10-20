{
  inputs,
  self,
  nixpkgs,
}: let
  inherit (nixpkgs) lib;
  systems = import ./systems.nix {inherit (inputs) flake-utils;};
  pkgsFor = import ./pkgs-for.nix {inherit nixpkgs;};
  mkNixosHost = import ../lib/mk-nixos-host.nix {inherit nixpkgs inputs self;};
  # Compiled fleet inventory (lib/inventory.nix). Parsed once here and shared
  # into module chains, checks and packages — hosts never re-parse inventory.toml.
  inventory = import ../lib/inventory.nix {inherit lib;};
  moduleSets = import ./module-sets.nix {inherit inputs self lib inventory;};
  hostInventory = import ./host-inventory.nix {inherit inputs moduleSets self;};
  hostProjection = import ./host-projection.nix {inherit lib hostInventory;};
  projectHosts = hostProjection.project;
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
  agentDocs = pkgsFor "x86_64-linux";
in {
  packages = import ./packages.nix {
    inherit inputs lib systems pkgsFor inventory;
  };

  apps = lib.genAttrs systems.default (_: {});

  # `checks` is the CHEAP set — it must never force a host configuration (see
  # the budget rule at the top of flake/checks.nix).
  checks = import ./checks.nix {
    inherit lib systems pkgsFor self hostInventory skillsCtl agentsNotesCtl;
  };

  # Per-host evaluation gate, one host per attribute so a run costs one host's
  # worth of evaluator heap instead of the whole fleet's. Not part of `checks`
  # because `nix flake check` forces every attribute of that output in a single
  # process. Drive it with `task checks:host:HOST=` (one) or `task checks:hosts`
  # (sequential sweep); CI runs the affected hosts.
  hostChecks = import ./host-checks.nix {
    inherit lib systems pkgsFor self hostInventory;
  };

  devShells = import ./devshells.nix {
    inherit lib systems pkgsFor self;
  };

  homeConfigurations = import ./home-configurations.nix {
    inherit inputs nixpkgs projectHosts self;
  };

  nixosConfigurations = import ./nixos-configurations.nix {
    inherit mkNixosHost projectHosts inputs self;
  };

  darwinConfigurations = import ./darwin-configurations.nix {
    inherit inputs projectHosts self;
  };

  # Expose the package set, including overlays, for convenience.
  darwinPackages = self.darwinConfigurations.cassini.pkgs;

  # `nix build .#docs` — the generated markdown tree (fleet inventory, modules
  # registry, per-host pages) as a store path. The rendered site is
  # `.#fleet-docs-site` (lib/aki-site.nix), built natively from the compiled
  # registry and the knowledge graph; the Python renderer that used to live in
  # docs-site/ is retired (docs/docs-pipeline-audit.md §4).
  inherit docs;

  inherit hostProjection;

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
    inherit (agentsNotesCtl) schemaVersion counts issues ok index notes byHost byModule byTask byStatus open;
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
