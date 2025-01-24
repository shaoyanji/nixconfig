{ config, pkgs, inputs, lib, ... }:
{
    home-manager= {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension= "hm-backup"; #for rebuild
        users.devji =  {
            imports = [
                ../env.nix
            ];
            home.stateVersion = "24.11";
            home.username = "devji";
            home.homeDirectory = "/home/devji";
            programs.home-manager.enable = true;
            home.packages = with pkgs; [
                task
                fzf
                gum
            ];
            home.file={
                "nixconfig".source = config.lib.file.mkOutOfStoreSymlink "/mnt/mac/Volumes/usbshare2/projects/repo/nixconfig";
            };

            xdg.configFile = {
            };
        }; 
        sharedModules = [
           #  sops-nix.homeManagerModules.sops
           ];
        extraSpecialArgs = { inherit inputs; }; # Pass inputs to homeManagerConfiguration

    };
}
