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
    ../shell/nushell.nix
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
    packages = with pkgs;
      [
        #        (pkgs.uutils-coreutils.override {prefix = "";})
        nix-output-monitor
        thefuck
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
        mailsy
        awscli2
        #cloudflared
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
      ]
      ++ lib.optionals stdenv.isLinux [
        strace
        ltrace
        lsof
        sysstat
        pciutils
        usbutils
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        mupdf
        mpv
        wl-clipboard
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [
        fastfetch
        yt-dlp
        age
        pass
        cmus
        bitwarden-cli
        glow
        pop
        charm-freeze
        viu
        wkhtmltopdf
        ghostscript
        #        texlive.combined.scheme-full
        pandoc
        mods
        aichat
        tgpt
        jekyll
        bundler
        tldr
        scc
        diff-so-fancy
        entr
        exiftool
        fdupes
        most
        procs
        # rip
        rsync
        sd
        tre
        bandwhich
        glances
        gping
        #dua-cli
        speedtest-cli
        #dog
        buku
        ddgr
        khal
        mutt
        newsboat
        rclone
        #taskwarrior3
        tuir
        httpie
        lazygit
        #ngrok
        asciinema
        navi
        #transfer
        #surge #x86
        epr
        #meetup-cli
        lynx
        #obs
        #hget
        translate-shell
        mc
        entr
        #gitmoji-cli
        #gitmoji-changelog
        #sparkly-cli
        #lowcharts
        hare
        haredoc
        go
        cargo
        tinygo
        wasmtime
        luajit
        alsa-utils
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };
}
