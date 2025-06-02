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
        ./minimal.nix
        ../nixoshmsymlinks.nix
        ../nixvim
      ];
      home.username = "devji";
      home.homeDirectory = "/home/devji";
      home.packages = with pkgs; [
      ];
      home.file = {
      };
      xdg.configFile = {
      };
    };
    sharedModules = [
      #  sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
  #  environment.sessionVariables = {
  #  EDITOR = "hx";
  #  };
}
