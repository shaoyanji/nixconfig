{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../lf
    ../env.nix
    #    ../shell
    ../shell/tmux.nix
    ../shell/bash.nix
    ../sops.nix
    ../helix.nix
    # ../shell/nushell.nix
    #    ../nixvim
  ];
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      options = [
        "--cmd cd"
      ];
    };
    fzf.enable = true;
  };
  home = {
    stateVersion = "25.05";
    packages = with pkgs;
      [
        #        (pkgs.uutils-coreutils.override {prefix = "";})
        duf
        graphviz
        graph-easy
        nix-output-monitor
        # qrencode
        # thefuck
        jq
        htmlq
        ripgrep
        fd
        zsh-forgit
        zsh-fzf-history-search
        #zsh-fzf-tab
        bat
        eza
        gum
        go-task
        fzf
        yq-go
        zoxide
        cloak
        age
        mailsy
        awscli2
        cloudflared
        btop
        direnv
        devenv
        nmap
        tree
        sqlite
        hyperfine
        zip
        unzip
        p7zip
        mtr
        iperf3
        dnsutils
        ldns
        aria2
        socat
        ipcalc
        ffmpeg
        fastfetch
      ]
      ++ lib.optionals stdenv.isLinux [
        strace
        ltrace
        lsof
        sysstat
        pciutils
        usbutils
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };
}
