{ config, lib, ... }: let
  cfg = config.profiles.aiHost;
  hasNullclawDeployment = config.aiServices ? nullclawDeployment;
  nullclawDeploymentEnabled =
    hasNullclawDeployment
    && config.aiServices.nullclawDeployment.enable;
  hasZeroclawDeployment = config.aiServices ? zeroclawDeployment;
  zeroclawDeploymentEnabled =
    hasZeroclawDeployment
    && config.aiServices.zeroclawDeployment.enable;
in {
  imports = [
    ../services/nullclaw.nix
    ../services/zeroclaw.nix
  ];

  options.profiles.aiHost = {
    enable = lib.mkEnableOption "AI host service composition profile";
    nullclaw.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable composed NullClaw service module.";
    };
    zeroclaw.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable composed ZeroClaw service module.";
    };
  };

  config =
    lib.mkIf cfg.enable {
      assertions = (lib.optionals hasNullclawDeployment [
        {
          assertion = cfg.nullclaw.enable == nullclawDeploymentEnabled;
          message = "profiles.aiHost.nullclaw.enable must match aiServices.nullclawDeployment.enable when nullclaw-deployment is imported";
        }
      ]) ++ (lib.optionals hasZeroclawDeployment [
        {
          assertion = cfg.zeroclaw.enable == zeroclawDeploymentEnabled;
          message = "profiles.aiHost.zeroclaw.enable must match aiServices.zeroclawDeployment.enable when zeroclaw-deployment is imported";
        }
      ]);

      aiServices.nullclaw.enable = lib.mkDefault cfg.nullclaw.enable;
      services.zeroclaw.instances = lib.mkIf (cfg.zeroclaw.enable && !zeroclawDeploymentEnabled) {
        zeroclaw = {};
      };
    };
}
