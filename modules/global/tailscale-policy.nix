# Tailscale client accept-policy as data: one generated pair of flags, tuned per host.
{
  config,
  lib,
  options,
  ...
}: let
  cfg = config.fleet.tailscale;
  # nix-darwin has services.tailscale but not the Linux module's extraSetFlags
  # suboption. Test the leaf itself: optionalAttrs must settle this before the
  # module system sees the definition, because mkIf cannot hide a missing option.
  hasExtraSetFlags = options ? services.tailscale && options.services.tailscale ? extraSetFlags;
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

  config = lib.optionalAttrs hasExtraSetFlags {
    services.tailscale.extraSetFlags = lib.mkIf cfg.clientPolicy (lib.mkDefault [
      "--accept-dns=${lib.boolToString cfg.acceptDns}"
      "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
    ]);
  };
}
