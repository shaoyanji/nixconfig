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
  # The systems this flake produces shells, packages, apps and checks for. It
  # used to be flake-utils' defaultSystems, which includes both darwin entries:
  # the root then advertised two macOS devshells and a macOS package set, so any
  # surface that walks the outputs (flake show/check, an editor, a completion
  # helper) instantiated darwin nixpkgs on a Linux-only host. The one darwin
  # machine is configuration-only and stays reachable by name through
  # `darwinConfigurations`; nothing else fans out to it.
  systems = {
    work = ["x86_64-linux" "aarch64-linux"];
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
  # Fleet-wide gates (per-host eval checks + the all-in-one aggregate). One binding
  # because both outputs come from the same computation.
  fleetCtl = import ./fleet-checks.nix {inherit lib systems pkgsFor self inventory hostInventory;};

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
  # The CLI table is compiled once here and projected into both namespaces:
  # `packages.<system>.cli` for a store path, `apps.<system>.cli` for `nix run`.
  cliFor = system:
    import ./cli.nix {
      inherit lib inputs system;
      pkgs = pkgsFor system;
    };
in {
  packages = import ./packages.nix {
    inherit lib systems pkgsFor inventory cliFor docsGen skillsCtl agentsNotesCtl knowledgeGraphCtl self;
  };

  apps = lib.genAttrs systems.work (system: {cli = (cliFor system).apps;});

  # `checks` is the CHEAP set — it must never force a host configuration (see
  # the budget rule at the top of flake/checks.nix).
  checks = import ./checks.nix {
    inherit lib systems pkgsFor self hostInventory skillsCtl agentsNotesCtl policiesCtl taskfileCtl;
  };

  # `nix eval --json .#taskfileGraph.names` / `.version` — the graph, without a
  # derivation and without `task` installed.
  taskfileGraph = taskfileCtl;

  # The rules as data, looked up by id: `nix eval .#policies.ids`. The derived
  # queries (citedIds, danglingCitations, uncitedPolicies, unenforcedHardRules)
  # stay inside `flake/checks.nix`, which is their only consumer — exporting
  # them here was four root outputs nothing read.
  inherit (policiesCtl) policies;

  # Per-host evaluation gate, one host per attribute so a run costs one host's
  # worth of evaluator heap instead of the whole fleet's. Not part of `checks`
  # because `nix flake check` forces every attribute of that output in a single
  # process. Drive it with `task checks:host:HOST=` (one) or `task checks:hosts`
  # (sequential sweep); CI runs the affected hosts.
  hostChecks = import ./host-checks.nix {
    inherit lib systems pkgsFor self hostInventory;
  };

  # Every microVM guest's runner, addressable as an attribute instead of a
  # `./result-*` symlink in the checkout: `nix build .#microvmRunners.<name>`
  # prints the store path, and `nix eval --raw` gives it without building anything
  # else. Membership is the inventory (`category = "microvm"`), so a new guest is
  # reachable the moment it is registered — nothing here names it.
  microvmRunners = lib.mapAttrs (
    name: _: self.nixosConfigurations.${name}.config.microvm.declaredRunner
  ) (lib.filterAttrs (_: host: host.category == "microvm") inventory.hosts);

  # The fleet gate, in two shapes (see flake/fleet-checks.nix):
  #   fleetHostChecks.<system>.<host> — one host per attribute, membership from the
  #                                    compiled inventory. What the nightly gate
  #                                    starts, one systemd unit per host.
  #   fleetChecks.<system>            — all active hosts as one derivation. Tidy, but
  #                                    forces every host's config in one evaluator
  #                                    (measured 5.1 GiB / 12 hosts), so it is for CI
  #                                    and operators, not the nightly.
  inherit (fleetCtl) fleetChecks fleetHostChecks;

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

  # The generated markdown tree and the skills bundle are per-system packages,
  # and x86_64-linux only: `nix build .#artifacts.docs` compiles them on the host
  # that serves them, and aarch64 hosts simply do not carry the attribute. The
  # rendered site is `.#sites.fleet-docs-site` (lib/aki-site.nix).

  # Fast, cached entry point: `nix eval .#inventory.hosts.<host>.role` reads the
  # compiled registry WITHOUT evaluating a single host configuration.
  inherit inventory;

  # --- agent context plane --------------------------------------------------
  # `nix eval .#agentSkills.count` / `.#agentSkills.byTag.nix` are the live
  # index; `.agents/README.md` routes to it instead of keeping a second table.
  # `skillsCtl.indexJson` is that same index serialized, used only where a
  # string is needed (the bundle below); as a root output it was a second path
  # to one fact with no reader.
  agentSkills = skillsCtl.index;

  # `~/AGENTS.md` per host: fleet preamble + compiled host card + persona.
  # Consumed by the home activation script as a store symlink.
  #
  # `builtins.toFile`, not a derivation: this artifact is pure text, and a
  # derivation pinned to x86_64 cannot be built at all on an aarch64 host —
  # installing delphi failed on `AGENTS-delphi.md.drv` with "required system
  # x86_64-linux" (2026-10-20). toFile has no builder, so the same text is
  # available on every architecture.
  homeAgents = lib.genAttrs (builtins.attrNames hostInventory) (
    h: builtins.toFile "AGENTS-${h}.md" (homeAgentsGen.mkText h)
  );

  # AGENTS.nix as a query surface: `nix eval .#agentsNotes.index` (no host
  # eval). The document itself is typed data (`api`); JSON is made at the edge
  # by `.#artifacts.agents-notes`, not carried here as a string.
  agentsNotes = {
    inherit (agentsNotesCtl) api schemaVersion counts issues ok index notes byHost byModule byTask byDoc byStatus lineage origins frontier open;
  };

  # Structural projection: hosts × skills × docs × mentions. `jq`-queryable
  # today, Cypher-exportable if an external graph database ever exists. The
  # store artifact a non-evaluating consumer reads is `.#artifacts.knowledge-graph`.
  knowledgeGraph = {
    inherit (knowledgeGraphCtl) graph cypher;
  };
}
