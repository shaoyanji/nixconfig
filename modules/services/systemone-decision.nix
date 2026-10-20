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
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkIf cfg.installCli [
      cfg.package
      cfg.ensemblePackage
    ];
  };
}
