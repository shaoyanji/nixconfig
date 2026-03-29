{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.aiServices.openfang;
in {
  options.aiServices.openfang = {
    enable = lib.mkEnableOption "experimental OpenFang service bundle";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "OpenFang package to run for the experimental host-local service.";
    };
    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/openfang";
      description = "Root path used as HOME for the OpenFang service user.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/openfang/.openfang/openfang.env";
      description = "Optional EnvironmentFile for provider credentials and overrides.";
    };
    requireEnvironmentFile = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Skip service startup unless the configured environment file exists.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "aiServices.openfang.package must be set when aiServices.openfang.enable = true";
      }
    ];

    users.groups.openfang = {};

    users.users.openfang = {
      isSystemUser = true;
      group = "openfang";
      home = cfg.workspaceRoot;
      createHome = true;
      description = "Experimental OpenFang service user";
    };

    environment.systemPackages = [cfg.package];

    systemd.tmpfiles.rules = [
      "d ${cfg.workspaceRoot} 0750 openfang openfang -"
      "d ${cfg.workspaceRoot}/.openfang 0750 openfang openfang -"
      "d ${cfg.workspaceRoot}/.openfang/data 0750 openfang openfang -"
      "d ${cfg.workspaceRoot}/.openfang/logs 0750 openfang openfang -"
    ];

    systemd.services.openfang = {
      description = "OpenFang Experimental Agent Runtime";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig = lib.optionalAttrs (cfg.requireEnvironmentFile && cfg.environmentFile != null) {
        ConditionPathExists = cfg.environmentFile;
      };
      path = config.environment.systemPackages ++ (with pkgs; [cacert]);
      serviceConfig =
        {
          User = "openfang";
          Group = "openfang";
          WorkingDirectory = cfg.workspaceRoot;
          ExecStart = "${cfg.package}/bin/openfang start";
          Restart = "on-failure";
          RestartSec = "10s";

          Environment = [
            "HOME=${cfg.workspaceRoot}"
          ];

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = false;
          ReadWritePaths = [cfg.workspaceRoot];
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = [cfg.environmentFile];
        };
    };
  };
}
