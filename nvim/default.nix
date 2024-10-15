{ config, pkgs, lib, inputs, ... }:
let
in {
  imports = [ 
  ];
  home.file.".config/nvim/init.lua" = {
  	source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nvim/init.lua.bkup";

};
	
programs.neovim.enable = true;
home.sessionVariables ={
	EDITOR = "nvim";
};
}

