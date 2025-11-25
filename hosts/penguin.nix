{
config,
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
    ../modules/aria2.nix
    # ../modules/kitty
    # ../modules/goodies.nix
    # ../modules/helix.nix
  ];
  programs.pay-respects.enable = true;


programs.nix-your-shell.enable =true;
  programs.atuin.enable = true;
  accounts.email.accounts."jisifu"= {
name = "jisifu";
primary=true;
address = "jisifu@gmail.com";
realName = "Shao-yan (Matt) Ji";
userName = "jisifu";
himalaya.enable =true;

};
  programs.himalaya ={
    enable =true;
    # accounts.email.accounts.mkAccountConfig = {
    #   notmuchEnabled=true;
    #   email = "jisifu@gmail.com";
    #   display-name = "Matt";
    # };
  };
  # services.imapnotify={enable=true;
  #   accounts.email.accounts."jisifu".himalaya.enable=true;
  # };
  programs.btop={
    enable = true;
    settings = {
      color_theme = "tokyo-night.theme";
      theme_background = false;
      vim_keys=true;
    };
    };
  programs.yt-dlp.enable = true;
  programs.yt-dlp.settings = {
          embed-thumbnail = true;
          embed-subs = true;
          sub-langs = "en";
          downloader = "aria2c";
          downloader-args = "aria2c:'-c -x8 -s8 -k1M'";
        };
  programs.wofi.enable = true;
  programs.kakoune.enable = true;
  programs.neovim.enable = true;
  # programs.vim.enable = true;
  programs.go.enable = true;
  programs.go.telemetry.mode = "off";
  programs.uv = {
    enable = true;
    settings = {
      python-downloads = "never";
      python-preference = "only-system";
      pip.index-url = "https://test.pypi.org/simple";
    };
  };
  programs.mpv.enable = true;
  programs.mpv.config = {
    profile="fast";
    hwdec="auto";
    force-window = true;
  };
  programs.mpv.bindings = {
    WHEEL_UP = "seek 10";
    WHEEL_DOWN = "seek -10";
    "Alt+0" = "set window-scale 0.5";
  };
  # services.clipmenu.enable = true;
  # services.clipmenu.launcher = "wofi";

  # programs.neovide.enable = true;
  # programs.qutebrowser.enable = true;
  # programs.quickshell.enable = true;
  # programs.kitty.enable = true;
  # programs.freetube.enable =true;
  # programs.zed-editor.enable = true;
  # services.way-displays.enable = true;
  # 
  programs.translate-shell.enable = true;
  programs.translate-shell.settings = {
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
      helix
      wl-clipboard
      ytfzf
      nixgl.nixGLIntel
    ];
    stateVersion = "24.11";
    file = {
    };
    sessionVariables = {
      EDITOR = "hx";
      invidious_instance="https://inv.perditum.com";
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

  services.home-manager.autoExpire.enable = true;
  programs.home-manager.enable = true;
}
