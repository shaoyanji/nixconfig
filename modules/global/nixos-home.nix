{ pkgs, ... }:

{
  imports = [ 
    ./home.nix
    ./hyprland.nix
    ./browser/firefox.nix
  ];
  home.packages = with pkgs; [
    obsidian
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
