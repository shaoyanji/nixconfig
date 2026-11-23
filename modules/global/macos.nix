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
        # Same passthrough nixos.nix makes: without it, `dankShell` resolves
        # through `_module.args` — which forces `config` inside `imports`,
        # the recursion that broke cassini's eval.
        dankShell = config.fleet.dankShell.enable;
        hmUserFeatures = config.fleet.hmUserFeatures;
        hmBaseFeatures = config.fleet.hmBaseFeatures;
        hmAiFeatures = config.fleet.hmAiFeatures;
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
