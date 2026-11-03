# Resident selector stage 1 (tools/selector/serve.py) as a user service.
# Clears [[flake/policies.nix#daemon-clears-kelly]] by the arithmetic in
# flake/daemons.nix; `checks:selector:sidecar` proves it answers the interpreter.
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
        # The script owns the lifecycle (detach + pidfile), so oneshot is honest.
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/selector-sidecar.sh start";
        ExecStop = "${pkgs.bash}/bin/bash ${cfg.repo}/scripts/task/selector-sidecar.sh stop";
        Restart = "on-failure";
        RestartSec = 10;
        Environment = [
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
