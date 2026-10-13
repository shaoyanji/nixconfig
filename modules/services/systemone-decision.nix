# System One Decision Service Module (Julia-1 & Laya)
# Provides declarative packaging and optional HTTP / CLI service for typed AI decisions.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.systemoneDecision;

  engineScript = ./systemone/engine.py;

  # Standalone CLI package wrapping python3 and the decision engine
  systemoneDecisionPkg = pkgs.writeShellApplication {
    name = "systemone-decision";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 "${engineScript}" "$@"
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

    defaultModel = lib.mkOption {
      type = lib.types.enum ["julia-1" "laya"];
      default = "julia-1";
      description = "Default decision architecture (julia-1: 144M mmBERT, laya: 421M ModernBERT).";
    };

    installCli = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install systemone-decision into system environment packages.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkIf cfg.installCli [
      cfg.package
    ];
  };
}
