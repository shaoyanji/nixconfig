{
  inputs,
  moduleSets,
  nixpkgs,
}: let
  inherit (moduleSets) globalModulesHome;
in {
  penguin = inputs.home-manager.lib.homeManagerConfiguration {
    extraSpecialArgs = {inherit inputs;};
    pkgs = nixpkgs.legacyPackages."x86_64-linux";
    modules =
      globalModulesHome
      ++ [
        ../hosts/penguin.nix
      ];
  };

  alarm = inputs.home-manager.lib.homeManagerConfiguration {
    extraSpecialArgs = {inherit inputs;};
    pkgs = nixpkgs.legacyPackages."aarch64-linux";
    modules =
      globalModulesHome
      ++ [
        ../hosts/alarm.nix
      ];
  };

  kali = inputs.home-manager.lib.homeManagerConfiguration {
    extraSpecialArgs = {inherit inputs;};
    pkgs = nixpkgs.legacyPackages."aarch64-linux";
    modules =
      globalModulesHome
      ++ [
        ../hosts/kali.nix
      ];
  };
}
