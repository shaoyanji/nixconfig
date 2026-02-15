{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
  ];
  programs = {
    uv = {
      enable = true;
      settings = {
        python-downloads = "never";
        python-preference = "only-system";
        pip.index-url = "https://test.pypi.org/simple";
      };
    };
    go = {
      enable = true;
      telemetry.mode = "off";
    };
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    # ghc
    # gcc
    # scc
    # gfortran
    # tcc
    # go
    # tinygo
    # rustc
    # cargo
    # lua
    # luajit
    # python3
    # lua51Packages.moonscript
    # nim
    # wasmtime
    # hare
    # haredoc
    # zig
    # dotnet-sdk
    # dotnet-runtime
  ];

  home.file = {
  };
  home.sessionVariables = {
    # DOTNET_ROOT = "${pkgs.dotnet-sdk}/share/dotnet";
    # DOTNET_CLI_TELEMETRY_OPTOUT = 1;
    # DOTNET_NOLOGO = 1;
    # DOTNET_SKIP_FIRST_TIME_EXPERIENCE = 1;
    # DOTNET_MULTILEVEL_LOOKUP = 0;
  };
  home.sessionPath = [
    "$HOME/.dotnet/tools"
    "$HOME/.cargo/bin"
    # "$HOME/.local/bin"
    # "$HOME/go/bin"
  ];
}
