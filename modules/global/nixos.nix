# NixOS home-manager embedded configuration.
# Primary user constants: modules/global/user.nix
{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./home-manager-shared.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.devji = {
      imports = [
        ../roles/heim.nix
      ];
    };
    extraSpecialArgs = {inherit inputs;};
  };
}
