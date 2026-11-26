{
  inputs,
  self,
  lib,
  inventory,
  # flake/host-inventory.nix — the composition registry (kind, features,
  # modules, hmFeatures per host). Injected as a module arg so a module can
  # read a host's own declared lists instead of a global default.
  hostInventory,
  # Every file under modules/, named (flake/nix-registry.nix). Chains name
  # the architecture's feature lists — the shape is note arch-shape.
  # modules instead of pointing at them; the walk is the one list.
  moduleFiles,
}: let
  # Compiled fleet inventory (lib/inventory.nix), injected into EVERY chain so
  # every host kind — nixos, darwin, containers/demo, standalone home-manager —
  # gets both `{inventory, ...}` as a module argument and a read-only
  # `config.fleet.inventory`. `inventory.toml` is parsed exactly once, at flake
  # level, and the result is plain data shared by every host.
  #
  # `_module.args` is deliberate rather than only an option: reading a leaf
  # (`inventory.hosts.fern.role`) stays cheap and lazy, so this adds no
  # meaningful eval cost to any host.
  # Two modules, not one: the module system rejects `_module` at the top level
  # of a module that also declares `options`/`config` ("unsupported attribute
  # `_module` … move all of them into the explicit `config` attribute").
  #
  # `user` is the same shape and arrives for the same reason: the constants in
  # `modules/global/user.nix` used to be reached by relative path from 23
  # modules, which is the one edge the registry could not name. A module takes
  # `user` as an argument, so the file has one name (`.#modules."global.user"`)
  # and a rename fails `checks.nix-registry` instead of an eval.
  #
  # `systemdJobs` joins it for the identical reason: the timer/daemon skeleton
  # was restated as `import ../../lib/systemd-jobs.nix` in ten service modules
  # and one host file — the same unnamed edge.
  appendModules = extra: mods: mods ++ extra;
  inventoryModules = [
    {
      _module.args = {
        inherit inventory hostInventory;
        user = import moduleFiles."global.user";
        systemdJobs = import self.nixFiles.lib."systemd-jobs.nix" {inherit lib;};
      };
    }
    # `nvidiaPkgs`/`nginxPkgs`: second pkgs sets, lazy via `_module.args`.
    ({
      pkgs,
      config,
      ...
    }: {
      _module.args.nvidiaPkgs = import inputs.nixpkgs-nvidia {
        system = pkgs.stdenv.hostPlatform.system;
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
          cudaSupport = config.nixpkgs.config.cudaSupport or false;
          # forward host waivers (schneeeule gtk2: hosts/schneeeule/nvidia.nix)
          problems = config.nixpkgs.config.problems or {};
        };
      };
      _module.args.nginxPkgs = inputs.nixpkgs-nginx.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    })
    {
      options.fleet.inventory = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        description = "Compiled fleet inventory from inventory.toml (lib/inventory.nix).";
      };
      config.fleet.inventory = inventory;
    }
  ];

  globalModules =
    inventoryModules
    |> appendModules [
      {
        system.configurationRevision = self.rev or self.dirtyRev or null;
      }
      moduleFiles.global
      # llm-agents.nix: prebuilt AI agent CLI packages under pkgs.llm-agents.<name>
      # Exposing the flake's packages attribute set directly ensures 100% cache hits
      # from https://cache.numtide.com instead of compiling from source.
      {
        nixpkgs.overlays = [
          (import self.nixFiles.overlays."simplex-chat.nix")
          (import self.nixFiles.overlays."molly-brown.nix")
          (final: _prev: {
            llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
            antigravity-cli = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.antigravity-cli;
          })
        ];
      }
    ];
  # The Linux plumbing every NixOS-assembly feature shares: systemd policy,
  # Determinate Nix (one Nix binary for every NixOS host — see the module
  # header for the priority and registry traps), HM integration, sops and
  # nix-index. `nixos` and `containers` differ only in the kernel module that
  # precedes it; `demo` opts out of sops/nix-index and spells its own.
  nixosSupport = [
    moduleFiles."global.linux-systemd"
    moduleFiles."global.determinate-nix"
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Minimal sharedModules for home-manager-only (standalone) configs.
  hmSharedModulesHome =
    inventoryModules
    |> appendModules [
      inputs.sops-nix.homeManagerModules.sops
      inputs.nix-index-database.homeModules.nix-index
      # ~/AGENTS.md from `.#homeAgents.<host>`; standalone HM configs get
      # `fleetHost` from the home assembler in flake/outputs.nix.
      moduleFiles."user.ai.home-agents"
      moduleFiles."user.task-shim"
      # The host's own HM imports from its `hmModules` inventory entry — an
      # empty list for a host with no field, so the floor alone stands.
      moduleFiles."global.hm-inventory-role"
    ];
in rec {
  inherit globalModules hmSharedModulesHome inventoryModules appendModules;

  # A host is a list of named features, not one of seven chains.
  #
  # The `globalModules*` names were hand-composed lists over the same groups of
  # modules, so a host that differed by one module either forked a chain or grew
  # a file of imports. Naming the groups makes the difference data:
  # `features = ["base" "nixos" "dms"]` IS the desktop chain, in that order.
  #
  # The names below are derived, so `flake/host-inventory.nix` and every
  # `hosts/*` file kept working unchanged — and `checks:drv-equality` shows the
  # derivation of all 30 configurations did not move.
  featureModules = {
    # Only the inventory/user/systemdJobs injection — the floor every host
    # stands on. Hosts that take no chain at all (garnixMachine, netbook, the
    # microVM guests) name this one feature so `features` is never empty.
    inventory = inventoryModules;

    # inventory injection + configurationRevision + modules/global/global.nix +
    # the nixpkgs overlays (simplex-chat, molly-brown, llm-agents).
    base = globalModules;

    # The NixOS kernel of a desktop or VM host, over the shared support list.
    nixos = [moduleFiles."global.nixos"] ++ nixosSupport;

    # Dux shell: the compositor, greeter and Quickshell session every desktop
    # host runs. Imported as a unit — a host that owns its own shell would be a
    # second Quickshell session in the same compositor.
    dms = [
      inputs.dms.nixosModules.dank-material-shell
      # Greeter lives in its own repo (duxlabs-dev/dux-greeter, ex-
      # AvengeMedia/dank-greeter): option is programs.dms-greeter.
      inputs.dank-greeter.nixosModules.default
      moduleFiles."global.dms"
    ];

    impermanence = [
      inputs.impermanence.nixosModules.impermanence
      inputs.disko.nixosModules.default
      moduleFiles."global.impermanence"
    ];

    # disko without impermanence: stark/fern/delphi/sledgehammer partition the
    # disk but keep a persistent root. Used to be a hand-add on each of them —
    # four copies of the same input line, which is what a feature exists to
    # name. impermanence still bundles its own disko entry.
    disko = [
      inputs.disko.nixosModules.default
    ];

    # A container/WSL host: home-manager without a shell, and no
    # modules/global/nixos.nix.
    containers = [moduleFiles."global.noDE"] ++ nixosSupport;

    demo = [
      moduleFiles."global.demo"
      moduleFiles."global.linux-systemd"
      moduleFiles."global.determinate-nix"
      inputs.home-manager.nixosModules.default
    ];

    macos = [
      moduleFiles."global.macos"
      inputs.nix-homebrew.darwinModules.nix-homebrew
      inputs.home-manager.darwinModules.default
      inputs.sops-nix.darwinModules.sops
    ];

    # Standalone home-manager. These hosts build their own pkgs outside the
    # NixOS module system, so modules/global/global.nix (which carries the
    # repo-wide nixpkgs.config.allowUnfree = true policy) never applies.
    # Restore the same policy here — without it the unfree antigravity-cli
    # (pulled in via roles/minimal → user/ai) fails eval on alarm/kali.
    home =
      hmSharedModulesHome
      |> appendModules [
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [inputs.llm-agents.overlays.shared-nixpkgs];
        }
      ];
  };

  # `modules` is what a `hosts/*.nix` file used to contribute by hand.
  mkHost = {
    features,
    modules ? [],
  }:
    features
    |> lib.concatMap (f: featureModules.${f})
    |> appendModules modules;

  # The one place a host's module list is assembled: `features` is the host's
  # chain as data, `modules` its own additions. Every consumer (builders,
  # boot checks, the inventory-injection gate) composes through this so a host
  # spec is `features = [...]; modules = [...];` — an edit to the list lands on
  # exactly one host.
  hostModules = h:
    mkHost {
      features = h.features or [];
      modules = h.modules or [];
    };

  # The seven chain names as DATA: a chain is exactly its features, in order, and
  # the docs table is a projection of this rather than a second copy of it
  # (`task docs:build`, [[flake/policies.nix#generated-not-tracked]]). A host
  # never imports a chain by name — `mkHost`/`hostModules` is the only
  # composer; the keys exist so `docs:build` and inventory `module_chain`
  # strings have a real row to name.
  chainFeatures = {
    globalModulesNixos = ["base" "nixos" "dms"];
    globalModulesImpermanence = ["base" "nixos" "dms" "impermanence"];
    globalModulesMacos = ["base" "macos"];
    globalModulesContainers = ["base" "containers"];
    globalModulesDemo = ["base" "demo"];
    globalModulesHome = ["home"];
  };
}
