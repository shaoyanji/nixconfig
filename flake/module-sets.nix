{
  inputs,
  self,
  lib,
  inventory,
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
  inventoryModules = [
    {_module.args.inventory = inventory;}
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
      ../modules/global/global.nix
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
      ../modules/user/ai/home-agents.nix
    ];
in rec {
  inherit globalModules hmSharedModulesHome inventoryModules;
  globalModulesNixos =
    globalModules
    ++ [
      ../modules/global/nixos.nix
      # Determinate Nix: one Nix binary for every NixOS host (rollback = the
      # generation). See the module header for the priority and registry traps.
      ../modules/global/determinate-nix.nix
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.nix-index-database.nixosModules.nix-index
      inputs.dms.nixosModules.dank-material-shell
      # Greeter lives in its own repo (duxlabs-dev/dux-greeter, ex-
      # AvengeMedia/dank-greeter): option is programs.dms-greeter.
      inputs.dank-greeter.nixosModules.default
    ];
  # Ryoku replaces the shell, not the system: it owns its compositor build,
  # session packages, portals, keyring and greeter preference. So this chain is
  # `globalModulesNixos` minus dms/dank-greeter (they would be a second
  # Quickshell shell in the same session), plus `modules/profiles/ryoku-desktop.nix`
  # in the host, which sets `fleet.dankShell.enable = false` to keep the DMS
  # home modules out of HM as well.
  globalModulesRyoku =
    globalModules
    ++ [
      ../modules/global/nixos.nix
      ../modules/global/determinate-nix.nix
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.nix-index-database.nixosModules.nix-index
      inputs.ryoku.nixosModules.default
    ];
  globalModulesImpermanence =
    globalModulesNixos
    ++ [
      ../modules/global/impermanence.nix
      inputs.impermanence.nixosModules.impermanence
      inputs.disko.nixosModules.default
    ];
  globalModulesMacos =
    globalModules
    ++ [
      ../modules/global/macos.nix
      inputs.nix-homebrew.darwinModules.nix-homebrew
      inputs.home-manager.darwinModules.default
      inputs.sops-nix.darwinModules.sops
    ];
  globalModulesContainers =
    globalModules
    ++ [
      ../modules/global/noDE.nix
      ../modules/global/determinate-nix.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.default
      inputs.nix-index-database.nixosModules.nix-index
    ];
  globalModulesDemo =
    globalModules
    ++ [
      ../modules/global/demo.nix
      ../modules/global/determinate-nix.nix
      inputs.home-manager.nixosModules.default
    ];
  # Standalone-home chain. These hosts build their own pkgs outside the
  # NixOS module system, so modules/global/global.nix (which carries the
  # repo-wide nixpkgs.config.allowUnfree = true policy) never applies.
  # Restore the same policy here — without it the unfree antigravity-cli
  # (pulled in via roles/minimal → user/ai) fails eval on alarm/kali.
  globalModulesHome =
    hmSharedModulesHome
    ++ [
      {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [inputs.llm-agents.overlays.shared-nixpkgs];
      }
    ];
}
