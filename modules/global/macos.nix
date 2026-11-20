# macOS (nix-darwin) home-manager configuration.
{
  inputs,
  config,
  self,
  user,
  ...
}: {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  config = {
    home-manager = {
      extraSpecialArgs = {
        inherit inputs self;
        # lib/home-agents.nix keys on the inventory name; this is that name.
        fleetHost = config.networking.hostName;
        hmUserFeatures = config.fleet.hmUserFeatures;
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
  };
}
