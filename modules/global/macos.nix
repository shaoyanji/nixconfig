# macOS (nix-darwin) home-manager configuration.
# Primary user constants: modules/global/user.nix
{inputs, ...}:
let
  user = import ../global/user.nix;
in
{
  imports = [
    ./home-manager-shared.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.${user.name} = {
      imports = [
        ../roles/home.nix
      ];
    }; # staging point for roles/home.nix commons
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
    # Optionally, use home-manager.extraSpecialArgs to pass
  };
  users.users.${user.name} = {
    name = user.name;
    home = "/Users/${user.name}";
  };
  # arguments to home.nix
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = user.name;
  };
}
