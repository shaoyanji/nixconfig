{ config, pkgs, ... }:

{
   #currentltly dotfiles need hardlinking ln modules/mappings.lua ~/.config/wezterm/modules/mappings.lua
   home.packages = with pkgs; [
      wezterm
   ];
   home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
      #   ".wezterm.lua".source = "./wezterm/.wezterm.lua";
      #"$HOME/.config/wezterm/modules/mappings.lua".source = "./wezterm/modules/mappings.lua";
   # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

}
