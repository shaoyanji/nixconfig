{pkgs, ...}: {
  home.packages = with pkgs; [
  ];
  home.file = {
    ".wezterm.lua".source = ../config/wezterm/.wezterm.lua;
  };
  xdg.configFile = {
    "wezterm/modules/mappings.lua".source = ../config/wezterm/modules/mappings.lua;
  };
}
