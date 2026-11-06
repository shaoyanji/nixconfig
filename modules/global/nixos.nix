# NixOS home-manager embedded configuration.
{
  inputs,
  self,
  config,
  lib,
  ...
}: {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  # `imports` is a module argument, so a fork has to be an option, not mkForce.
  options.fleet.hmUserModules = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [self.modules."roles.home"];
    description = "Home-manager modules for the embedded `devji` user.";
  };

  config = {
    nixpkgs.overlays = [
      (import ../../overlays/nushell-plugins-compat.nix)
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      users.devji = {
        imports = config.fleet.hmUserModules;
      };
      # `self` gives home modules the flake's compiled artifacts (homeAgents,
      # agentSkills, …) without re-reading the repo at activation time.
      extraSpecialArgs = {
        inherit inputs self;
        fleetHost = config.networking.hostName;
        # Lets a home module choose its imports by shell capability instead of
        # mkForce-ing inside a role (see `roles/home.nix`, Ryoku pilot).
        dankShell = config.fleet.dankShell.enable;
      };
    };
  };
}
