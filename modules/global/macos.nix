# macOS (nix-darwin) home-manager configuration.
# Primary user constants: modules/global/user.nix
{inputs, ...}: {
  imports = [
    ./home-manager-shared.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ../roles/home.nix
      ];
    }; # staging point for roles/home.nix commons
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
