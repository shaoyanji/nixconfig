{ pkgs, ... }:

{
  imports = [ 
    ./home.nix
    ../dev.nix
  ];
  home = {
    username = "devji";
    homeDirectory= "/home/devji";
    stateVersion = "24.11"; # Please read the comment before changing.
    packages = with pkgs; [
      wl-clipboard
#   system call monitoring
      strace # system call monitoring
      ltrace # library call monitoring
      lsof # list open files
#   system tools
      sysstat
      lm_sensors # for `sensors` command
      ethtool
      pciutils # lspci
      usbutils # lsusb
    ];

    file = {
    };

    sessionVariables = {
    };
  };
 
  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "obsidian"
  # ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
