# The resident selector stage 1 (tools/selector/serve.py) as a user service.
# Justified by [[flake/policies.nix#daemon-clears-kelly]]: flake/daemons.nix
# records the arithmetic, and `checks:selector:sidecar` proves this unit answers
# exactly what the interpreter answers.
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
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    systemd.user.services.selector = {
      Unit = {
        Description = "Selector stage 1 (question -> query object on selector.sock)";
        ConditionPathExists = "${cfg.repo}/tools/selector/serve.py";
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The script detaches the interpreter itself (setsid nohup) and writes its
        # own pidfile, so the unit stays active and ExecStop is the script's stop —
        # one implementation of the lifecycle, not two.
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/selector-sidecar.sh start";
        ExecStop = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/selector-sidecar.sh stop";
        Restart = "on-failure";
        RestartSec = 10;
        # `q.sh --question` reaches this socket; without the unit it falls back to
        # the interpreter, so a failed start costs latency and not an answer.
        Environment = [
          "SELECTOR_SOCKET=%t/selector.sock"
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              # `setsid` detaches the daemon; without it the start dies with
              # "setsid: command not found" and the unit fails at login.
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
