{pkgs, ...}: {
  programs.fuzzel.enable = true;

  xdg.configFile."xdg-desktop-portal/niri-portals.conf".text = ''
    [preferred]
    org.freedesktop.impl.portal.FileChooser=kde;gtk;
  '';

  # KDE color scheme for portal file picker and other Qt/KDE apps
  xdg.configFile."kdeglobals".text = ''
    [General]
    ColorScheme=CatppuccinFrappeBlue

    [KDE]
    contrast=4

    [WM]
    activeBackground=48, 52, 70
    activeForeground=198, 208, 245
    inactiveBackground=35, 38, 52
    inactiveForeground=165, 173, 206
  '';

  # Kvantum Qt style config — catppuccin-frappe-blue theme
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=catppuccin-frappe-blue
  '';

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
  };

  programs.niri.settings = {
    hotkey-overlay.skip-at-startup = true;
    environment."NIXOS_OZONE_WL" = "1";
    input.focus-follows-mouse.enable = true;
    input.warp-mouse-to-focus.enable = true;
    layout.focus-ring.enable = false;
    layout.border = {};
    window-rules = [
      {
        geometry-corner-radius = let
          r = 12.0;
        in {
          top-left = r;
          top-right = r;
          bottom-left = r;
          bottom-right = r;
        };
        clip-to-geometry = true;
      }
      {
        matches = [
          {app-id = "xdg-desktop-portal-gtk";}
          {app-id = "org.freedesktop.impl.portal.desktop.gtk";}
          {app-id = "xdg-desktop-portal-kde";}
          {app-id = "org.freedesktop.impl.portal.desktop.kde";}
        ];
        border.enable = false;
        open-floating = true;
        default-column-width.proportion = 0.5;
        default-window-height.proportion = 0.8;
      }
    ];
    binds = {
      "Mod+Shift+Slash".action.show-hotkey-overlay = [];
      "Mod+Print".action.screenshot-screen = {show-pointer = false;};
      "Mod+A".action.spawn = "fuzzel";
      "Mod+T".action.spawn-sh = "kitty -- tmux";

      "Mod+Z".action.spawn = "zen-beta";
      "Mod+C".action.spawn-sh = "kitty -- task";
      "Mod+B".action.spawn-sh = "kando -m 'Kando Menu'";

      "Mod+W".action.toggle-window-floating = [];
      "Mod+E".action.switch-focus-between-floating-and-tiling = [];
      "Mod+BracketLeft".action.consume-or-expel-window-left = [];
      "Mod+BracketRight".action.consume-or-expel-window-right = [];

      "Mod+Return".action.toggle-overview = [];
      "Ctrl+Space".action.spawn-sh = "kando -m 'Kando Menu'";

      "Mod+H".action.focus-column-left = [];
      "Mod+J".action.focus-workspace-down = [];
      "Mod+K".action.focus-workspace-up = [];
      "Mod+L".action.focus-column-right = [];

      "Mod+Shift+H".action.focus-monitor-left = [];
      "Mod+Shift+J".action.focus-workspace-down = [];
      "Mod+Shift+K".action.focus-workspace-up = [];
      "Mod+Shift+L".action.focus-monitor-right = [];

      "Mod+Ctrl+H".action.move-column-left = [];
      "Mod+Ctrl+J".action.move-column-to-workspace-down = [];
      "Mod+Ctrl+K".action.move-column-to-workspace-up = [];
      "Mod+Ctrl+L".action.move-column-right = [];

      "Mod+Ctrl+Shift+H".action.move-column-to-monitor-left = [];
      "Mod+Ctrl+Shift+J".action.move-column-to-workspace-down = [];
      "Mod+Ctrl+Shift+K".action.move-column-to-workspace-up = [];
      "Mod+Ctrl+Shift+L".action.move-column-to-monitor-right = [];

      "Mod+Q".action.close-window = [];
      "Mod+Q".repeat = false;
      "Mod+F".action.maximize-column = [];
      "Mod+Shift+F".action.fullscreen-window = [];
      "Mod+R".action.switch-preset-column-width = [];
      "Mod+U".action.focus-monitor-previous = [];
      "Mod+I".action.focus-workspace-previous = [];
      "Mod+S".action.screenshot = [];
      "Mod+WheelScrollDown".action.focus-workspace-down = [];
      "Mod+WheelScrollUp".action.focus-workspace-up = [];
      "Mod+Ctrl+WheelScrollDown".action.move-column-to-workspace-down = [];
      "Mod+Ctrl+WheelScrollUp".action.move-column-to-workspace-up = [];

      "Mod+WheelScrollDown".cooldown-ms = 150;
      "Mod+WheelScrollUp".cooldown-ms = 150;
      "Mod+Ctrl+WheelScrollDown".cooldown-ms = 150;
      "Mod+Ctrl+WheelScrollUp".cooldown-ms = 150;

      "Mod+0".action.focus-workspace-previous = [];
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

  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    niri = {
      enableKeybinds = true;
      enableSpawn = true;
      includes = {
        enable = false;
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
    settings = {
      theme = "dark";
      dynamicTheming = true;
    };
  };

  home.packages = with pkgs; [
    xwayland-satellite
    swaybg
    kando
    catppuccin-kde
    catppuccin-kvantum
  ];
}
