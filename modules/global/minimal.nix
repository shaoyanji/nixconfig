{
  inputs,
  pkgs,
  lib,
  ...
}: let
  pkgstxt = map (pkg: pkgs.${pkg}) (
    builtins.filter (line: !(pkgs.lib.hasPrefix "#" (pkgs.lib.trim line))) (
      builtins.filter (pkg: pkg != "") (pkgs.lib.splitString "\n" (builtins.readFile ./../../pkg.txt))
    )
  );
  # pkgstxt =
  #   ./../../pkg.txt
  #   |> builtins.readFile
  #   |> pkgs.lib.splitString "\n"
  #   |> builtins.filter (pkg: pkg != "")
  #   |> builtins.filter (line:
  #     !(pkgs.lib.trim line
  #       |> pkgs.lib.hasPrefix "#"))
  #   |> map (pkg: pkgs.${pkg});
in {
  imports = [
    ../scripts
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
        # eget
        poppler-utils
        pastel
        caligula
        astroterm
        comrak
        surge-cli
        minijinja
        amfora
        typst
        tinymist
        cook-cli
        supabase-cli
        turso-cli
        cloudflare-cli
        bootdev-cli
        todoist
        wash-cli
        starfetch
        neocities
        comodoro
        jwt-cli
        himalaya
        totp-cli
        termshark
        gucci
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
        charm-freeze
        nixd
        viu
        qrencode
        duf
        slides
        graphviz
        graph-easy
        nix-output-monitor
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
        buku
        ddgr
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
        ticker
        obsidian-export
        ots
        xq
      ]
      ++ lib.optionals stdenv.isDarwin [
        wget
        cocoapods
        m-cli # useful macOS CLI commands
        #wezterm
        # darwin.xcode_16_1
      ]
      ++ lib.optionals stdenv.isLinux [
        hyprpicker
        graph-easy
        lazygit
        gitmoji-cli
        tldr
        dust
        lz4
        # toot
        pass
        cmus
        bitwarden-cli
        hub
        md2pdf
        strace
        ltrace
        lsof
        sysstat
        pciutils
        usbutils
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        ghostscript_headless
        goose-cli
        anki-bin
        uv
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
