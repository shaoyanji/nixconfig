{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    # ../modules/global/minimal.nix
    ../modules/shell
    ../modules/env.nix
    ../modules/nixoshmsymlinks.nix
    ../modules/lf
    ../modules/sops.nix
    ../modules/scripts
    ../modules/kitty
    ../modules/goodies.nix
    # ../modules/helix.nix
  ];
  services.home-manager.autoExpire.enable = true;
  programs.wofi.enable = true;
  programs.kakoune.enable = true;
  programs.neovim.enable = true;
  programs.go.enable = true;
  programs.go.telemetry.mode = "off";
    
  programs.uv={
    enable = true;
    settings = {
          python-downloads = "never";
          python-preference = "only-system";
          pip.index-url = "https://test.pypi.org/simple";
        };
  };
  programs.mpv.enable = true;
  programs.mpv.bindings = {
            WHEEL_UP = "seek 10";
            WHEEL_DOWN = "seek -10";
            "Alt+0" = "set window-scale 0.5";
          };
  services.clipmenu.enable = true;
  services.clipmenu.launcher= "wofi";

  # programs.neovide.enable = true;
  # programs.qutebrowser.enable = true;
  # programs.quickshell.enable = true;
  # programs.kitty.enable = true;
  # programs.freetube.enable =true;
  # programs.zed-editor.enable = true;
  # services.way-displays.enable = true;
  programs.translate-shell.enable = true;
  programs.translate-shell.settings = 
	{
        verbose = true;
        hl = "en";
        tl = [
          "zh"
          "de"
        ];
      };
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs; [
      ani-cli
      nix-output-monitor
      lowfi
      duf
      viu
      gum
      go-task
      cloak
      btop
      helix
      wl-clipboard
    ];
    stateVersion = "24.11";
    file = {
    };
    sessionVariables = {
      EDITOR = "hx";
    };
    sessionPath = [];
  };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text =
    /*
    ini
    */
    ''
      [Service]
      Environment="PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
      Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
    '';

  programs.home-manager.enable = true;
}
