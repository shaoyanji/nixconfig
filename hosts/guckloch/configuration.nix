{ nixos-wsl, home-manager, config, lib, pkgs, ... }:

{
  imports = [
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  wsl.enable = true;
  wsl.defaultUser = "devji";
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  virtualisation.docker.enable = true;
  users.users.devji.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
      devenv
  ];

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };
  
  system.stateVersion = "24.05";

}

