{
  config,
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
        ../nixoshmsymlinks.nix
        ../nixvim
      ];
      home.username = "devji";
      home.homeDirectory = "/home/devji";
      home.packages = with pkgs;
        [
        ]
        ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        ]
        ++ lib.optionals stdenv.hostPlatform.isAarch64 [
          # utilities for arm64 raspi
          yt-dlp
          pass
          cmus
          bitwarden-cli
          glow
          pop
          charm-freeze
          # viu
          wkhtmltopdf
          ghostscript
          #        texlive.combined.scheme-full
          pandoc
          mods
          aichat
          tgpt
          jekyll
          bundler
          tldr
          scc

          hare
          haredoc
          go
          cargo
          tinygo
          wasmtime
          luajit
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
  #  environment.sessionVariables = {
  #  EDITOR = "hx";
  #  };
}
