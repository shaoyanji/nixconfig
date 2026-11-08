# macOS (nix-darwin) home-manager configuration.
{
  inputs,
  config,
  self,
  user,
  lib,
  ...
}: {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  # Same feature switch as the NixOS assembler (modules/global/nixos.nix); it is
  # declared here rather than shared because darwin imports neither that file
  # nor its option set.
  options.fleet.hmUserFeatures = lib.mkOption {
    type = lib.types.listOf (
      lib.types.enum ["systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"]
    );
    default = user.hmFeatures;
    description = "Named features of the desktop role (modules/roles/home.nix).";
  };

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
}
