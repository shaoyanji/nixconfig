# LAN binary cache: harmonia served from the NAS (frieren).
{
  config,
  lib,
  ...
}: {
  options.services.harmonia-fleet = {
    enable = lib.mkEnableOption "the LAN harmonia binary cache (serves /nix/store contents)";
    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "TCP port harmonia listens on.";
    };
  };

  config = lib.mkIf config.services.harmonia-fleet.enable {
    sops.secrets.harmonia_signing_key = {};

    services.harmonia.cache = {
      enable = true;
      signKeyPaths = [config.sops.secrets.harmonia_signing_key.path];
      settings = {
        bind = "[::]:${toString config.services.harmonia-fleet.port}";
        # Advertised substituter priority; lower wins over cache.nixos.org
        # so LAN hits are always preferred.
        priority = 10;
      };
    };

    networking.firewall.allowedTCPPorts = [config.services.harmonia-fleet.port];
  };
}
