{
  lib,
  pkgs,
  config,
  ...
}: let
  nixNAS = "/Volumes/data";
  # peachNAS = "/Volumes/peachcable";
  # routerNAS = "/mnt/y";
  # sharedNAS = "/Volumes/Shared Library/core";
  # wolfNAS = "/Volumes/usbshare2";
in {
  home = {
    packages = [
      # (
      #   pkgs.writers.writeBashBin "chillhop" {} ''
      #     lowfi -t chillhop
      #   ''
      # )
      # (
      #   pkgs.writers.writeBashBin "lofigirl" {} ''
      #     lowfi -t lofigirl-new
      #   ''
      # )
    ];

    file = {
      #"nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
      "vaults/personal".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/Obsidian-Git-Sync";
      "vaults/work".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/work";
      "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/nixconfig";
      "Documents/jobby".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/jobby";
      "Documents/docs".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/documents";
      "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/books";
      "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/downloads";
      "Downloads/storage".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/storage";
      "Applications/appimages".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/appimages";
      "Music/muzik".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/music";
      "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/pics";
      "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/video";
      "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/cache/go/pkg";
      ".cargo/registry".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/cache/.cargo/registry";
      ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/ollama";
      # ".zen".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/zen";
      #".mozilla/firefox/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/firefox";
      # ".cloak/accounts.age".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/security/accounts.age";
      # key for cloak migrated to sops
      # ".cloak/key.txt".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/security/key.txt";
      "gokrazy/hello".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/hello";
      ".local/share/lowfi/chillhop.txt".source = builtins.fetchurl {
        url = "https://raw.githubusercontent.com/talwat/lowfi/refs/heads/main/data/chillhop.txt";
        sha256 = "sha256:0r6x15f09h8k2apxbpiplvwh44n4cfip9fac52y74vap7s8hw3ll";
      };
      # ".local/share/lowfi/lofigirl-new.txt".source = builtins.fetchurl {
      #   url = "https://raw.githubusercontent.com/talwat/lowfi/refs/heads/main/data/lofigirl-new.txt";
      #   sha256 = "sha256:1s9gi7sxsfbvabm6apk0r9phns25f45vsdn9xqdc431gkrsg429s";
      # };
      # ".local/share/lowfi/synthboy.txt".source = builtins.fetchurl {
      #   url = "https://raw.githubusercontent.com/talwat/lowfi/refs/heads/main/data/synthboy.txt";
      #   sha256 = "sha256:1v315rp5fxshgwq8zxavdprppbr00yash3xvks744yb38d6rsw76";
      # };
      # ".local/share/lowfi".source = ./config/lowfi;
      ".simplex".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/.simplex";
    };
    sessionPath =
      ["${nixNAS}/bin-script"]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isAarch64 [
        # "${nixNAS}/bin-aarch64"
        # "/opt/homebrew/bin/"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 ["${nixNAS}/bin-x86"];
    sessionVariables = {};
  };

  xdg.configFile = {
    #    "btop".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/btop";
    #    "cmus".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/cmus";
    #    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/ghostty";
    "nixpkgs/config.nix".text = ''
      {
        packageOverrides = pkgs: {
          nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/main.tar.gz") {
            inherit pkgs;
          };
        };
      }
    '';
    "ghostty/config".text =
      /*
      ini
      */
      ''
                font-family = JetBrainsMono Nerd Font Mono
                font-size = 14
                background-opacity = 0.88888888
                gtk-titlebar = false

                keybind = ctrl+shift+'=new_split:right
                keybind = ctrl+shift+enter=new_split:down
                keybind = ctrl+enter=unbind
                keybind = ctrl+'=toggle_fullscreen
                keybind = ctrl+n=new_window

        #        shell-integration = bash
      '';
    "elvish/rc.elv".source = builtins.fetchurl {
      url = "https://gist.githubusercontent.com/shaoyanji/656406074a590a09e33755b88ac29d53/raw/rc.elv";
      sha256 = "0b0078sp6fyqygxz9hap7inhpnwz17s0vcpb4fgklzxa2h8kp194";
    };
  };
}
