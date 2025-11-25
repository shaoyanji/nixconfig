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
    # ../modules/kitty
    # ../modules/goodies.nix
    # ../modules/helix.nix
  ];
  programs.aria2 = {
      enable = true;
      settings = {
        disk-cache = ''32M'';
        file-allocation = ''falloc'';
        continue = true;
        max-concurrent-downloads = 10;
        max-connection-per-server = 16;
        min-split-size = ''10M'';
        split = 5;
        disable-ipv6 = true;
        save-session-interval = 60;
        #rpc-secret=;
        rpc-listen-port = 6800;
        rpc-allow-origin-all = true;
        rpc-listen-all = true;
        follow-torrent = true;
        listen-port = 51413;
        bt-max-peers = 100;
        enable-dht = true;
        enable-dht6 = true;
        dht-listen-port = 6966;
        enable-peer-exchange = true;
        peer-id-prefix = "-TR2770-";
        peer-agent = ''Transmission/2.77'';
        user-agent = ''Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0'';
        seed-ratio = 0;
        bt-hash-check-seed = true;
        bt-seed-unverified = true;
        bt-save-metadata = false;
        enable-rpc = true;
        max-upload-limit = "50K";
        ftp-pasv = true;
      };
    };
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
  services.clipmenu.enable = true;
  services.clipmenu.launcher = "wofi";

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
