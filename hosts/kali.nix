{pkgs, ...}: {
  home.username = "kali";
  home.homeDirectory = "/home/kali";
  # home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [
    ../modules/global/minimal.nix
    ../modules/nixvim
  ];

  home.packages = with pkgs; [
    # neovim
  ];

  programs.home-manager.enable = true;
}
