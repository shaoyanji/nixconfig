# System One Decision Service Module (Julia-1 & Laya)
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.systemoneDecision;

  systemoneSrc = ./systemone;

  # Standalone CLI package wrapping python3 and the decision engine
  systemoneDecisionPkg = pkgs.writeShellApplication {
    name = "systemone-decision";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 "${systemoneSrc}/engine.py" "$@"
    '';
  };

  # Ensemble CLI package wrapping System 1 (Julia-1) + System 2 (Nemotron-3-Ultra) Pre-Harness
  systemoneEnsemblePkg = pkgs.writeShellApplication {
    name = "systemone-ensemble";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 "${systemoneSrc}/ensemble.py" "$@"
    '';
  };
in {
  options.services.systemoneDecision = {
    enable = lib.mkEnableOption "System One Decision Engine (Julia-1 & Laya)";

    package = lib.mkOption {
      type = lib.types.package;
      default = systemoneDecisionPkg;
      description = "The systemone-decision CLI wrapper package.";
    };

    ensemblePackage = lib.mkOption {
      type = lib.types.package;
      default = systemoneEnsemblePkg;
      description = "The systemone-ensemble pre-harness CLI wrapper package.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.enum ["julia-1" "laya"];
      default = "julia-1";
      description = "Default decision architecture (julia-1: 144M mmBERT, laya: 421M ModernBERT).";
    };

    installCli = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install decision and ensemble CLIs into system environment packages.";
    };

    # The envelope other agents call, so they do not each ship engine.py. Bind
    # loopback and put a proxy in front: on a host with `services.tailscale`,
    # `tailscale serve --https=<port>` is the tailnet mount (exp-120).
    serve = {
      enable = lib.mkEnableOption "the /v1/systemone HTTP envelope";

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Bind address. Loopback by default: the proxy is the perimeter.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8091;
        description = "Bind port (8090 is eisen's Laya, so stay off it).";
      };

      model = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["julia-1" "laya"]);
        default = null;
        description = "Architecture to serve; null follows defaultModel.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkIf cfg.installCli [
      cfg.package
      cfg.ensemblePackage
    ];

    # One process, one loopback port, no writes: the engine is pure computation,
    # so it is sandboxed harder than a service that owns state.
    systemd.services.systemone-decision-serve = lib.mkIf cfg.serve.enable {
      unitConfig.X-Fleet-Role = "daemon";
      description = "System One decision envelope (/v1/systemone) on ${cfg.serve.host}:${toString cfg.serve.port}";
      wantedBy = ["multi-user.target"];
      # No `network-online`: a loopback listener needs no network state.
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/systemone-decision --model ${
          if cfg.serve.model != null
          then cfg.serve.model
          else cfg.defaultModel
        } serve --host ${cfg.serve.host} --port ${toString cfg.serve.port}";
        Restart = "always";
        RestartSec = 2;
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        # Measured at 24 MiB; the cap is the runaway guard, not the expectation.
        MemoryMax = "256M";
      };
    };
  };
}
