# BurgerNAS cold vault (Synology DS220j) as an automount.
#
# One home for the mount *and* for how it is allowed to fail. The NAS is powered
# off for most of the day, so anything that walks the mount table — `duf`, `btop`,
# `updatedb`, a `findmnt -a` — probes a peer that is not there, and the default
# NFS mount behaviour makes that probe expensive:
#
#   * `mount.nfs` retries a failed mount for **2 minutes** by default (`retry=`,
#     counted in minutes; it is not the data-path `retrans`). With the peer off
#     the connect itself fails in under a second ("No route to host"), so `retry=0`
#     removes the entire wait.
#   * Without it, each probe held systemd for 90 s until `DefaultTimeoutStartSec`
#     killed `mount.nfs` (measured 2026-10-28, `Result=timeout` in the journal).
#     `duf` looked hung and printed nothing, because it `statfs()`es every mount
#     before it applies any `--hide-*` filter; `df` survived only because it skips
#     autofs entries without a statfs (17 ms against a blocking probe).
#
# The options therefore belong to the mount, not to a host: a host that enables
# this profile gets a mount that fails in seconds, and no disk tool can be blocked
# by a sleeping NAS.
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.burgernas-client;
in {
  options.profiles.burgernas-client = {
    enable = lib.mkEnableOption "the BurgerNAS cold-vault export as an automount";

    host = lib.mkOption {
      type = lib.types.str;
      default = "192.168.3.92";
      description = "BurgerNAS LAN address. An automount's `What=` is fixed, so this cannot be a tailnet name.";
    };

    export = lib.mkOption {
      type = lib.types.str;
      default = "/volume1/peachcable";
      description = "Exported path on the NAS. It exports nothing else (see the burgernas skill).";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/burgernas/peachcable";
      description = "Where the export appears. Parent directories are created by tmpfiles.";
    };

    idleTimeout = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "Unmount after this long without access, so the NAS can go back to sleep.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems.${cfg.mountPoint} = {
      device = "${cfg.host}:${cfg.export}";
      fsType = "nfs4";
      options = [
        # DSM's kernel has no NFSv4.2 (it answers "Protocol not supported"), so
        # 4.1 is pinned rather than negotiated.
        "vers=4.1"
        # `soft` + short data-path retries: a read against a NAS that vanished
        # mid-transfer returns an error instead of hanging the caller for minutes.
        "soft"
        "timeo=100"
        "retrans=2"
        # The two options this profile exists for — see the header.
        "retry=0"
        "x-systemd.mount-timeout=10s"
        # Nothing mounts at boot, and a dead NAS never blocks the boot either.
        "noauto"
        "nofail"
        "_netdev"
      ];
    };

    # `x-systemd.mount-timeout` bounds the mount(8) call, not the unit: on
    # 2026-10-28 `mnt-burgernas-peachcable.mount` sat in `activating` for 30 min
    # 1.47 s before failing. The timeout is declared on the unit itself.
    systemd.mounts = [
      {
        what = "${cfg.host}:${cfg.export}";
        where = cfg.mountPoint;
        overrideStrategy = "asDropin";
        unitConfig = {
          TimeoutStartSec = "10s";
          TimeoutStopSec = "10s";
        };
      }
    ];

    # NixOS does not translate `x-systemd.automount` in fileSystems options into an
    # automount unit (tasks/filesystems.nix only reads autoResize/autoFormat), so the
    # unit is declared here: nothing mounts at boot, and the first access wakes the
    # NAS instead of blocking local-fs.target behind it.
    systemd.automounts = [
      {
        where = cfg.mountPoint;
        wantedBy = ["multi-user.target"];
        automountConfig.TimeoutIdleSec = cfg.idleTimeout;
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${dirOf cfg.mountPoint} 0755 root root -"
    ];
  };
}
