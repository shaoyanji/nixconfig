{ config, pkgs, inputs, ... }:
{
    imports = [
    ];
    home-manager= {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension= "hm-backup"; #for rebuild
        users.devji =  import ./home.nix;
        sharedModules = [
           #  sops-nix.homeManagerModules.sops
           ];
        extraSpecialArgs = { inherit inputs; }; # Pass inputs to homeManagerConfiguration
    };
}
