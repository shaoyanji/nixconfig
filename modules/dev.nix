{ lib, config, pkgs, inputs, ... }:
{
  imports = [ 
  ];

  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    gcc
    go
    #tinygo
    rustc
    cargo
    #lua
    #luajit
    #python3
    #lua51Packages.moonscript
    #nim
    #wasmtime
    #hare
    #haredoc
    zig

  ];
  
  home.file={
    
  };
}
