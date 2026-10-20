# NixOS home-manager embedded configuration.
{
  inputs,
  self,
  config,
  ...
}: {
  imports = [
    ./home-manager-shared.nix
  ];

  nixpkgs.overlays = [
    (import ../../overlays/nushell-plugins-compat.nix)
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.devji = {
      imports = [
        ../roles/home.nix
      ];
    };
    # `self` gives home modules the flake's compiled artifacts (homeAgents,
    # agentSkills, …) without re-reading the repo at activation time.
    extraSpecialArgs = {
      inherit inputs self;
      fleetHost = config.networking.hostName;
    };
  };
}
