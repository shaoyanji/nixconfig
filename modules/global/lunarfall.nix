{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./heim.nix
    ../nixoshmsymlinks.nix
  ];
  home.packages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.system}.default
  ];
  home.file = {
  };
  home.sessionVariables = {
  };
  home.sessionPath = [
  ];
}
