{ inputs
, self
,
}:
let
  globalModules = [
    {
      system.configurationRevision = self.rev or self.dirtyRev or null;
    }
    ../modules/global/global.nix
    # llm-agents.nix: prebuilt AI agent CLI packages under pkgs.llm-agents.<name>
    # Exposing the flake's packages attribute set directly ensures 100% cache hits
    # from https://cache.numtide.com instead of compiling from source.
    {
      nixpkgs.overlays = [
        (final: _prev: {
          llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
        })
      ];
    }
  ];
  # Minimal sharedModules for home-manager-only (standalone) configs.
  hmSharedModulesHome = [
    inputs.kickstart-nixvim.homeManagerModules.default
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-index-database.homeModules.nix-index
  ];
in
rec {
  inherit globalModules hmSharedModulesHome;
  globalModulesNixos =
    globalModules
    ++ [
      ../modules/global/nixos.nix
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.nix-index-database.nixosModules.nix-index
      inputs.dms.nixosModules.dank-material-shell
      # Greeter split out of the dms flake into AvengeMedia/dank-greeter
      # (2026-09): option is programs.dms-greeter now.
      inputs.dank-greeter.nixosModules.default
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
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.default
      inputs.nix-index-database.nixosModules.nix-index
    ];
  globalModulesDemo =
    globalModules
    ++ [
      ../modules/global/demo.nix
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
        nixpkgs.overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];
      }
    ];
}
