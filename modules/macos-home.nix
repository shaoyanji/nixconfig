{
  pkgs,
  lib,
  config,
  ...
}:
let  
    routerNAS = "/Volumes/FRITZ.NAS/External-USB3-0-01";
    sharedNAS = "/Volumes/Shared Library";
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
    "Documents/docs".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/documents";
    "nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
    ".config/nix-darwin".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/nixconfig";
    "Music/muzik".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/music/";
    "Movies/video".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/videos/";
    "Pictures/pics".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/pics/";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/ollama";
    "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/go/pkg";
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/btop";
    ".cloak/accounts.age".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/secrets/cloak/accounts.age";
    ".cloak/keys.txt".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/security/keys.txt";
    # ".config/cmus".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/cmus";
    # ".cloak/accounts".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/security/accounts";
  };

  home.sessionVariables = {
  };
  programs.home-manager.enable = true;
}
