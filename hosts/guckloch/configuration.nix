{
  self,
  pkgs,
  config,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    self.modules."profiles.sshfs-nas-client"
    self.modules."config.authorized-keys"
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
      self.modules."user.ai.skills"
      self.modules."user.ai.antigravity-cli"
    ];

    # The fleet syncs shell history over the tailnet, which this host is not on
    # (inventory.toml: guckloch network.tailscale = false), so the shared
    # address is unroutable here and atuin reports `invalid credentials` — the
    # same message a wrong password gives. Frieren's LAN address answers, and it
    # is read from the registry rather than restated.
    programs.atuin.settings.sync_address = lib.mkForce "http://${config.fleet.inventory.hosts.frieren.network.lan_ip}";
  };

  system.stateVersion = "25.05";
}
