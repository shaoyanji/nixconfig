{
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/server-hardening.nix
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ./media-stack.nix
    ./dns.nix
    ./tools.nix
    ./networking.nix
    ./ai.nix
    ../../modules/services/aria2-daemon.nix
  ];

  networking.hostName = "thinsandy";

  profiles.serverHardening = {
    enable = true;
    varLogDevice = "/srv/private/var-log";
    varCacheDevice = "/srv/private/var-cache";
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "127.0.0.1";
    nginx.enable = true;
    nginx.domain = "aria.cloudforest-kardashev.ts.net";
  };

  system.stateVersion = "25.05";
}
