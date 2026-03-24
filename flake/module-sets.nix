{inputs, self}: let
  globalModules = [
    {
      system.configurationRevision = self.rev or self.dirtyRev or null;
    }
    ../modules/global/global.nix
  ];
in rec {
  inherit globalModules;
  globalModulesNixos =
    globalModules
    ++ [
      ../modules/global/nixos.nix
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.nur.modules.nixos.default
      inputs.nix-index-database.nixosModules.nix-index
      inputs.niri.nixosModules.niri
      inputs.dms.nixosModules.dank-material-shell
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
  globalModulesHome = [
    inputs.kickstart-nixvim.homeManagerModules.default
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-index-database.homeModules.nix-index
  ];
}
