{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.xs;
in {
  options.aiServices.xs = {
    enable = lib.mkEnableOption "experimental xs event-store service";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "xs package used for the experimental host-local service.";
    };
    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/xs";
      description = "Root path used as HOME and persistent state for xs.";
    };
    storePath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/xs/store";
      description = "Persistent xs event-store path passed to `xs serve`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "aiServices.xs.package must be set when aiServices.xs.enable = true";
      }
      {
        assertion = lib.hasPrefix cfg.workspaceRoot cfg.storePath;
        message = "aiServices.xs.storePath must live under aiServices.xs.workspaceRoot";
      }
    ];

    users.groups.xs = {};

    users.users.xs = {
      isSystemUser = true;
      group = "xs";
      home = cfg.workspaceRoot;
      createHome = true;
      description = "Experimental xs event-store service user";
    };

    environment.systemPackages = [cfg.package];

    systemd.tmpfiles.rules = [
      "d ${cfg.workspaceRoot} 0750 xs xs -"
      "d ${cfg.storePath} 0750 xs xs -"
    ];

    systemd.services.xs = {
      description = "xs Experimental Event Store";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        User = "xs";
        Group = "xs";
        WorkingDirectory = cfg.workspaceRoot;
        ExecStart = "${cfg.package}/bin/xs serve ${cfg.storePath}";
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0077";

        Environment = [
          "HOME=${cfg.workspaceRoot}"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.workspaceRoot];
      };
    };
  };
}
