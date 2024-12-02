{ pkgs, lib, config, ... }:

{
  home.stateVersion = "24.11";
  imports = [ 
    ./home.nix
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
    #"Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/FRITZ.NAS/External-USB3-0-01/documents/Obsidian-Git-Sync";
  };

    home.sessionVariables = {
  };
    programs.home-manager.enable = true;
}
