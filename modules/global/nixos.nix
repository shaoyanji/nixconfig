{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./heim.nix
        # ../hypr
        ../hypr/waybar.nix
        ../niri.nix
      ];
      home.packages = with pkgs; [
        # firefox-bin
      ];
      # xdg.configFile."niri/config.kdl".source = builtins.fetchurl {
      #   url = "https://raw.githubusercontent.com/YaLTeR/niri/refs/heads/main/resources/default-config.kdl";
      #   sha256 = "sha256:05bbav6xc8rx1fki49iv6y7grncp22afal6an31jjkqw2scq6bsd";
      # };
    };
    sharedModules = [
      # inputs.sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
}
