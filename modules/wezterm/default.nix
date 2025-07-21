{pkgs, ...}: {
  home.packages = with pkgs; [
  ];
  home.file = {
    ".wezterm.lua".source = ../dotfiles/.config/wezterm/.wezterm.lua;
  };
  xdg.configFile = {
    "wezterm/modules/mappings.lua".source = ../dotfiles/.config/wezterm/modules/mappings.lua;
  };
}
