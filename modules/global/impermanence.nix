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
        inputs.impermanence.nixosModules.home-manager.impermanence
        #./minimal.nix
        #../nixoshmsymlinks.nix
        ./heim.nix
        ../hypr
      ];

      home.stateVersion = "25.05"; # Please read the comment before changing.

      home.persistence."/persist/home" = {
        directories = [
          "Downloads"
          "Music"
          "Pictures"
          "Documents"
          "Videos"
          ".ssh"
          ".supermaven"
          ".local/share/keyrings"
          ".local/share/direnv"
          ".config/direnv"
          ".zen"
          {
            directory = ".local/share/Steam";
            method = "symlink";
          }
        ];
        files = [
          ".config/sops/age/keys.txt"
        ];
        allowOther = true;
      };
    };
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
}
