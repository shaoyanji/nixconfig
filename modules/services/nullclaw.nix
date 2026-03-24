{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.aiServices.nullclaw;
  nullclawPkg = pkgs.callPackage ../../pkgs/nullclaw.nix {};
in {
  options.aiServices.nullclaw = {
    enable = lib.mkEnableOption "NullClaw gateway service bundle";
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Listen host passed to `nullclaw gateway --host`.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Listen port passed to `nullclaw gateway --port`.";
    };
    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nullclaw";
      description = "Root path used for nullclaw HOME, state, and workspace.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/nullclaw.env";
      description = "Optional EnvironmentFile for nullclaw service.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.nullclaw = {};

    users.users.nullclaw = {
      isSystemUser = true;
      group = "nullclaw";
      home = cfg.workspaceRoot;
      createHome = true;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.workspaceRoot} 0750 nullclaw nullclaw -"
      "d ${cfg.workspaceRoot}/.nullclaw 0750 nullclaw nullclaw -"
      "d ${cfg.workspaceRoot}/workspace 0750 nullclaw nullclaw -"
    ];

    systemd.services.nullclaw = {
      description = "NullClaw Gateway";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path =
        config.environment.systemPackages
        ++ (with pkgs; [
          curl
          cacert
        ]);
      serviceConfig = {
        User = "nullclaw";
        Group = "nullclaw";
        WorkingDirectory = cfg.workspaceRoot;
        ExecStart = "${nullclawPkg}/bin/nullclaw gateway --host ${cfg.host} --port ${toString cfg.port}";
        Restart = "always";
        RestartSec = "5s";

        Environment = [
          "HOME=${cfg.workspaceRoot}"
          "NULLCLAW_HOME=${cfg.workspaceRoot}/.nullclaw"
          "NULLCLAW_WORKSPACE=${cfg.workspaceRoot}/workspace"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [cfg.workspaceRoot];
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = [cfg.environmentFile];
      };
    };
  };
}
