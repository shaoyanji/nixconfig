{ pkgs, config, ... }:
let
  user = import ../../modules/global/user.nix;
in
{
  networking.hostName = "guckloch";

  imports = [
    ../../modules/profiles/sshfs-nas-client.nix
    ../../modules/config/authorized-keys.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = user.name;
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  users.users.${user.name} = {
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

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
