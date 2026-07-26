{ pkgs
, lib
, ...
}: {
  imports = [
    ../shell/base.nix
    ../user/desktop/niri.nix
  ];

  home.packages = with pkgs; [
    # ── Core terminal / TUI ──
    helix
    btop
    fastfetch
    duf
    procs
    most
    glow
    tree
    file
    which

    # ── File / Data Transfer ──
    rsync
    rclone
    aria2
    unzip
    zip
    zstd
    p7zip

    # ── Network / Diagnostics ──
    curl
    wget
    dnsutils
    nmap
    mtr
    iperf3
    socat

    # ── Shell / Productivity ──
    go-task
    just
    sd
    fd
    ripgrep
    jq
    yq-go
    fzf
    zoxide
    eza
    bat
    diff-so-fancy
    git
    hyperfine
    entr

    # ── System ──
    htop
    lsof
    pciutils
    usbutils
    lm_sensors
    strace

    # ── Launcher / Desktop ──
    foot
    swaybg
    wlogout
    xwayland-satellite
  ];
  # Demo role overrides ONLY the niri binds that meaningfully differ from
  # modules/user/desktop/niri.nix. Other shared keys (Mod+S, Mod+A,
  # Mod+W, Mod+F, Mod+Q, Mod+R, Mod+1..9, Mod+0, Mod+Print, Mod+H/J/K/L,
  # Mod+WheelScroll*, Mod+Ctrl+1..9, layout.*, input.*, window-rules) are
  # owned by the base niri module; redefining them here previously
  # caused duplicate-definition evaluation errors.
  #
  # lib.mkForce is applied where the action fundamentally differs so the
  # demo host wins over the base. Mod+Escape is unique to demo (no clash).
  programs.niri.settings = {
    binds = {
      "Mod+Return".action = lib.mkForce { spawn = "foot"; };
      "Mod+T".action = lib.mkForce { spawn-sh = "foot -- tmux"; };
      "Mod+Escape".action = { spawn = "wlogout"; };

      "Mod+Shift+H".action = lib.mkForce { move-column-left = [ ]; };
      "Mod+Shift+J".action = lib.mkForce { move-workspace-down = [ ]; };
      "Mod+Shift+K".action = lib.mkForce { move-workspace-up = [ ]; };
      "Mod+Shift+L".action = lib.mkForce { move-column-right = [ ]; };

      "Mod+Ctrl+H".action = lib.mkForce { move-column-to-workspace-down = [ ]; };
      "Mod+Ctrl+J".action = lib.mkForce { move-column-to-workspace-up = [ ]; };
      "Mod+Ctrl+K".action = lib.mkForce { move-column-to-workspace-down = [ ]; };
      "Mod+Ctrl+L".action = lib.mkForce { move-column-to-workspace-up = [ ]; };
    };
  };

  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = false;
    enableVPN = false;
    enableDynamicTheming = false;
    enableAudioWavelength = false;
    enableCalendarEvents = false;
    niri = {
      enableKeybinds = false;
      enableSpawn = true;
      includes = {
        enable = true;
        override = true;
        originalFileName = "hm";
        filesToInclude = [
          "alttab"
          "binds"
          "colors"
          "layout"
          "outputs"
          "wpblur"
        ];
      };
    };
    systemd.enable = false;
    settings = { };
  };
}
