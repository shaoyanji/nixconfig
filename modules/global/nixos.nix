# NixOS home-manager embedded configuration.
# Primary user constants: modules/global/user.nix
{inputs, ...}: {
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
    extraSpecialArgs = {inherit inputs;};
  };
}
