{pkgs, ...}: {
  home.username = "kali";
  home.homeDirectory = "/home/kali";
  # home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [
    # ../modules/global/minimal.nix
    ../modules/global/home.nix
  ];

  home.packages = with pkgs; [
    lolcat
    figlet
    jp2a
    graph-easy
    graphviz
    tgpt
    comrak
    go
    gobuster
    steghide
    pandoc
    aircrack-ng
    powershell
    secretscanner
    seclists
  ];

  programs.home-manager.enable = true;
}
