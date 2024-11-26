{ lib, config, pkgs, inputs, ... }:
{
  imports = [ 
  ];

  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    gcc
    go
    tinygo
    rustc
    cargo
  ];
  
  home.file={
    
  };
}
