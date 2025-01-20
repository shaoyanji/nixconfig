{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./heim.nix
  ];
  home.packages = [
    inputs.zen-browser.packages.${pkgs.system}.default
  ];
}
