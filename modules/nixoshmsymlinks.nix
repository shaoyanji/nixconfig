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
  home.file = {
    #"nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/work";
    "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/nixconfig";
    "Documents/jobby".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/jobby";
    "Documents/docs".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/documents";
    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/books";
    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/downloads";
    "Downloads/storage".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/storage";
    "Applications/appimages".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/appimages";
    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/music";
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
  };
  xdg.configFile = {
    #    "btop".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/btop";
    #    "cmus".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/cmus";
    #    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/ghostty";
    "ghostty/config".text =
      /*
      ini
      */
      ''
                theme = catppuccin-mocha
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
    "elvish/rc.elv".source = ./shell/rc.elv;
  };
  home.sessionPath =
    ["${nixNAS}/bin-script"]
    #    ++ lib.optionals pkgs.stdenv.hostPlatform.isAarch64 ["${nixNAS}/bin-aarch64"]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 ["${nixNAS}/bin-x86"];
}
