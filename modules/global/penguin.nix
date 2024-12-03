{pkgs, ...}: {
  home.username = "jisifu";
  home.homeDirectory = "/home/jisifu";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [
    ../lf
    ../env.nix
    ../shell
    ../sops.nix
    ../nixvim
    ../kitty
    ../shell/nushell.nix
    ../helix.nix
  ];

  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  # "obsidian"
  # ];
  home.packages = with pkgs; [
    gum
    go-task
    (pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];})
  ];
  home.file = {
    # ".screenrc".source = dotfiles/screenrc;
    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    #    EDITOR = "nvim";
  };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text = ''
    [Service]
    Environment="PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
    Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
  '';
  programs.home-manager.enable = true;
}
