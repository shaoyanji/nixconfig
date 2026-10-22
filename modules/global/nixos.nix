# NixOS home-manager embedded configuration.
{
  inputs,
  self,
  config,
  lib,
  ...
}: {
  imports = [
    ./home-manager-shared.nix
  ];

  # The embedded user's module list, as an option so a host can *fork* it
  # instead of inheriting. The fleet default is the shared desktop role; a host
  # that is deliberately a different desktop (a suckless dwl session, say) sets
  # its own list, because otherwise the WM changes and the userland — zen, niri,
  # kitty, DMS, zed — comes along anyway. `imports` is a module argument, not a
  # mergeable list option, so it cannot be `mkForce`d at the call site.
  options.fleet.hmUserModules = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [../roles/home.nix];
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
      };
    };
  };
}
