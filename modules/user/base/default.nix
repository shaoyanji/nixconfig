{
  self,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../scripts
    ../../lf
    ../../env.nix
    ../../shell/base.nix
    ../../sops.nix
    ../../helix.nix
  ];

  programs.nixvim.enable = true;

  home = {
    stateVersion = "25.05";
    packages = with pkgs;
      [
        http-nu
        aha
        tesseract
        pandoc
        markdownlint-cli
        mdq
        poppler-utils
        pastel
        comrak
        typst
        tinymist
        todoist
        totp-cli
        pdfcpu
        dufs
        just
        lux
        lowfi
        pop
        glow
        charm-freeze
        nixd
        qrencode
        duf
        slides
        graphviz
        graph-easy
        nix-output-monitor
        htmlq
        tomlq
        gum
        go-task
        yq-go
        cloak
        age
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
        ffmpeg
        fastfetch
        iftop
        file
        which
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
        gping
        buku
        ddgr
        mutt
        rclone
        httpie
        asciinema
        navi
        epr
        mc
        obsidian-export
      ]
      ++ lib.optionals stdenv.isLinux [
        self.packages.${pkgs.system}.qwen-code
        newsboat
        tuir
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
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        glances
      ]
      ++ lib.optionals stdenv.isDarwin [];

    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };

  xdg.configFile = {
    "nixpkgs/config.nix".text = ''
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
