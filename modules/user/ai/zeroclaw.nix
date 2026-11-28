# ZeroClaw as a lightweight always-on Home Manager messaging agent.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.zeroclaw-user;
  tomlFormat = pkgs.formats.toml {};
  configTemplate = tomlFormat.generate "zeroclaw-config.toml" cfg.settings;
  loadEnv = lib.optionalString (cfg.envFile != null) ''
    if [ -f ${lib.escapeShellArg cfg.envFile} ]; then
      . ${lib.escapeShellArg cfg.envFile}
    fi
  '';
  startScript = pkgs.writeShellScript "zeroclaw-user-start" ''
    set -eu

    mkdir -p ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.workspace}
    chmod 700 ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.workspace}

    ${loadEnv}

    : "''${INFRON_API_KEY:?INFRON_API_KEY is missing}"
    : "''${ZEROCLAW_TELEGRAM_BOT_TOKEN:?ZEROCLAW_TELEGRAM_BOT_TOKEN is missing}"

    cp ${configTemplate} ${lib.escapeShellArg cfg.dataDir}/config.toml
    chmod 600 ${lib.escapeShellArg cfg.dataDir}/config.toml

    exec ${pkgs.coreutils}/bin/env -i \
      HOME="$HOME" \
      USER="''${USER:-devji}" \
      SHELL=/bin/bash \
      PATH="$PATH" \
      ZEROCLAW_providers__models__custom__infron__api_key="$INFRON_API_KEY" \
      ZEROCLAW_providers__models__custom__infronretry__api_key="$INFRON_API_KEY" \
      ZEROCLAW_providers__models__custom__crow__api_key="''${CROWLLM_API_KEY:-}" \
      ZEROCLAW_providers__models__custom__sail__api_key="''${SAIL_API_KEY:-}" \
      ZEROCLAW_providers__models__custom__nvidia__api_key="''${NVIDIA_API_KEY:-}" \
      ZEROCLAW_providers__models__custom__openrouter__api_key="''${OPENROUTER_API_KEY:-}" \
      ZEROCLAW_channels__telegram__home__bot_token="$ZEROCLAW_TELEGRAM_BOT_TOKEN" \
      ${cfg.package}/bin/zeroclaw --config-dir ${lib.escapeShellArg cfg.dataDir} channel start
  '';
in {
  options.programs.zeroclaw-user = {
    enable = lib.mkEnableOption "the ZeroClaw messaging agent daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.zeroclaw;
      description = "ZeroClaw package to run.";
    };

    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Dotenv file containing the provider keys and ZEROCLAW_TELEGRAM_BOT_TOKEN.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.zeroclaw";
      description = "ZeroClaw config and state directory.";
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.zeroclaw/workspace";
      description = "Workspace the agent is constrained to.";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "160M";
      description = "systemd memory ceiling for the daemon.";
    };

    telegramAllowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Telegram numeric user IDs allowed to talk to the bot.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {
        schema_version = 4;

        providers.models = {
          custom.infron = {
            uri = "https://llm.onerouter.pro/v1";
            model = "qwen/qwen3.8-27b:free";
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
            fallback = [
              "custom.nvidia"
              "custom.openrouter"
              "custom.crow"
              "custom.infronretry"
              "custom.apisfree"
              "custom.sail"
            ];
          };
          custom.nvidia = {
            uri = "https://integrate.api.nvidia.com/v1";
            model = "nvidia/nemotron-3.5-super-vl-120b-a12b";
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
          };
          custom.openrouter = {
            uri = "https://openrouter.ai/api/v1";
            model = "baidu/ernie-5.5-flash-preview:free";
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
          };
          custom.crow = {
            uri = "https://crowllm.com/v1";
            model = "nemotron-3-ultra-550b-a55b-uncensored:free";
            fallback_models = [
              "crow-roleplay:free"
              "laguna-xs-2.1-uncensored:free"
            ];
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
          };
          custom.infronretry = {
            uri = "https://llm.onerouter.pro/v1";
            model = "qwen/qwen3.8-27b:free";
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
          };
          custom.apisfree = {
            uri = "https://api.apisfreellm.com/v1";
            model = "free-ai";
            api_key = "free";
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
          };
          custom.sail = {
            uri = "https://api.sailresearch.com/v1";
            model = "deepseek-ai/DeepSeek-V4.1-Flash-1017";
            timeout_secs = 180;
            context_window = 8192;
            native_tools = false;
          };
        };

        agents.primary = {
          model_provider = "custom.infron";
          runtime_profile = "lumi";
          risk_profile = "supervised";
          channels = ["telegram.home"];
          workspace = {
            path = cfg.workspace;
            unrestricted_filesystem = false;
          };
        };

        runtime_profiles.lumi = {
          agentic = true;
          compact_context = true;
          prompt_injection_mode = "compact";
          strict_tool_parsing = true;
          max_tool_iterations = 4;
          max_actions_per_hour = 20;
          max_cost_per_day_cents = 25;
          shell_timeout_secs = 20;
          max_delegation_depth = 1;
          delegation_timeout_secs = 60;
          agentic_timeout_secs = 120;
          max_history_messages = 20;
          max_context_tokens = 8000;
          parallel_tools = false;
          max_system_prompt_chars = 8000;
          max_tool_result_chars = 4000;
          keep_tool_context_turns = 1;
          memory_recall_limit = 3;
        };

        risk_profiles.supervised = {
          level = "supervised";
          workspace_only = true;
          require_approval_for_medium_risk = true;
          block_high_risk_commands = true;
        };

        memory = {
          backend = "sqlite.default";
          search_mode = "bm25";
        };

        storage.sqlite.default = {
          open_timeout_secs = 30;
        };

        channels.telegram.home = {
          enabled = true;
        };

        peer_groups.telegram_home = {
          channel = "telegram.home";
          external_peers = cfg.telegramAllowedUsers;
        };
      };
      description = "ZeroClaw config.toml as a Nix attrset. Secrets arrive through schema-mirror environment overrides.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.activation.zeroclawDirectories = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.workspace}
      run chmod 700 ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.workspace}
    '';

    systemd.user.services.zeroclaw = {
      Unit = {
        Description = "ZeroClaw lightweight messaging agent";
        After = ["network-online.target" "sops-nix.service"];
        Wants = ["network-online.target"];
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "simple";
        ExecStart = startScript;
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = 5;
        MemoryMax = cfg.memoryMax;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = cfg.dataDir;
        UMask = "0077";
        StandardOutput = "journal";
        StandardError = "journal";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "USER=${config.home.username}"
          "PATH=${config.home.homeDirectory}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
        ];
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
