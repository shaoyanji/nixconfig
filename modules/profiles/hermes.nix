# Reusable NixOS profile for Hermes agent environment and secret templating.
# Isolates host Telegram bot tokens to prevent multi-client polling conflicts.
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.hermes;
in {
  options.profiles.hermes = {
    enable = lib.mkEnableOption "Hermes agent environment and isolated secrets";

    telegramSecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Host-specific SOPS secret name containing the Telegram bot token and allowed users.
        If null, no Telegram token is injected into hermes.env, preventing multi-client bot polling conflicts.
        Only gateway hosts (such as frieren) should set this.
      '';
    };

    envPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/devji/.config/hermes/hermes.env";
      description = "Destination path for the assembled hermes .env file.";
    };

    agentTimeout = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "HERMES_AGENT_TIMEOUT setting (0 for unlimited).";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Base shared AI services environment and optional host Telegram secret
    sops.secrets = lib.mkMerge [
      {
        "ai-services-shared-env" = {
          owner = "devji";
          group = "users";
          mode = "0400";
        };
      }
      (lib.mkIf (cfg.telegramSecret != null) {
        "${cfg.telegramSecret}" = {
          owner = "devji";
          group = "users";
          mode = "0400";
        };
      })
    ];

    # 3. Assemble ~/.hermes/.env directly via SOPS template
    sops.templates."hermes.env" = {
      owner = "devji";
      group = "users";
      mode = "0400";
      path = cfg.envPath;
      content = ''
        ${config.sops.placeholder."ai-services-shared-env"}
        HERMES_AGENT_TIMEOUT=${toString cfg.agentTimeout}
        ${lib.optionalString (cfg.telegramSecret != null) config.sops.placeholder."${cfg.telegramSecret}"}
      '';
    };
  };
}
