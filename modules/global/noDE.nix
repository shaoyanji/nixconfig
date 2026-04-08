{
  pkgs,
  inputs,
  lib,
  config,
  ...
}: {
  # Disable opencode for container/infrastructure hosts (thinsandy, mtfuji, etc.)
  ai.opencode.enable = lib.mkDefault false;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ../roles/minimal.nix
        ../shell
      ];
      home.username = "devji";
      home.homeDirectory = "/home/devji";
    };
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
    ];
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
    };
  };
}
