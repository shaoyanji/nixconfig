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
  ];

  networking.hostName = "thinsandy";

  profiles.serverHardening = {
    enable = true;
    varLogDevice = "/srv/private/var-log";
    varCacheDevice = "/srv/private/var-cache";
  };

  system.stateVersion = "25.05";
}
