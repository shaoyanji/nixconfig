{ pkgs, ... }:

{
  home.username = "devji";
  home.homeDirectory= "/home/devji";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [ 
    ./home.nix
    ../dev.nix
  ];
  
  nixpkgs.config.allowUnfree = true;

  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #           "obsidian"
  #         ];

  home.packages = with pkgs; [
    obsidian
    wl-clipboard
# system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

# system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

  ];
  home.file = {
  };

    home.sessionVariables = {
   };

  # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
}
