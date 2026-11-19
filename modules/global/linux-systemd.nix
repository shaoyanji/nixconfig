{
  config,
  lib,
  ...
}: let
  hostName = config.networking.hostName or (config.hostName or "");
  hostMeta = config.fleet.inventory.hosts.${hostName} or {};
  oomdUserSlices = builtins.elem (hostMeta.category or "") ["cloud" "container-host" "server-and-workstation"];
in {
  systemd.oomd.enableUserSlices = lib.mkDefault oomdUserSlices;

  # Prevent missed maintenance timers from bursting during daytime production hours.
  systemd.timers = lib.mkIf config.nix.optimise.automatic {
    nix-optimise.timerConfig.Persistent = lib.mkDefault false;
  };

  # oomd ships enabled and managed by nobody; the journal cap was in five hosts.
  services.journald.settings.Journal = {
    SystemMaxUse = lib.mkDefault "300M";
    RuntimeMaxUse = lib.mkDefault "200M";
    MaxRetentionSec = lib.mkDefault "1week";
  };
}
