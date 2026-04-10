# Container/no-DE home-manager configuration.
# Primary user constants: modules/global/user.nix
#
# NOTE: sharedModules intentionally do NOT import home-manager-shared.nix
# because container hosts should not pull in dms/niri desktop modules.
let
  user = import ./user.nix;
in {
  inputs,
  config,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${user.name} = {
      imports = [
        ../roles/minimal.nix
        ../shell
      ];
      home.username = user.name;
      home.homeDirectory = user.home;
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
