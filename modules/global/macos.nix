{inputs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./home.nix
        ../nixoshmsymlinks.nix
      ];
    }; #staging point for ./home.nix commons
    sharedModules = [
      #  sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
    # Optionally, use home-manager.extraSpecialArgs to pass
  };
  users.users.devji = {
    name = "devji";
    home = "/Users/devji";
  };
  # arguments to home.nix
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "devji";
  };
}
