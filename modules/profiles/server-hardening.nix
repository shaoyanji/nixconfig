{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.profiles.serverHardening;
in {
  options.profiles.serverHardening = {
    enable = mkEnableOption "Server hardening — journald caps, tmp cleanup, /var relocation";

    varLogDevice = mkOption {
      type = types.str;
      default = "/srv/private/var-log";
      description = "Target directory for /var/log bind mount. Set to empty string to disable.";
    };

    varCacheDevice = mkOption {
      type = types.str;
      default = "/srv/private/var-cache";
      description = "Target directory for /var/cache bind mount. Set to empty string to disable.";
    };
  };

  config = mkIf cfg.enable {
    # 1. Cap systemd journal — the single highest-impact change for /var pressure
    services.journald.extraConfig = ''
      SystemMaxUse=300M
      RuntimeMaxUse=200M
      MaxRetentionSec=1week
    '';

    # 2. Wipe /tmp on every boot (no state survives in tmp)
    boot.tmp.cleanOnBoot = true;

    # 3. Bind-mount /var/log to the large data disk
    #    x-systemd.requires ensures the target dir is mounted before this binds.
    fileSystems."/var/log" = mkIf (cfg.varLogDevice != "") {
      device = cfg.varLogDevice;
      fsType = "none";
      options = ["bind" "x-systemd.requires=systemd-tmpfiles-setup.service"];
    };

    # 4. Bind-mount /var/cache to the large data disk
    fileSystems."/var/cache" = mkIf (cfg.varCacheDevice != "") {
      device = cfg.varCacheDevice;
      fsType = "none";
      options = ["bind" "x-systemd.requires=systemd-tmpfiles-setup.service"];
    };

    # 5. Ensure target directories exist before the bind mount
    systemd.tmpfiles.rules =
      (optional (cfg.varLogDevice != "") "d ${cfg.varLogDevice} 0755 root root -")
      ++ (optional (cfg.varCacheDevice != "") "d ${cfg.varCacheDevice} 0755 root root -");
  };
}
