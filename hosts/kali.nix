{pkgs, ...}: {
  home.username = "kali";
  home.homeDirectory = "/home/kali";

  imports = [
    ../modules/shell/nushell.nix
    ../modules/shell/starship.nix
    ../modules/roles/minimal.nix
    # ../modules/roles/home.nix
  ];
  home = {
    packages = with pkgs; [
      lolcat
      figlet
      jp2a
      go
      gobuster
      steghide
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
