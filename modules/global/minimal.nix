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
        ffmpeg
        mupdf
        mpv
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
        strace
        ltrace
        lsof
        sysstat
        pciutils
        usbutils
      ]
      ++ lib.optionals stdenv.isLinux [
        wl-clipboard
      ];
    file = {};

    sessionVariables = {
      GUM_CHOOSE_SELECTED_FOREGROUND = 50;
      GUM_CHOOSE_CURSOR_FOREGROUND = 50;
      GUM_CHOOSE_HEADER_FOREGROUND = 30;
    };
  };
}
