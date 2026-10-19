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
  # use (lib/docs.nix). Built for one system: it is markdown/HTML only, so the
  # output is system-independent and does not need a per-system fan-out.
  docsGen = import ../lib/docs.nix {inherit lib inventory;};
  docs = docsGen.mkDocs (pkgsFor "x86_64-linux");
  # Skills are compiled the same way the inventory is: parsed once, validated
  # once, consumed by checks/tasks/bundles. No host config is evaluated.
  skillsCtl = import ../lib/skills.nix {inherit lib;};
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
    inherit lib systems pkgsFor self hostInventory skillsCtl;
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

  # The site consumes the generated docs derivation, never the repo copy: the
  # page list and the pages themselves are the same build output git readers see
  # after `task docs:sync`.
  docsSite = (pkgsFor "x86_64-linux").callPackage ../docs-site/default.nix {inherit docs;};
  docs-site = self.docsSite;

  # `nix build .#docs` — generated markdown tree + nav.json (the site manifest).
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
  # Consumed by the hermes/frieren activation script as a store symlink.
  homeAgents = lib.genAttrs (builtins.attrNames hostInventory) (
    h: agentDocs.writeText "AGENTS-${h}.md" (homeAgentsGen.mkText h)
  );

  # Structural projection: hosts × skills × docs × mentions. `jq`-queryable
  # today, Cypher-exportable if an external graph database ever exists.
  knowledgeGraph = {
    inherit (knowledgeGraphCtl) graph json cypher;
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
