{ config, pkgs, lib, inputs, ... }:
let
	initLuafilepath = ./init.lua;
	luaFolderpath = ./lua;
in {
  imports = [ 
  ];
  home.file.".config/nvim/init.lua" = {
  	source = config.lib.file.mkOutOfStoreSymlink "${initLuafilepath}";
};
home.file.".config/nvim/lua" = {
	source = config.lib.file.mkOutOfStoreSymLink "luaFolderpath";
};
	
programs.neovim.enable = true;
home.sessionVariables ={
	EDITOR = "nvim";
};
}

