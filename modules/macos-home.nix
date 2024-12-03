{ pkgs, lib, config, ... }:

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
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/FRITZ.NAS/External-USB3-0-01/documents/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/FRITZ.NAS/External-USB3-0-01/documents/work";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/Shared Library/ollama";
    "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/Shared Library/go/pkg";
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/Shared Library/dotfiles/btop";
    ".config/cmus".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/Shared Library/dotfiles/cmus";
  };

    home.sessionVariables = {
  };
    programs.home-manager.enable = true;
}
