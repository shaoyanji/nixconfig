{pkgs, ...}: {
  home.username = "kali";
  home.homeDirectory = "/home/kali";

  imports = [
    ../modules/env.nix
    ../modules/shell/nushell.nix
    ../modules/shell/tmux.nix
    ../modules/shell/starship.nix
    ../modules/global/minimal.nix
    ../modules/helix.nix
    # ../modules/global/home.nix
  ];
  home = {
    packages = with pkgs; [
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
      zoxide
      # aircrack-ng
      powershell
      secretscanner
      # seclists
      yt-dlp
      ytfzf
      mpv
    ];
    # stateVersion = lib.mkDefault "25.11";
    sessionVariables = {
      invidious_instance = "https://inv.perditum.com";
      TERM = "xterm-256color";
    };
  };
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
      options = [
        # "--cmd cd"
      ];
    };
    fzf.enable = true;
    fzf.tmux.enableShellIntegration = true;
  };
  programs.home-manager.enable = true;
}
