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
        # mupdf
        # mpv
        pop
        glow
        charm-freeze # obsidian
        nixd
        viu
        qrencode
        wl-clipboard
        duf
        slides
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
        nmap
        ipcalc
        ipcalc
        ffmpeg
        fastfetch
        iftop

        file
        which
        tree
        gnused
        gnutar
        gawk
        zstd

        diff-so-fancy
        entr
        exiftool
        fdupes
        most
        procs
        rsync
        sd
        tre
        bandwhich
        glances
        gping
        speedtest-cli
        buku
        ddgr
        khal
        mutt
        newsboat
        rclone
        tuir
        httpie
        lazygit
        asciinema
        navi
        epr
        lynx
        translate-shell
        mc
      ]
      ++ lib.optionals stdenv.isDarwin [
        # python3
        cocoapods
        m-cli # useful macOS CLI commands
        #wezterm
        # darwin.xcode_16_1
        yt-dlp
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
