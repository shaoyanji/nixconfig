{pkgs, ...}: {
  home.username = "alarm";
  home.homeDirectory = "/home/alarm";
  # home.stateVersion = "24.11"; # Please read the comment before changing.

  # The role list (roles.minimal) is this host's `hmModules` entry in
  # flake/host-inventory.nix, resolved by global.hm-inventory-role.

  home.packages = with pkgs; [
    # neovim
  ];

  programs.home-manager.enable = true;
}
