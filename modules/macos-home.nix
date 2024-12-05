{
  pkgs,
  lib,
  config,
  ...
}:
let  
    routerNAS = "/Volumes/FRITZ.NAS/External-USB3-0-01";
    routerShared = "/Volumes/Shared Library";
    wolfNAS = "/Volumes/usbshare2";
in
{
  home.stateVersion = "24.11";
  imports = [
    ./global/home.nix
  ];
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # ]  ++ lib.optionals stdenv.isDarwin [
    # cocoapods
    # m-cli # useful macOS CLI commands
    # wezterm
  ];
  home.file = {
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/work";
    "nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/nixconfig";
    ".config/nix-darwin".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
    "Music/muzik".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/music/";
    "Movies/video".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/video/";
    "Pictures/pics".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/pics/";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${routerShared}/ollama";
    "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${routerShared}/go/pkg";
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/btop";
      #    ".config/cmus".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/cmus";
  };

  home.sessionVariables = {
  };
  programs.home-manager.enable = true;
}
