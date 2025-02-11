{
  lib,
  pkgs,
  config,
  ...
}: let
  peachNAS = "/Volumes/peachcable";
  routerNAS = "/mnt/y";
  sharedNAS = "/Volumes/Shared Library";
  wolfNAS = "/Volumes/usbshare2";
in {
  home.file = {
    #"nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
    # "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/Obsidian-Git-Sync";
    # "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/work";
    # "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/nixconfig";
    "Documents/docs".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/documents";
    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/books";
    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/downloads";
    "Downloads/storage".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/storage";
    "Applications/appimages".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/appimages";
    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/music";
    "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/pics";
    "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/video";
    "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/go/pkg";
    ".cargo/registry".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/.cargo/registry";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/ollama";
    # ".zen".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/zen";
    #".mozilla/firefox/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/firefox";
    ".cloak/accounts.age".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/security/accounts.age";
    ".cloak/key.txt".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/security/key.txt";
    # ".cloak/accounts".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/security/accounts";
    "gokrazy/hello".source = config.lib.file.mkOutOfStoreSymlink "${peachNAS}/hello";
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
  };
  home.sessionPath =
    ["${peachNAS}/bin-scripts"]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isAarch64 ["${peachNAS}/bin-aarch64" "${peachNAS}/go/bin" "${peachNAS}/.cargo/bin"]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 ["${peachNAS}/bin-x86" "${peachNAS}/go/bin-x86"];
}
