{ pkgs, ... }:

{
   home.packages = with pkgs; [
   ];
   home.file = {
      ".wezterm.lua".source = ./.wezterm.lua;
   };
   xdg.configFile = {
      "wezterm/modules/mappings.lua".source = ./modules/mappings.lua;
   };
}
