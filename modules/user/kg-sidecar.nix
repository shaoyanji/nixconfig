# The knowledge-graph sidecar (tools/kg-engine) as a user service.
#
# The repo's scripts already know how to start and stop it, so this module is
# deliberately thin: a oneshot whose ExecStart/ExecStop are the same two
# commands `task ops:kg:sidecar` runs. What it adds is the thing that was
# missing — something actually STARTS it, so `kg-query.sh` can take its fast
# path (28 ms vs ~476 ms on a dirty tree) instead of silently falling back to
# jq every time.
#
# It serves the COMPILED projection (lib/knowledge-graph.nix), resolved from
# THIS checkout, so the socket and the jq surface read one graph. `--native` is
# the parity experiment behind `checks:kg:native`, never the daemon default.
#
# Skipped, not failed, when the checkout or the script is absent (a preserved
# host, a container without the repo): ConditionPathExists makes that a clean
# "not applicable" rather than a red unit on every login.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.kgSidecar;
in {
  options.programs.kgSidecar = {
    enable = lib.mkEnableOption "the in-memory knowledge-graph sidecar on $XDG_RUNTIME_DIR/kg.sock";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Documents/nixconfig";
      description = ''
        Checkout whose tools/kg-engine and graph are served. The graph is
        compiled from this working tree, so a host without it gets no unit.
      '';
    };
  };

  # systemd is Linux-only; the darwin role imports the same module.
  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    systemd.user.services.kg-sidecar = {
      Unit = {
        Description = "Knowledge-graph sidecar (compiled projection on kg.sock)";
        ConditionPathExists = "${cfg.repo}/scripts/task/kg-sidecar.sh";
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The script detaches the BEAM itself (setsid nohup) and writes its own
        # pidfile, so the unit stays active and ExecStop is the script's stop —
        # one implementation of the lifecycle, not two.
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/kg-sidecar.sh start";
        ExecStop = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/kg-sidecar.sh stop";
        Restart = "on-failure";
        RestartSec = 10;
        # elixir on PATH is the point: `resolve_elixir` then never invokes nix,
        # so the daemon starts in ~4 s without touching the network.
        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            # `setsid` detaches the BEAM; without it the start dies with
            # "setsid: command not found" and the unit reports failure at login.
            pkgs.util-linux
            pkgs.git
            pkgs.nix
            pkgs.curl
            pkgs.jq
            pkgs.beamPackages.elixir
          ]
        }";
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
