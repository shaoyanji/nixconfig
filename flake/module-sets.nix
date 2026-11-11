{
  inputs,
  self,
  lib,
  inventory,
  # Every file under modules/, named (flake/nix-registry.nix). Chains name
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
  inventoryModules = [
    {
      _module.args = {
        inventory = inventory;
        user = import moduleFiles."global.user";
      };
    }
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
    ++ [
      {
        system.configurationRevision = self.rev or self.dirtyRev or null;
      }
      moduleFiles.global
      # llm-agents.nix: prebuilt AI agent CLI packages under pkgs.llm-agents.<name>
      # Exposing the flake's packages attribute set directly ensures 100% cache hits
      # from https://cache.numtide.com instead of compiling from source.
      {
        nixpkgs.overlays = [
          (import ../overlays/simplex-chat.nix)
          (import ../overlays/molly-brown.nix)
          (final: _prev: {
            llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
            antigravity-cli = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.antigravity-cli;
          })
        ];
      }
    ];
  # Minimal sharedModules for home-manager-only (standalone) configs.
  hmSharedModulesHome =
    inventoryModules
    ++ [
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.sops-nix.homeManagerModules.sops
      inputs.nix-index-database.homeModules.nix-index
      # ~/AGENTS.md from `.#homeAgents.<host>`; standalone HM configs get
      # `fleetHost` from the home assembler in flake/outputs.nix.
      moduleFiles."user.ai.home-agents"
    ];
in rec {
  inherit globalModules hmSharedModulesHome inventoryModules;

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
    # inventory injection + configurationRevision + modules/global/global.nix +
    # the nixpkgs overlays (simplex-chat, molly-brown, llm-agents).
    base = globalModules;

    # The NixOS kernel of a desktop or VM host.
    nixos = [
      moduleFiles."global.nixos"
      # Determinate Nix: one Nix binary for every NixOS host (rollback = the
      # generation). See the module header for the priority and registry traps.
      moduleFiles."global.determinate-nix"
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.nix-index-database.nixosModules.nix-index
    ];

    # Dux shell: the compositor, greeter and Quickshell session every desktop
    # host runs. Imported as a unit — a host that owns its own shell would be a
    # second Quickshell session in the same compositor.
    dms = [
      inputs.dms.nixosModules.dank-material-shell
      # Greeter lives in its own repo (duxlabs-dev/dux-greeter, ex-
      # AvengeMedia/dank-greeter): option is programs.dms-greeter.
      inputs.dank-greeter.nixosModules.default
    ];

    impermanence = [
      moduleFiles."global.impermanence"
      inputs.impermanence.nixosModules.impermanence
      inputs.disko.nixosModules.default
    ];

    # A container/WSL host: home-manager without a shell, and no
    # modules/global/nixos.nix.
    containers = [
      moduleFiles."global.noDE"
      moduleFiles."global.determinate-nix"
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.default
      inputs.nix-index-database.nixosModules.nix-index
    ];

    demo = [
      moduleFiles."global.demo"
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
      ++ [
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
    lib.concatMap (f: featureModules.${f}) features ++ modules;

  # The seven chain names as DATA: a chain is exactly its features, in order, and
  # the docs table is a projection of this rather than a second copy of it
  # (`docs/generated/fleet-module-chains.md`,
  # [[flake/policies.nix#generated-not-tracked]]).
  chainFeatures = {
    globalModulesNixos = ["base" "nixos" "dms"];
    globalModulesImpermanence = ["base" "nixos" "dms" "impermanence"];
    globalModulesMacos = ["base" "macos"];
    globalModulesContainers = ["base" "containers"];
    globalModulesDemo = ["base" "demo"];
    globalModulesHome = ["home"];
  };

  globalModulesNixos = mkHost {features = chainFeatures.globalModulesNixos;};
  globalModulesImpermanence = mkHost {features = chainFeatures.globalModulesImpermanence;};
  globalModulesMacos = mkHost {features = chainFeatures.globalModulesMacos;};
  globalModulesContainers = mkHost {features = chainFeatures.globalModulesContainers;};
  globalModulesDemo = mkHost {features = chainFeatures.globalModulesDemo;};
  globalModulesHome = mkHost {features = chainFeatures.globalModulesHome;};
}
