# macOS (nix-darwin) home-manager configuration.
{
  self,
  user,
  ...
}: {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  config = {
    # home-manager.extraSpecialArgs lives in global.home-manager-shared: the
    # passthrough was byte-identical here and in global.nixos.
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
