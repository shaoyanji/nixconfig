{
  self,
  inputs,
  config,
  pkgs,
  user,
  ...
}: {
  imports = [
    self.modules."shell"
    self.modules."env"
    self.modules."lf"
    self.modules."sops"
    self.modules."scripts"
    # Imported here, not into every standalone HM config: this is the only host
    # that enables the editor, and option surface is what a gate pays for.
    inputs.kickstart-nixvim.homeManagerModules.default
  ];
  # Was roles/portable-home.nix, a file with one import plus this line and a
  # single consumer. One host is not a shared property.
  programs.nixvim = {
    enable = true;
    # Use the host's pkgs inside nixvim instead of nixvim's own nixpkgs: one
    # nixpkgs evaluation per host, and the plugins share store paths the rest of
    # this config already pulls in.
    nixpkgs.useGlobalPackages = true;
  };

  programs = {
    pay-respects.enable = true;
    atuin.enable = true;

    btop = {
      enable = true;
      settings = {
        color_theme = "tokyo-night.theme";
        theme_background = false;
        vim_keys = true;
      };
    };

    mpv = {
      enable = true;
      package = config.lib.nixGL.wrap pkgs.mpv;
      config = {
        profile = "fast";
        hwdec = "auto";
        force-window = true;
      };
      bindings = {
        WHEEL_UP = "seek 10";
        WHEEL_DOWN = "seek -10";
        "Alt+0" = "set window-scale 0.5";
      };
    };
  };
  services = {
    keybase.enable = true;
    home-manager.autoExpire.enable = true;
  };
  home = {
    username = user.name;
    homeDirectory = user.home;
    packages = with pkgs; [
      nix-output-monitor
      lowfi
      duf
      gum
      go-task
      glow
      cloak
      typst
      tinymist
      pdfcpu
      comrak
      helix
      obs-cli
    ];
    stateVersion = "24.11";
    file = {
      ".local/share/fonts".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/data/dotfiles/.local/share/fonts";
    };
    sessionVariables = {
      EDITOR = "hx";
    };
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.npm-global/bin"
    ];
  };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text = ''
    [Service]
    Environment="PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
    Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
  '';
  programs.home-manager.enable = true;
}
