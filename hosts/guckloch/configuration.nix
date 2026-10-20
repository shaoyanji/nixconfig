{
  pkgs,
  config,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    ../../modules/profiles/sshfs-nas-client.nix
    ../../modules/config/authorized-keys.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = user.name;
  wsl.docker-desktop.enable = true;
  wsl.useWindowsDriver = true;
  users.users.${user.name} = {
    extraGroups = ["docker"];
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  environment.systemPackages = with pkgs; [
    markdownlint-cli
    simplex-chat
    (python3.withPackages (ps:
      with ps; [
        websockets
        requests
        aiohttp
      ]))
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib
    openssl
    gmp # for simplex-chat
  ];

  home-manager.users.${user.name} = {
    imports = [
      ../../modules/user/ai/skills
      ../../modules/user/ai/antigravity-cli.nix
    ];
  };

  system.stateVersion = "25.05";
}
