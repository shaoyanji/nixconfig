{
  pkgs,
  lib,
  ...
}: {
  home.stateVersion = "24.11";
  imports = [
    ../lf
    ../env.nix
    ../shell
    ../sops.nix
    ../kitty
    # ../dev.nix
    ../helix.nix
    # ../scripts
  ];
  home = {
    packages = with pkgs;
      [
        gum
        go-task
        nixd
        devenv
        sqlite
        mailsy
        hyperfine
        ## archives
        zip
        # xz
        unzip
        p7zip

        # networking tools
        mtr # A network diagnostic tool
        iperf3
        dnsutils # `dig` + `nslookup`
        ldns # replacement of `dig`, it provide the command `drill`
        aria2 # A lightweight multi-protocol & multi-source command-line download utility
        socat # replacement of openbsd-netcat
        nmap # A utility for network discovery and security auditing
        ipcalc # it is a calculator for the IPv4/v6 addresses

        # misc
        file
        which
        tree
        gnused
        gnutar
        gawk
        zstd
        # gnupg
        btop # replacement of htop/nmon
        iotop # io monitoring
        iftop # network monitoring
      ]
      ++ lib.optionals stdenv.isDarwin [
        pop
        glow
        charm-freeze # obsidian
        cocoapods
        m-cli # useful macOS CLI commands
        wezterm
      ]
      ++ lib.optionals stdenv.isLinux [
        wl-clipboard
        ##   system call monitoring
        strace # system call monitoring
        ltrace # library call monitoring
        lsof # list open files
        ##   system tools
        sysstat
        lm_sensors # for `sensors` command
        ethtool
        pciutils # lspci
        usbutils # lsusb
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;
}
