{
  pkgs,
  lib,
  ...
}: let
  readPkgList = path: let
    lines = lib.pipe (builtins.readFile path) [
      (lib.splitString "\n")
      (map lib.strings.trim)
      (builtins.filter (line: line != "" && !(lib.hasPrefix "#" line)))
    ];
  in
    map (
      name:
        pkgs.${name} or (throw "Unknown package in ${toString path}: ${name}")
    )
    lines;
in {
  imports = [
    ../../scripts
    ../../lf
    ../../env.nix
    ../../shell/base.nix
    ../../sops.nix
    ../../helix.nix
  ];

  home = {
    stateVersion = "25.05";
    packages = with pkgs;
      readPkgList ../../../pkg.txt
      ++ [
        # ── PDF / Document Processing ──
        pandoc # Universal document converter
        pdfcpu # PDF processing toolkit
        poppler-utils # PDF utilities (pdftotext, pdfinfo, etc.)
        typst # Modern typesetting system
        tinymist # Typst language server
        comrak # CommonMark-compliant Markdown renderer
        obsidian-export # Export Obsidian markdown notes

        # ── Image / Media / Graphics ──
        tesseract # OCR engine
        exiftool # EXIF metadata reader/writer
        ffmpeg # Audio/video processing
        graphviz # Graph visualization
        graph-easy # ASCII/HTML/SVG graph renderer
        qrencode # QR code generator
        pastel # Color palette tool

        # ── Terminal UI / TUI Apps ──
        btop # Resource monitor
        duf # Disk usage/free space viewer
        dufs # Static file server with Web UI
        fastfetch # System info fetcher
        glow # Markdown renderer for terminal
        gum # Shell scripting eye-candy
        lowfi # Lo-fi music player
        most # Advanced pager
        navi # Interactive cheatsheet tool
        pop # Terminal email client
        procs # ps replacement
        slides # Terminal presentation tool
        tre # Tree viewer with syntax highlighting
        charm-freeze # Code block image generator

        # ── File / Data Transfer ──
        aria2 # Download utility
        httpie # User-friendly HTTP client
        http-nu # HTTP client for Nushell
        mutt # Terminal email client
        rclone # Cloud storage sync
        rsync # Remote file sync
        lux # Video downloader

        # ── Network / Diagnostics ──
        awscli2 # AWS CLI
        bandwhich # Terminal bandwidth monitor
        cloudflared # Cloudflare tunnel client
        dnsutils # DNS utilities (dig, nslookup)
        gping # Ping with graph
        iftop # Network bandwidth monitor
        ipcalc # IP address calculator
        iperf3 # Network bandwidth measurement
        ldns # DNS library utilities
        mtr # Network diagnostic (traceroute + ping)
        nmap # Network scanner
        socat # Bidirectional data relay

        # ── Security / Encryption / Auth ──
        age # Simple, modern encryption
        bitwarden-cli # Bitwarden password manager CLI
        cloak # Encrypted secrets manager
        totp-cli # TOTP generator

        # ── Archive / Compression ──
        p7zip # 7-Zip archiver
        unzip # ZIP extraction
        zip # ZIP compression
        zstd # Zstandard compression

        # ── Shell / Productivity / Dev Tools ──
        asciinema # Terminal session recorder
        devenv # Developer environments
        epr # E-book reader
        go-task # Task runner (Taskfile.yml)
        gokrazy # Go-based embedded Linux builder
        htmlq # HTML query (like jq for HTML)
        just # Command runner (Make-like)
        markdownlint-cli # Markdown linter
        mdq # Markdown query tool
        nix-output-monitor # Pretty Nix output
        nixd # Nix language server
        sd # sed alternative (find/replace)
        tomlq # TOML processor
        yq-go # YAML/JSON/XML processor

        # ── Search / Bookmarks ──
        buku # Bookmark manager
        ddgr # DuckDuckGo from terminal
        fdupes # Duplicate file finder
        hyperfine # Benchmarking tool

        # ── Core Unix Utilities ──
        aha # ANSI to HTML converter
        diff-so-fancy # Better git diff output
        entr # Run commands on file changes
        file # File type detection
        gawk # GNU awk
        gnused # GNU sed
        gnutar # GNU tar
        mc # Midnight Commander file manager
        tree # Directory tree viewer
        which # Locate executables

        # ── Databases ──
        sqlite # SQLite database

        # ── Misc ──
        mailsy # Email utility
      ]
      ++ lib.optionals stdenv.isLinux [
        # ── Linux-only TUI Apps ──
        newsboat # RSS/Atom feed reader
        tuir # TUI for Reddit
        cmus # Terminal music player

        # ── Linux-only Dev / Productivity ──
        dust # Disk usage analyzer
        gitmoji-cli # Gitmoji CLI
        hub # GitHub CLI wrapper
        pass # Standard Unix password manager
        tldr # Simplified man pages

        # ── Linux-only Compression ──
        lz4 # Fast compression algorithm

        # ── Linux-only Document Processing ──
        md2pdf # Markdown to PDF converter
        ghostscript_headless # PostScript/PDF interpreter

        # ── Linux-only System Diagnostics ──
        lsof # List open files
        ltrace # Library call tracer
        pciutils # PCI bus utilities
        strace # System call tracer
        sysstat # System performance tools
        usbutils # USB device utilities
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        glances # Cross-platform system monitor
        nurl
        python3
      ]
      ++ lib.optionals stdenv.isDarwin [];

    sessionVariables = {
      EDITOR = "hx";
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
