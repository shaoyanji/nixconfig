{ pkgs, ... }:
let
  user = import ../../modules/global/user.nix;
in
{
  networking.hostName = "guckloch";

  wsl.enable = true;
  wsl.defaultUser = user.name;
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  users.users.${user.name}.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    markdownlint-cli
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib
    openssl
  ];

  home-manager.users.${user.name} = {
    imports = [
      ../../modules/user/ai/skills
      ../../modules/user/ai/antigravity-cli.nix
    ];
  };

  system.stateVersion = "25.05";
}
