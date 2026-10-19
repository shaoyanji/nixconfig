# Reusable NixOS profile for Hermes agent environment, flexible YAML config, and secret templating.
# Isolates Hermes agent state strictly to frieren and manages secrets via SOPS.
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.hermes;
  user = import ../global/user.nix;
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

    # Flexible options for shared model and display settings
    model = {
      provider = lib.mkOption {
        type = lib.types.str;
        default = "nous";
        description = "Primary model provider in Hermes YAML config.";
      };
      default = lib.mkOption {
        type = lib.types.str;
        default = "inclusionai/ling-3.0-flash-sante:free";
        description = "Default model identifier in Hermes YAML config.";
      };
    };

    fallbackProviders = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [
        {
          provider = "openrouter";
          model = "thinkingmachines/inkling:free";
        }
        {
          provider = "deepseek";
          model = "deepseek-flash";
        }
      ];
      description = "Fallback model providers and models in Hermes YAML config.";
    };

    display = {
      interface = lib.mkOption {
        type = lib.types.enum ["cli" "tui"];
        default = "cli";
        description = "Hermes display interface (cli forces classic REPL, fixing Hermes 0.22 TUI breakdown).";
      };
      toolProgress = lib.mkOption {
        type = lib.types.str;
        default = "all";
        description = "Tool execution progress preview mode in Hermes YAML config.";
      };
    };

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

    extraYamlConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Arbitrary extra YAML configuration options to merge into Hermes config.";
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
      ../user/ai/hermes-user.nix
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
