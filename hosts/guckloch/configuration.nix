{
  nixos-wsl,
  home-manager,
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.kickstart-nixvim.nixosModules.default
  ];
  programs.nixvim.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes" "pipe-operators"];
  wsl.enable = true;
  wsl.defaultUser = "devji";
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  virtualisation.docker.enable = true;
  users.users.devji.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    markdownlint-cli
  ];

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };

  system.stateVersion = "25.05";
}
