# Resident selector stage 1 (tools/selector/serve.py) as a user service.
# Clears [[flake/policies.nix#daemon-clears-kelly]] by the arithmetic in
# flake/daemons.nix; `checks:selector:sidecar` proves it answers the interpreter.
#
# The artifact is an option, not a fixed path: a retrained or different model
# (nb today, a larger hermes-class one next) is `model = "…"` and a restart, and
# the unit's ConditionPathExists reads that same value — so an absent model is a
# skipped start, never a restart loop.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.selectorDaemon;
in {
  options.programs.selectorDaemon = {
    enable = lib.mkEnableOption "the resident selector stage 1 on $XDG_RUNTIME_DIR/selector.sock";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Documents/nixconfig";
      description = ''
        Checkout whose tools/selector and model are served. The model is trained
        from this working tree, so a host without it gets no unit.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.cache/nixconfig/selector/selector-nb.json";
      description = ''
        Trained artifact this unit serves, handed to the sidecar as `Q_MODEL`.
        The unit's start condition reads this path, so the artifact and the guard
        cannot disagree — which is what made an untrained host restart 3,140 times
        between 2026-11-03 and 2026-11-09.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    systemd.user.services.selector = {
      Unit = {
        Description = "Selector stage 1 (question -> query object on selector.sock)";
        # Both halves of "there is something to serve": the script and the model.
        # Guarding on serve.py alone was always true, so the missing artifact
        # surfaced as ExecStart exit 1 rather than as a skip.
        ConditionPathExists = [
          "${cfg.repo}/tools/selector/serve.py"
          cfg.model
        ];
        # A unit that fails identically on every attempt is not making progress.
        # Restart=on-failure with no limit is a log amplifier, not resilience.
        StartLimitIntervalSec = 300;
        StartLimitBurst = 3;
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The script owns the lifecycle (detach + pidfile), so oneshot is honest.
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/selector-sidecar.sh start";
        ExecStop = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/selector-sidecar.sh stop";
        Restart = "on-failure";
        RestartSec = 10;
        Environment = [
          "Q_MODEL=${cfg.model}"
          "SELECTOR_SOCKET=%t/selector.sock"
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.util-linux
              pkgs.git
              pkgs.curl
              pkgs.jq
              pkgs.python3
            ]
          }"
        ];
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
