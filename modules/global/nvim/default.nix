{ config, ... }:
  let
    initLuafilepath = ./init.lua;
  in {
    imports = [ ];
    home.file.".config/nvim/init.lua" = {
      source = config.lib.file.mkOutOfStoreSymlink "${initLuafilepath}";
  };
  programs.neovim.enable = true;

  home.sessionVariables ={
    EDITOR = "nvim";
  };
}

