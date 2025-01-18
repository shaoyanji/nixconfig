{ config, pkgs, inputs, ... }:
{
    home-manager= {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension= "hm-backup"; #for rebuild
        users.devji =  {
            imports = [ 
                ./heim.nix
                ../hypr
            ];
        }; 
        sharedModules = [
           #  sops-nix.homeManagerModules.sops
           ];
        extraSpecialArgs = { inherit inputs; }; # Pass inputs to homeManagerConfiguration

    };
}
