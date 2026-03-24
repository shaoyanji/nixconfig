{
  withOpenclaw ? false,
  withHermes ? false,
}: {
  config,
  lib,
  ...
}: let
  cfg = config.profiles.aiHost;
in {
  imports =
    [
      ../services/nullclaw.nix
    ]
    ++ lib.optionals withOpenclaw [
      ../services/openclaw-gateway.nix
    ]
    ++ lib.optionals withHermes [
      ../services/hermes-agent.nix
    ];

  options.profiles.aiHost = {
    enable = lib.mkEnableOption "AI host service composition profile";
    openclaw.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable composed OpenClaw service module.";
    };
    nullclaw.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable composed NullClaw service module.";
    };
    hermes.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable composed Hermes service module.";
    };
  };

  config = lib.mkIf cfg.enable {
    aiServices.nullclaw.enable = cfg.nullclaw.enable;
  }
  // lib.optionalAttrs withOpenclaw {
    aiServices.openclawGateway.enable = cfg.openclaw.enable;
  }
  // lib.optionalAttrs withHermes {
    aiServices.hermesAgent.enable = cfg.hermes.enable;
  };
}
