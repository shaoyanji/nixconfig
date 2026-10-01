# LAN binary cache: harmonia served from the NAS (frieren).
#
# Lets every host on the LAN share store paths — the first host to
# fetch or build a path makes it available to all the others at LAN
# speed, instead of each host pulling from WAN caches independently.
#
# The signing keypair is fleet-wide static:
#   - private key: sops `harmonia_signing_key` in modules/secrets.yaml
#     (only enabled on the cache host)
#   - public key:  registered in modules/global/global.nix
#     ("frieren.lan-1:...")
{ config
, lib
, ...
}:
{
  options.services.harmonia-fleet = {
    enable = lib.mkEnableOption "the LAN harmonia binary cache (serves /nix/store contents)";
    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "TCP port harmonia listens on.";
    };
  };

  config = lib.mkIf config.services.harmonia-fleet.enable {
    sops.secrets.harmonia_signing_key = { };

    services.harmonia.cache = {
      enable = true;
      signKeyPaths = [ config.sops.secrets.harmonia_signing_key.path ];
      settings = {
        bind = "[::]:${toString config.services.harmonia-fleet.port}";
        # Advertised substituter priority; lower wins over cache.nixos.org
        # so LAN hits are always preferred.
        priority = 10;
      };
    };

    networking.firewall.allowedTCPPorts = [ config.services.harmonia-fleet.port ];
  };
}
