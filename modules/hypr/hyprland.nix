{ config, pkgs, lib, inputs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    plugins = [
      #      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];
    settings = {
      master = {
        new_status = "master";
      };
      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
      };
      input = {
        kb_layout = "us";
        kb_variant = ",us";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };
      };
      gestures = {
        workspace_swipe = false;
      };
      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };
      windowrulev2 = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];
      monitor = [
        #"DVI-I-1,1280x1024,-1280x0,auto"
        #"HDMI-1,preferred,auto,auto"
        #"eDP-1,preferred,auto,auto"
        #"eDP-1,disabled,auto,auto"
      ];
      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        resize_on_border = false;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        allow_tearing = false;
        layout = "dwindle";
      };
      decoration = {
        rounding = 10;
        active_opacity = 1;
        inactive_opacity = 0.6;
        #drop_shadow = true;
        #shadow_range = 5;
        #shadow_render_power = 3;
        #"col.shadow" = "rgba(1a1a1aee)";
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };
      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1"
          "quick,0.15,0,0.1,1"
        ];
        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, easeOutQuint, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 1, 1.94, almostLinear, fade"
          "workspacesIn, 1, 1.21, almostLinear, fade"
          "workspacesOut, 1, 1.94, almostLinear, fade"
        ];
      };
      "$mainMod" = "SUPER";
      #      "$fileManager" = "${pkgs.dolphin}/bin/dolphin";
      "$menu" = "${pkgs.wofi}/bin/wofi --show drun";
      bind = [
        "$mainMod, T, exec, ${pkgs.kitty}/bin/kitty"
        "$mainMod, W, killactive"
        "$mainMod, M, exit"
        "$mainMod, D, togglefloating"
        "$mainMod, A, exec, $menu"
        "$mainMod, P, pseudo"
        "$mainMod, E, togglesplit"
        "$mainMod, H,  movefocus, l"
        "$mainMod, J,  movefocus, d"
        "$mainMod, K,  movefocus, u"
        "$mainMod, L,  movefocus, r"

        "$mainMod, period, workspace, next"
        "$mainMod, comma, workspace, prev"

        "$mainMod, semicolon, workspace, move, next"
        "$mainMod, apostrophe, workspace, move, prev"

        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];
      bindm = [
        #mouse movements
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
        "$mainMod ALT, mouse:272, resizewindow"
      ];
      bindl = [
        " , XF86AudioNext, exec, playerctl next"
        " , XF86AudioPrev, exec, playerctl previous"
        " , XF86AudioPlay, exec, playerctl play-pause"
      ];
      bindel = [
        " , X86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        " , X86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        " , XF86MonBrightnessUp, exec, brightnessctl set +10%+"
        " , XF86MonBrightnessDown, exec, brightnessctl set +10%-"
        " , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        " , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];
      dwindle = {
        #psuedotile = true;
        preserve_split = true;
      };

    };
    extraConfig = ''
      source = ~/.config/hypr/animations.conf
      #source = ~/.config/hypr/keybinds.conf
      source = ~/.config/hypr/windowrules.conf
      source = ~/.config/hypr/themes/common.conf
      source = ~/.config/hypr/themes/colors.conf
      source = ~/.config/hypr/themes/theme.conf
      source = ~/.config/hypr/monitors.conf
      source = ~/.config/hypr/userprefs.conf
    '';
  };
}
