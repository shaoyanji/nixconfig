{
  inputs,
  pkgs,
  lib,
  ...
}: let
  # pkgstxt = map (pkg: pkgs.${pkg}) (builtins.filter (line: !(pkgs.lib.hasPrefix "#" (pkgs.lib.trim line))) (builtins.filter (pkg: pkg != "") (pkgs.lib.splitString "\n" (builtins.readFile ./../../pkg.txt))));
  pkgstxt =
    ./../../pkg.txt
    |> builtins.readFile
    |> pkgs.lib.splitString "\n"
    |> builtins.filter (pkg: pkg != "")
    |> builtins.filter (line:
      !(pkgs.lib.trim line
        |> pkgs.lib.hasPrefix "#"))
    |> map (pkg: pkgs.${pkg});
in {
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

  home = {
    stateVersion = "25.05";
    packages = with pkgs;
      pkgstxt
      ++ [
        #        (pkgs.uutils-coreutils.override {prefix = "";})
        cook-cli
        goose-cli
        supabase-cli
        turso-cli
        cloudflare-cli
        bootdev-cli
        todoist
        go
        wash-cli
        starfetch
        # rustfinity
        # twitch-hls-client
        neocities-cli
        comodoro
        jwt-cli
        himalaya
        # neverest #doesn't build on wsl or penguin
        totp-cli
        termshark
        gucci
        #seclists
        a2ps
        enscript
        pdfcpu
        tgpt
        aichat
        mods
        dufs
        just
        lux
        gtree
        lowfi
        pop
        glow
        charm-freeze # obsidian
        nixd
        viu
        qrencode
        duf
        slides
        graphviz
        graph-easy
        nix-output-monitor
        # thefuck
        jq
        htmlq
        tomlq
        ripgrep
        fd
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
        # khal
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
        broot
        # qalculate-qt
        ticker
        obsidian-export
        ots
        xq
      ]
      ++ lib.optionals stdenv.isDarwin [
        python3
        wget
        cocoapods
        m-cli # useful macOS CLI commands
        #wezterm
        # darwin.xcode_16_1
        yt-dlp
      ]
      ++ lib.optionals stdenv.isLinux [
        wl-clipboard
        hub
        md2pdf
        strace
        ltrace
        lsof
        sysstat
        pciutils
        usbutils
        graph-easy
        gnuplot
        cliphist
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        ghostscript_headless
        # inputs.stormy.packages.x86_64-linux.stormy
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };

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
}
