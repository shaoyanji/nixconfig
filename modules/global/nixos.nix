# NixOS home-manager embedded configuration.
{
  inputs,
  self,
  config,
  lib,
  user,
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

  # Which parts of `roles.home` this host builds. A name the role does not know
  # is a typo, and an enum makes that an eval error instead of a silently
  # ignored string. Default is the full set in `modules/global/user.nix`.
  options.fleet.hmUserFeatures = lib.mkOption {
    type = lib.types.listOf (
      lib.types.enum ["systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"]
    );
    default = user.hmFeatures;
    description = "Named features of the desktop role (modules/roles/home.nix).";
  };

  config = {
    nixpkgs.overlays = [
      (import self.nixFiles.overlays."nushell-plugins-compat.nix")
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
        # mkForce-ing inside a role (see `roles/home.nix`).
        dankShell = config.fleet.dankShell.enable;
        # Same mechanism for the role's feature list: an import decision, taken
        # before `config` exists inside the HM module system.
        hmUserFeatures = config.fleet.hmUserFeatures;
      };
    };
  };
}
