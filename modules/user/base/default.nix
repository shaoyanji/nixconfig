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
    map
    (
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
        # ── Sysadmin Resource & Performance Monitoring ──
        btop # Resource monitor
        duf # Disk usage/free space viewer
        fastfetch # System info fetcher
        procs # Modern ps replacement

        # ── File & Remote Data Transfer ──
        aria2 # Multi-protocol download utility
        rclone # Cloud/remote storage sync
        rsync # Fast incremental remote file copy

        # ── Network Diagnostics & Infrastructure ──
        bandwhich # Terminal bandwidth monitor
        dnsutils # DNS utilities (dig, nslookup)
        gping # Graphical interactive ping
        iftop # Network bandwidth monitor
        ipcalc # IPv4/IPv6 subnet calculator
        iperf3 # Network throughput tester
        ldns # Fast DNS resolver & drill tool
        mtr # Combined traceroute & ping diagnostic
        nmap # Network port scanner & security audit
        socat # Multipurpose bidirectional relay

        # ── Secrets, Encryption & Security ──
        age # Modern simple file encryption
        cloak # Command-line TOTP / 2FA secrets generator

        # ── Archive & Compression Formats ──
        lz4 # Extremely fast compression
        p7zip # 7-Zip archiver
        unzip # Standard ZIP extractor
        zip # Standard ZIP archiver
        zstd # Modern real-time compression (Zstandard)

        # ── Automation, Task Runners & Scripting ──
        go-task # Taskfile runner (task)
        gum # Modern shell eye-candy / interactive TUI (used by fleet task scripts)
        just # Modern command runner
        nix-output-monitor # Enhanced nix-build progress output (nom)
        sd # Intuitive regex search & replace
        tomlq # TOML stream parser
        yq-go # YAML/JSON processor

        # ── Core Unix Administration Utilities ──
        entr # Event-driven command execution on file change
        file # File type inspection
        gawk # GNU pattern scanning language
        gnused # GNU stream editor
        gnutar # GNU tar tape archiver
        tree # Hierarchical directory visualizer
        which # Path discovery for binaries

        # ── Databases & Persistent Stores ──
        sqlite # Embedded relational database engine
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        # ── Linux System Diagnostics & Hardware ──
        lsof # List open files & network sockets
        pass # Standard Unix password manager
        pciutils # PCI bus inspection (lspci)
        strace # Kernel system call tracer
        sysstat # System performance & accounting (sar, iostat)
        tldr # Practical command manual pages
        usbutils # USB bus inspection (lsusb)
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [];

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
