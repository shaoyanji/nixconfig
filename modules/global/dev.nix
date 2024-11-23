{ lib, config, pkgs, inputs, ... }:
{
  imports = [ 
  ];

  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    go
    tinygo
    rustc
    cargo
  ];
  
  home.file={
    
  };
}
