# macOS (nix-darwin) home-manager configuration.
{
  inputs,
  config,
  self,
  ...
}: let
  user = import ../global/user.nix;
in {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.${user.name} = {
      imports = [
        self.modules."roles.home"
      ];
    }; # staging point for roles/home.nix commons
    extraSpecialArgs = {
      inherit inputs self;
      # lib/home-agents.nix keys on the inventory name; this is that name.
      fleetHost = config.networking.hostName;
    };
    # Optionally, use home-manager.extraSpecialArgs to pass
  };
  users.users.${user.name} = {
    inherit (user) name;
    home = "/Users/${user.name}";
  };
  # arguments to home.nix
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = user.name;
  };
}
