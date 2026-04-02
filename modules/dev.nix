{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
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
  home.packages = with pkgs; [
  ];

  home.sessionVariables = {
  };
  home.sessionPath = [
    "$HOME/.dotnet/tools"
    "$HOME/.cargo/bin"
  ];
}
