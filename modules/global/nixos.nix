{
  config,
  pkgs,
  inputs,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./heim.nix
      ];
    };
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
}
