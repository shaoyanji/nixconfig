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
    luajit
    python3
    #lua51Packages.moonscript
    #nim
    #wasmtime
    #hare
    #haredoc
    #zig
    dotnet-sdk
    #dotnet-runtime
  ];
  
  home.file={
    
  };
  home.sessionVariables = {
    DOTNET_ROOT="${pkgs.dotnet-sdk}/share/dotnet";
    DOTNET_CLI_TELEMETRY_OPTOUT=1;
    DOTNET_NOLOGO=1;
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1;
    DOTNET_MULTILEVEL_LOOKUP=0;
  };
}
