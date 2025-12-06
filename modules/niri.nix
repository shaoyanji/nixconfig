{pkgs, ...}: {
  # programs.alacritty.enable = true; # Super+T in the default setting (terminal)
  programs.fuzzel.enable = true; # Super+D in the default setting (app launcher)
  # programs.fuzzel.settings = {
  #   main = {
  #     terminal = "${pkgs.kitty}/bin/kitty";
  #     layer = "overlay";
  #   };
  #   colors.background = "ffffffff";
  # };
  # programs.firefox.enable = true;
  programs.niri.settings.environment."NIXOS_OZONE_WL" = "1";
  programs.niri.settings = {
    input.focus-follows-mouse.enable = true;
    input.warp-mouse-to-focus.enable = true;
    layout.focus-ring.enable = false;
    layout.border = {
      # enable = true;
      # active = "#7fc8ff";
      # inactive = "#505050";
      # active-gradient from="#e5989b" to="#ffb4a2" angle=45 relative-to="workspace-view" in="oklch longer hue"
      # inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
    };
    # window-rules.default = {
    # geometry-corner-radius = 12;
    # clip-to-geometry = true;
    # };
    # window-rules."Kando Menu" = {
    # matches."Kando Menu".title = {
    # open-floating = true;
    # border = "off";
    # shadown = "off";
    # };
    # };
    # prefer-no-csd = true;
    binds = {
      "Mod+A".action.spawn = "fuzzel";
      "Mod+T".action.spawn-sh = "kitty -- tmux";

      "Mod+Z".action.spawn = "zen";
      "Mod+C".action.spawn-sh = "obsidian";
      "Mod+B".action.spawn-sh = "kando -m 'Kando Menu'";

      "Mod+Return".action.spawn-sh = "kitty -- lf";
      "Ctrl+Space".action.spawn-sh = "kando -m 'Kando Menu'";

      # "Mod+H" = {
      # action = "focus-column-left";
      # hotkey-overlay.title = "Toggle Clipboard Manager";
      # };
      # "Mod+H".action.hotkey-overlay = "focus-column-left";
      # "Mod+J".action.focus-window-down.enable = true;
      # "Mod+K".action.focus-window-up.enable = true;
      # "Mod+L".action.focus-column-right.enable = true;

      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      "Mod+Ctrl+1".action.move-column-to-workspace = 1;
      "Mod+Ctrl+2".action.move-column-to-workspace = 2;
      "Mod+Ctrl+3".action.move-column-to-workspace = 3;
      "Mod+Ctrl+4".action.move-column-to-workspace = 4;
      "Mod+Ctrl+5".action.move-column-to-workspace = 5;
      "Mod+Ctrl+6".action.move-column-to-workspace = 6;
      "Mod+Ctrl+7".action.move-column-to-workspace = 7;
      "Mod+Ctrl+8".action.move-column-to-workspace = 8;
      "Mod+Ctrl+9".action.move-column-to-workspace = 9;
    };
  };
  programs.dankMaterialShell = {
    enable = true;
    systemd = {
      enable = true; # Systemd service for auto-start
      restartIfChanged = true; # Auto-restart dms.service when dankMaterialShell changes
    };
    # Core features
    enableSystemMonitoring = true; # System monitoring widgets (dgop)
    enableClipboard = true; # Clipboard history manager
    enableVPN = true; # VPN management widget
    enableBrightnessControl = true; # Backlight/brightness controls
    enableColorPicker = true; # Color picker tool
    enableDynamicTheming = true; # Wallpaper-based theming (matugen)
    enableAudioWavelength = true; # Audio visualizer (cava)
    enableCalendarEvents = true; # Calendar integration (khal)
    enableSystemSound = true; # System sound effects
    niri = {
      enableKeybinds = true; # Automatic keybinding configuration
      enableSpawn = true; # Auto-start DMS with niri
    };
    default.settings = {
      theme = "dark";
      dynamicTheming = true;
      # Add any other settings here
    };
  };
  # programs.swaylock.enable = true; # Super+Alt+L in the default setting (screen locker)
  services.mako.enable = true; # notification daemon
  # services.swayidle.enable = true; # idle management daemon
  # services.polkit-gnome.enable = true; # polkit
  home.packages = with pkgs; [
    xwayland-satellite # xwayland support
    swaybg # wallpaper
    kando
    # firefox-bin
  ];
  # home.file."Pictures/Wallpapers/yqKnYa.jpg".source = builtins.fetchurl {
  # url = "https://envs.net/~jisifu/pics/yqKnYa.jpg";
  # sha256 = "sha256:0i5dc7680cx2g32manwy8smfiwg2g6h6kfrhpxlm2icxza3jdscs";
  # };
  # xdg.configFile."niri/config.kdl".source = builtins.fetchurl {
  #   url = "https://raw.githubusercontent.com/YaLTeR/niri/refs/heads/main/resources/default-config.kdl";
  #   sha256 = "sha256:05bbav6xc8rx1fki49iv6y7grncp22afal6an31jjkqw2scq6bsd";
  # };
  # xdg.configFile."niri/config.kdl".source = builtins.fetchurl {
  #   url = "https://gist.githubusercontent.com/shaoyanji/f675c27adaaac753b35af9141568b78b/raw/a8959b808456109a1e88b5bf2f9c5f1c44341d10/config.kdl";
  #   sha256 = "sha256:16d54yw27h9an8ldnsvhcyn3zn1y60yikaap945nkidhgy06xcws";
  # };
}
