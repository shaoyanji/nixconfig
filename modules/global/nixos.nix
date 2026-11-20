# NixOS home-manager embedded configuration.
{
  inputs,
  self,
  config,
  ...
}: {
  imports = [
    self.modules."global.home-manager-shared"
  ];

  config = {
    nixpkgs.overlays = [
      (import self.nixFiles.overlays."nushell-plugins-compat.nix")
    ];

    home-manager = {
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
