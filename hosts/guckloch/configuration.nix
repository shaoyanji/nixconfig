{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  wsl.enable = true;
  wsl.defaultUser = "devji";
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  users.users.devji.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    markdownlint-cli
  ];

  programs.nix-ld.enable = true;

  system.stateVersion = "25.05";
}
