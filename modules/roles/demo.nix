{
  pkgs,
  lib,
  ...
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
  programs.niri.settings = {
    input.focus-follows-mouse.enable = true;
    layout.focus-ring.enable = false;
    layout.border = {};

    window-rules = [
      {
        geometry-corner-radius = let r = 8.0; in {
          top-left = r;
          top-right = r;
          bottom-left = r;
          bottom-right = r;
        };
        clip-to-geometry = true;
      }
    ];

    binds = {
      "Mod+Return".action.spawn = "foot";
      "Mod+A".action.spawn = "fuzzel";
      "Mod+Q".action.close-window = [];
      "Mod+Q".repeat = false;
      "Mod+F".action.maximize-column = [];
      "Mod+Shift+F".action.fullscreen-window = [];
      "Mod+R".action.switch-preset-column-width = [];
      "Mod+T".action.spawn-sh = "foot -- tmux";
      "Mod+W".action.toggle-window-floating = [];
      "Mod+S".action.screenshot = [];
      "Mod+Print".action.screenshot-screen = {show-pointer = false;};
      "Mod+Escape".action.spawn = "wlogout";

      "Mod+H".action.focus-column-left = [];
      "Mod+J".action.focus-workspace-down = [];
      "Mod+K".action.focus-workspace-up = [];
      "Mod+L".action.focus-column-right = [];

      "Mod+Shift+H".action.move-column-left = [];
      "Mod+Shift+J".action.move-workspace-down = [];
      "Mod+Shift+K".action.move-workspace-up = [];
      "Mod+Shift+L".action.move-column-right = [];

      "Mod+Ctrl+H".action.move-column-to-workspace-down = [];
      "Mod+Ctrl+J".action.move-column-to-workspace-up = [];
      "Mod+Ctrl+K".action.move-column-to-workspace-down = [];
      "Mod+Ctrl+L".action.move-column-to-workspace-up = [];

      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;
      "Mod+0".action.focus-workspace-previous = [];

      "Mod+Ctrl+1".action.move-column-to-workspace = 1;
      "Mod+Ctrl+2".action.move-column-to-workspace = 2;
      "Mod+Ctrl+3".action.move-column-to-workspace = 3;
      "Mod+Ctrl+4".action.move-column-to-workspace = 4;
      "Mod+Ctrl+5".action.move-column-to-workspace = 5;
      "Mod+Ctrl+6".action.move-column-to-workspace = 6;
      "Mod+Ctrl+7".action.move-column-to-workspace = 7;
      "Mod+Ctrl+8".action.move-column-to-workspace = 8;
      "Mod+Ctrl+9".action.move-column-to-workspace = 9;

      "Mod+WheelScrollDown".action.focus-workspace-down = [];
      "Mod+WheelScrollDown".cooldown-ms = 150;
      "Mod+WheelScrollUp".action.focus-workspace-up = [];
      "Mod+WheelScrollUp".cooldown-ms = 150;
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
    settings = {};
  };

}
