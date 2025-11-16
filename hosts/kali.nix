{pkgs, ...}: {
  home.username = "kali";
  home.homeDirectory = "/home/kali";

  imports = [
    # ../modules/global/minimal.nix
    ../modules/global/home.nix
    ../modules/nixoshmsymlinks.nix
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
    # aircrack-ng
    powershell
    secretscanner
    # seclists
    yt-dlp
  ];
  home.sessionVariables = {
    TERM = "xterm-256color";
  };
  programs.home-manager.enable = true;
}
