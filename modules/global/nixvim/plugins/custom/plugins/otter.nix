{ pkgs, ... }:
{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
#      vim-nix
      otter-nvim
    ];
    extraConfigLuaPre =''
      require("otter").activate({ "python", "javascript" },true,true, nil)
        
    '';
  };
}  
