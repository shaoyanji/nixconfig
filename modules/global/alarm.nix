{ pkgs, ... }:

{
  home.username = "alarm";
  home.homeDirectory= "/home/alarm";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  imports = [
  ../lf
  ../env.nix
  ../shell
  #./home.nix
  ];
  
  nixpkgs.config.allowUnfree = true;
 home.packages = with pkgs; [
    neovim
  ];
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
  home.sessionVariables = {
      EDITOR = "nvim";
   };
  programs.home-manager.enable = true;
}
