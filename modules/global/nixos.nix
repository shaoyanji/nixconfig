{ config, pkgs, inputs, ... }:

{
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension= "hm-backup"; #for rebuild
    home-manager.users.devji = import ./home2.nix;
    home-manager.sharedModules = [
        #  sops-nix.homeManagerModules.sops
    ];
    home-manager.extraSpecialArgs = { inherit inputs; }; # Pass inputs to homeManagerConfiguration
}
