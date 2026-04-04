{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.hermes-agent-local;
  # Default version to work around upstream bug that auto-detects "0.1.0".
  # Update this version when you want to track a newer Hermes release.
  defaultHermesPackage = inputs.hermes-agent.packages.${pkgs.system}.default.overrideAttrs (old: {
    version = "0.7.0";
  });
in {
  options.services.hermes-agent-local = {
    enable = lib.mkEnableOption "Hermes agent with version tracking";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultHermesPackage;
      example = lib.literalExpression ''
        inputs.hermes-agent.packages.''${pkgs.system}.default.overrideAttrs (old: {
          version = "0.7.0";
        })
      '';
      description = "Hermes agent package. Defaults to version 0.7.0 to work around upstream version auto-detection bug. Update the default in modules/services/hermes-agent-local.nix to track newer releases.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
      description = "State directory for Hermes agent.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Hermes agent settings (passed to upstream module).";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files for Hermes agent.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.hermes-agent = {
      # addToSystemPackages = true;
      # container.enable = true;
      enable = true;
      package = cfg.package;
      stateDir = cfg.stateDir;
      settings = cfg.settings;
      environmentFiles = cfg.environmentFiles;
    };
  };
}
