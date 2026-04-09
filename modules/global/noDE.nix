# Container/no-DE home-manager configuration.
# Primary user constants: modules/global/user.nix
#
# NOTE: sharedModules intentionally do NOT import home-manager-shared.nix
# because container hosts should not pull in dms/niri desktop modules.
{
  inputs,
  config,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
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
