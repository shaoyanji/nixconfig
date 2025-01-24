{
  config,
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
        ../env.nix
        ../sops.nix
      ];
      home.stateVersion = "25.05";
      home.username = "devji";
      home.homeDirectory = "/home/devji";
      programs.home-manager.enable = false;
      home.packages = with pkgs; [
        git
        helix
      ];
      home.file = {
      };
      #home.sessionPath = ["/mnt/mac/Volumes/peachcable/bin-aarch64/"];
      xdg.configFile = {
        # "nixconfig".source = config.lib.file.mkOutOfStoreSymlink "/mnt/mac/Volumes/usbshare2/projects/repo/nixconfig";
      };
   };
   sharedModules = [
      #  sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
    environment.sessionVariables = {
      EDITOR = "hx";
    };
}
