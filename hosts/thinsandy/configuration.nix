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

  sops.templates."aria2-rpc-env" = {
    content = ''
      RPC_SECRET=${config.sops.placeholder."aria2-rpc-secret"}
    '';
  };

  services.aria2-daemon = {
    enable = true;
    downloadDir = "/srv/data/downloads";
    rpcHost = "127.0.0.1";
    rpcSecretFile = config.sops.templates."aria2-rpc-env".path;
    nginx.enable = true;
    nginx.domain = "aria.cloudforest-kardashev.ts.net";
  };

  system.stateVersion = "25.05";
}
