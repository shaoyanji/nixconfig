{pkgs, ...}: {
  home.username = "kali";
  home.homeDirectory = "/home/kali";

  imports = [
    # ../modules/global/minimal.nix
    ../modules/global/home.nix
  ];
  programs.starship.enable = true;
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
