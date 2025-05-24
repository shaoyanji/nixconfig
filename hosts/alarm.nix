{pkgs, ...}: {
  home.username = "alarm";
  home.homeDirectory = "/home/alarm";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [
    ../modules/global/minimal.nix
    ../modules/nixvim
  ];

  home.packages = with pkgs; [
    # neovim
  ];

  programs.home-manager.enable = true;
}
