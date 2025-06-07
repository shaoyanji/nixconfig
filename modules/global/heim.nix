{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./home.nix
    #../dev.nix
    ../nixoshmsymlinks.nix
    ../shell/nushell.nix
  ];
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs;
      [
      ]
      ++ lib.optionals stdenv.isLinux [
        # strace
        # ltrace
        # lsof
        # sysstat
        # pciutils
        # usbutils
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [
        yt-dlp
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
  };

  nixpkgs.config.allowUnfree = true;
}
