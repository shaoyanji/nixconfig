{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  user = import ../../modules/global/user.nix;
in
{
  networking.hostName = "guckloch";

  wsl.enable = true;
  wsl.defaultUser = user.name;
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  users.users.${user.name}.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    markdownlint-cli
  ];

  programs.nix-ld.enable = true;

  system.stateVersion = "25.05";
}
