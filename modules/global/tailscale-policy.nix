# Tailscale client accept-policy as data: one generated pair of flags, tuned per host.
{
  config,
  lib,
  options,
  ...
}: let
  cfg = config.fleet.tailscale;
in {
  options.fleet.tailscale = {
    clientPolicy = lib.mkEnableOption "the fleet tailscale accept-dns/accept-routes client policy";

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether tailscaled accepts DNS pushed by the tailnet.";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether tailscaled accepts subnet routes advertised on the tailnet.";
    };
  };

  config = lib.optionalAttrs (options ? services.tailscale) {
    services.tailscale.extraSetFlags = lib.mkIf cfg.clientPolicy (lib.mkDefault [
      "--accept-dns=${lib.boolToString cfg.acceptDns}"
      "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
    ]);
  };
}
