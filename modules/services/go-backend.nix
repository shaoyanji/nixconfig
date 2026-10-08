{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.go-backend;
in {
  options.services.go-backend = {
    enable = lib.mkEnableOption "Go backend service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/go-backend.nix {};
      description = "Backend package to run.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port exposed by the backend process.";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host bind value exported via HOST env var.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables for the backend service.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.go-backend = {
      description = "Go backend";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        ExecStart = lib.getExe cfg.package;
        Environment =
          [
            "HOST=${cfg.host}"
            "PORT=${toString cfg.port}"
          ]
          ++ lib.mapAttrsToList (name: value: "${name}=${value}") cfg.environment;
      };
    };
  };
}
