{ pkgs, ... }:

{
  imports = [ 
    ./heim.nix
    ./hyprland.nix
    ./hypr
  ];
  home.packages = with pkgs; [
  ];
  home.file = {
    # ".screenrc".source = dotfiles/screenrc;
    # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };
   home.sessionVariables = {
   };

}
