{
  pkgs,
  inputs,
  lib,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./minimal.nix
        ../shell
      ];
      home.username = "devji";
      home.homeDirectory = "/home/devji";
    };
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
}
