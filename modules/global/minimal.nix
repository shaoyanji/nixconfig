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
    # ../shell
    ../shell/tmux.nix
    ../shell/bash.nix
    ../sops.nix
    ../helix.nix
    ../goodies.nix # aichat
    # ../shell/nushell.nix
  ];

  programs.nixvim.enable = true;
  home = {
    stateVersion = "25.05";
    packages = with pkgs;
      pkgstxt
      ++ [
        aha
        tesseract
        pandoc
        markdownlint-cli
        todo-txt-cli
        ytcast
        mdq
        zbar
        multimarkdown
        poppler-utils
        pastel
        caligula
        astroterm
        comrak
        minijinja
        amfora
        typst
        tinymist
        todoist
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
        httpie
        lazygit
        asciinema
        navi
        epr
        lynx
        translate-shell
        mc
        ticker
        obsidian-export
        ots
        xq
      ]
      ++ lib.optionals stdenv.isLinux [
        tuir
        graph-easy
        lazygit
        gitmoji-cli
        tldr
        dust
        lz4
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
        ghostscript_headless
        # toot
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 []
      ++ lib.optionals stdenv.isDarwin [];
    file = {};

    sessionVariables = {
      EDITOR = "nvim";
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };

  xdg.configFile = {
    "nixpkgs/config.nix".text =
      /*
      nix
      */
      ''
        {
          packageOverrides = pkgs: {
            nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/main.tar.gz") {
              inherit pkgs;
            };
          };
        }
      '';
    "elvish/rc.elv".source = builtins.fetchurl {
      url = "https://gist.githubusercontent.com/shaoyanji/656406074a590a09e33755b88ac29d53/raw/rc.elv";
      sha256 = "0b0078sp6fyqygxz9hap7inhpnwz17s0vcpb4fgklzxa2h8kp194";
    };
  };
}
