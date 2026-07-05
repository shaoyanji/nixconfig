{
  inputs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/server-hardening.nix
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ./media-stack.nix
    ./paperless.nix
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

  sops.secrets."aria2-rpc-secret" = {
    owner = "aria2";
    group = "aria2";
    mode = "0400";
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "127.0.0.1";
    rpcSecretFile = config.sops.secrets."aria2-rpc-secret".path;
    nginx.enable = true;
    nginx.listenPort = 6801;
  };

  networking.firewall.allowedTCPPorts = [
    8123  # HomeAssistant
    7351  # Stirling PDF
    6801  # AriaNg web UI
    28981 # Paperless-ngx
  ];

  system.stateVersion = "25.05";
}
