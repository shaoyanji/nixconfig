{
  config,
  pkgs,
  lib,
  ...
}: {
  services.openclaw-gateway = {
    enable = true;
    config = {
      models = {
        mode = "merge";
        providers = {
          ollama = {
            api = "ollama";
            apiKey = "ollama-local";
            baseUrl = "http://127.0.0.1:11434/v1";
            models = [
              {
                id = "qwen3.5:cloud";
                name = "qwen3.5:cloud";
                reasoning = true;
                input = ["text" "image"];
                contextWindow = 128000;
                maxTokens = 8192;
                cost = {
                  cacheRead = 0;
                  cacheWrite = 0;
                  input = 0;
                  output = 0;
                };
              }
              {
                id = "minimax-m2.5:cloud";
                name = "minimax-m2.5:cloud";
                reasoning = true;
                input = ["text"];
                contextWindow = 204800;
                maxTokens = 128000;
                cost = {
                  cacheRead = 0;
                  cacheWrite = 0;
                  input = 0;
                  output = 0;
                };
              }
              {
                id = "kimi-k2.5:cloud";
                name = "kimi-k2.5:cloud";
                reasoning = true;
                input = ["text" "image"];
                contextWindow = 262144;
                maxTokens = 262144;
                cost = {
                  cacheRead = 0;
                  cacheWrite = 0;
                  input = 0;
                  output = 0;
                };
              }
              {
                id = "glm-5:cloud";
                name = "glm-5:cloud";
                reasoning = true;
                input = ["text"];
                contextWindow = 128000;
                maxTokens = 8192;
                cost = {
                  cacheRead = 0;
                  cacheWrite = 0;
                  input = 0;
                  output = 0;
                };
              }
              {
                id = "qwen3-coder-next:cloud";
                name = "qwen3-coder-next:cloud";
                reasoning = false;
                input = ["text"];
                contextWindow = 262144;
                maxTokens = 32768;
                cost = {
                  cacheRead = 0;
                  cacheWrite = 0;
                  input = 0;
                  output = 0;
                };
              }
            ];
          };
        };
      };
      gateway.mode = "local";
      agents.defaults = {
        model = {
          primary = "openrouter/openrouter/hunter-alpha";
          fallbacks = [
            "ollama/minimax-m2.5:cloud"
            "openai-codex/gpt-5.4"
          ];
        };

        models = {
          "openai-codex/gpt-5.4" = {alias = "Codex";};
          "ollama/qwen3-coder-next:cloud" = {alias = "Qwen Coder";};
          "ollama/kimi-k2.5:cloud" = {alias = "Kimi";};
          "ollama/minimax-m2.5:cloud" = {alias = "MiniMax";};
          "ollama/glm-5:cloud" = {alias = "GLM";};
          "ollama/qwen3.5:cloud" = {alias = "Qwen";};
          "openrouter/openrouter/hunter-alpha" = {};
        };

        heartbeat = {
          every = "30m";
          lightContext = true;
          # isolatedSession = true;
          target = "none";
        };
      };
      plugins.entries.google-gemini-cli-auth = {
        enabled = true;
      };
      channels.telegram = {
        dmPolicy = "allowlist";
        tokenFile = config.sops.secrets."vanta-telegram".path;
        allowFrom = [8207284912];
      };
    };

    environmentFiles = [
      config.sops.secrets."openclaw".path
    ];

    environment = {
      OPENCLAW_NIX_MODE = "1";
    };
  };

  sops.secrets = {
    openclaw = {
      owner = "openclaw";
      group = "openclaw";
      mode = "0400";
    };
    telegram = {};
    vanta-telegram = {
      owner = "openclaw";
      group = "openclaw";
      mode = "0400";
    };
  };

  environment.sessionVariables = {
    OPENCLAW_NIX_MODE = "1";
  };

  environment.systemPackages = with pkgs; [
    openclaw
  ];
}
