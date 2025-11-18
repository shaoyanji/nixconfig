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
        ../nixoshmsymlinks.nix
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
          # utilities for arm64 raspi
          yt-dlp
          pass
          cmus
          wkhtmltopdf
          ghostscript
          #        texlive.combined.scheme-full
          pandoc
          # jekyll
          # bundler
          # scc
          # hare
          # haredoc
          # go
          # cargo
          # tinygo
          # wasmtime
          # luajit
          alsa-utils
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
    EDITOR = "nvim";
  };
}
