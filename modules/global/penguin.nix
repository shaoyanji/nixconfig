{ pkgs, ... }:

{
  home.username = "jisifu";
  home.homeDirectory= "/home/jisifu";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [ 
    ./home.nix
   # ./browser/firefox.nix
  ];
  
  nixpkgs.config.allowUnfree = true;
  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #           "obsidian"
  #         ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
  ];
 # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
   # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mattji/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
  #    EDITOR = "nvim";
   };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text = ''
   [Service]
   Environment="PATH=%h/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
   Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
  '';
}
