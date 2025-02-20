{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../lf
    ../env.nix
    #../shell
    ../sops.nix
    ../helix.nix
    ../shell/tmux.nix
    ../shell/bash.nix
    ../shell/nushell.nix
  ];
  home = {
    packages = with pkgs;
      [
        gum
        go-task
        fzf
        yq-go
        zoxide
        mailsy
        awscli2
        cloudflared
        btop
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
        ffmpeg
        mupdf
        mpv

        wl-clipboard
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [
        viu
        wkhtmltopdf
        ghostscript
        texlive.combined.scheme-full
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
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };
}
