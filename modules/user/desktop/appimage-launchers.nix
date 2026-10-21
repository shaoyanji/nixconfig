# Launcher entries for the AppImages kept in the shared NAS library.
#
# The images stay where they are (`/Volumes/data/appimages`, symlinked as
# ~/Applications/appimages) and are executed by appimage-run through binfmt; this
# module only keeps ~/.local/share/applications in sync so DMS and fuzzel list
# them like any other application. It reads each image's embedded .desktop and
# icon out of the squashfs (`unsquashfs -cat`), so nothing is executed, unpacked
# in full, or copied.
#
# Linux-only: `systemd.user` and binfmt have no darwin counterpart, and the
# script's `file`/`readelf`/`unsquashfs` reads assume an ELF AppImage.
{
  lib,
  pkgs,
  ...
}: let
  integrate = pkgs.writeShellApplication {
    name = "appimage-integrate";
    runtimeInputs = with pkgs; [
      binutils
      coreutils
      file
      gawk
      gnugrep
      gnused
      squashfs-tools
    ];
    text = builtins.readFile ../../../scripts/task/appimage-integrate.sh;
  };
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
