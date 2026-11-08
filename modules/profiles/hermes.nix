# Reusable NixOS profile for Hermes agent environment, flexible YAML config, and secret templating.
{
  self,
  config,
  lib,
  user,
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
      default = "${user.home}/.config/hermes/hermes.env";
      description = "Destination path for the assembled hermes .env file.";
    };

    agentTimeout = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "HERMES_AGENT_TIMEOUT setting (0 for unlimited).";
    };

    # Model, display, fallback and arbitrary YAML settings are deliberately not
    # options here. The YAML is authored in modules/user/ai/hermes-persona/
    # config.yaml and symlinked to ~/.hermes/config.yaml by hermes-user.nix, so
    # an option naming a YAML key would write no file: `model`, `display`,
    # `fallbackProviders` and `extraYamlConfig` existed in that shape and were
    # read by nobody. Edit the persona file. (Removed 2026-11-05; `hermes
    # doctor` now reports that file as v51, which is the version to keep.)

    gateway = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the background messaging gateway daemon (Telegram/Discord/SimpleX).";
      };
    };

    simplex = {
      daemon = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run simplex-chat as a background WebSocket daemon.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5225;
        description = "Port for the simplex-chat WebSocket daemon.";
      };
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

    # 2. Assemble ~/.hermes/.env directly via SOPS template
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

    # 3. Exclusively share home-manager module with hosts that enable profiles.hermes
    home-manager.sharedModules = [
      self.modules."user.ai.hermes-user"
    ];

    home-manager.users.${user.name} = {
      programs.hermes-user = {
        enable = lib.mkDefault true;
        gateway.enable = lib.mkDefault cfg.gateway.enable;
        simplex.daemon = lib.mkDefault cfg.simplex.daemon;
        simplex.port = lib.mkDefault cfg.simplex.port;
        envFile = lib.mkDefault "/run/secrets/rendered/hermes.env";
      };
    };
  };
}
