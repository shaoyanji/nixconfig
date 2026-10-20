# The knowledge-graph sidecar (tools/kg-engine) as a user service.
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
