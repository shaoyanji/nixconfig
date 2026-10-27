# delphi keeps minyx (its declared `builder` in inventory) equal to main. One
# implementation, shared with `task infra:minyx:keep` —
# [`scripts/task/minyx-keeper.sh`](../../scripts/task/minyx-keeper.sh).
{
  lib,
  pkgs,
  ...
}: {
  # The service runs as devji (it needs that user's ssh key and the checkout) and
  # writes only the deployed rev, so the state directory must exist and be
  # writable before the first run.
  systemd.tmpfiles.rules = ["d /var/lib/minyx-keeper 0755 devji users -"];

  systemd.services.minyx-keeper = {
    description = "Deploy main to minyx over the LAN (delphi is its declared builder)";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "devji";
      Group = "users";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "minyx-keeper";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          dnsutils
          git
          nixos-rebuild
          openssh
        ];
        text = ''
          exec ${pkgs.bash}/bin/bash ${../../scripts/task/minyx-keeper.sh} "$@"
        '';
      });
      # A hang is worse than a failure here: the LAN ssh has its own timeout, and
      # this bounds the build that follows it.
      TimeoutStartSec = "45min";
    };
  };

  systemd.timers.minyx-keeper = {
    wantedBy = ["timers.target"];
    timerConfig = {
      # After frieren's 04:00 autoUpgrade and outside the 03:00-05:30 window the
      # fleet keeps clear, so the backup trails the primary by up to a day rather
      # than racing it.
      OnCalendar = "*-*-* 06:15";
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
  };
}
