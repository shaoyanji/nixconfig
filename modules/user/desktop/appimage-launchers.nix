# Syncs ~/.local/share/applications with /Volumes/data/appimages from the
# squashfs header (`unsquashfs -cat`), never executing or copying an image.
# Linux-only: `systemd.user` and binfmt have no darwin counterpart.
{
  lib,
  pkgs,
  ...
}: let
  # One packaged script for both callers: this module and hosts that run without
  # home-manager (`hosts/netbook`).
  integrate = import ../../scripts/appimage-integrate.nix {inherit pkgs;};
in
  lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [integrate];

    # Refresh at login and hourly: picking up a newly dropped AppImage should not
    # need a rebuild, and a run costs a couple of seconds against the library.
    systemd.user.services.appimage-launchers = {
      Unit = {
        Description = "Generate XDG launchers for the AppImages in the shared library";
        # The library is a NAS mount on most hosts; a missing mount is a no-op,
        # not a failure (the script exits 0 and the next hourly run retries).
        After = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${integrate}/bin/appimage-integrate --quiet";
        Nice = 10;
      };
    };

    systemd.user.timers.appimage-launchers = {
      Unit.Description = "Refresh AppImage launcher entries (login + hourly)";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = "1h";
        Unit = "appimage-launchers.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  }
