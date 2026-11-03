# The needle3 edge caller (scripts/task/edge-sidecar.sh) as a user service.
# Disabled by default and refused on hosts where the Kelly gate disagrees:
# [[flake/policies.nix#daemon-clears-kelly]] · docs/nix-patterns.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.edgeCaller;
  needle = import ../scripts/needle-model.nix {inherit pkgs;};
  host = pkgs.stdenv.hostPlatform;
in {
  options.programs.edgeCaller = {
    enable = lib.mkEnableOption "a login-resident needle3 edge caller";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Documents/nixconfig";
      description = ''
        Checkout whose edge scripts and task graph are used. The surface is
        compiled from this working tree, so a host without it gets no unit.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && host.isLinux && host.isAarch64) {
    systemd.user.services.edge-caller = {
      Unit = {
        Description = "needle3 edge caller (resident tool dispatcher, six typed tools)";
        ConditionPathExists = "${cfg.repo}/scripts/task/edge-serve.sh";
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The script starts the engine and exits; the pid and the idle window
        # belong to edge-sidecar.sh, so there is one lifecycle implementation.
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/edge-serve.sh";
        ExecStop = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/edge-sidecar.sh stop";
        Restart = "on-failure";
        RestartSec = 30;
        # A login unit that reaps itself is a lazy start with extra steps.
        Environment = [
          "EDGE_IDLE_SECONDS=0"
          "NEEDLE_ENGINE=${needle.engine}/bin/needle"
          "NEEDLE_WEIGHTS=${needle.weights}"
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.curl
              pkgs.jq
              pkgs.git
              pkgs.nix
            ]
          }"
        ];
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
