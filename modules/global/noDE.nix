{
  pkgs,
  inputs,
  lib,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./minimal.nix
        ../shell
      ];
      home.username = "devji";
      home.homeDirectory = "/home/devji";
      home.packages = with pkgs;
        [
        ]
        ++ lib.optionals stdenv.isLinux [
        ]
        ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        ]
        ++ lib.optionals stdenv.hostPlatform.isAarch64 [
        ];
      home.file = {
      };
      xdg.configFile = {
      };
    };
    sharedModules = [
      #  sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
  environment.sessionVariables = {
  };
}
