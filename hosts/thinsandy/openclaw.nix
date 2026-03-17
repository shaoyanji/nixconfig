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
          nvidia = {
            baseUrl = "https://integrate.api.nvidia.com/v1";
            api = "openai-completions";
            models = [
              {
                id = "nvidia/openai/gpt-oss-20b";
                name = "nvidia/openai/gpt-oss-20b";
              }
              {
                id = "moonshotai/kimi-k2.5";
                name = "moonshotai/kimi-k2.5";
              }
            ];
          };
          ollama = {
            api = "ollama";
            apiKey = "ollama-local";
            baseUrl = "http://127.0.0.1:11434";
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
        compaction = {
          reserveTokensFloor = 20000;
          memoryFlush = {
            enabled = true;
            softThresholdTokens = 4000;
            systemPrompt = "Session nearing compaction. Store durable memories now.";
            prompt = "Write any lasting notes to memory/YYYY-MM-DD.md; reply with NO_REPLY if nothing to store.";
          };
        };
        memorySearch = {
          query = {
            hybrid = {
              enabled = true;
              vectorWeight = 0.7;
              textWeight = 0.3;
              candidateMultiplier = 4;
              #// Diversity: reduce redundant results
              mmr = {
                enabled = true; #    // default: false
                lambda = 0.7; #       // 0 = max diversity, 1 = max relevance
              };
              # Recency: boost newer memories
              temporalDecay = {
                enabled = true; #   // default: false
                halfLifeDays = 30; # // score halves every 30 days
              };
            };
          };
          provider = "gemini";
          model = "gemini-embedding-2-preview";
          outputDimensionality = 3072;
          extraPaths = [
          ];
        };
        model = {
          primary = "openrouter/openrouter/hunter-alpha";
          fallbacks = [
            "openai-codex/gpt-5.4"
            "nvidia/openai/gpt-oss-20b"
            "nvidia/openai/gpt-oss-120b"
            "nvidia/moonshotai/kimi-k2.5"
            "ollama/kimi-k2.5:cloud"
          ];
        };

        models = {
          "openrouter/openrouter/hunter-alpha" = {};
          "ollama/qwen3-coder-next:cloud" = {alias = "Qwen Coder";};
          "ollama/kimi-k2.5:cloud" = {alias = "Kimi";};
          "ollama/minimax-m2.5:cloud" = {alias = "MiniMax";};
          "ollama/glm-5:cloud" = {alias = "GLM";};
          "ollama/qwen3.5:cloud" = {alias = "Qwen";};
          "openai-codex/gpt-5.4" = {alias = "Codex";};
          "nvidia/openai/gpt-oss-20b" = {};
          "nvidia/openai/gpt-oss-120b" = {};
          "nvidia/moonshotai/kimi-k2.5" = {};
        };

        heartbeat = {
          every = "30m";
          lightContext = true;
          # isolatedSession = true;
          target = "none";
        };
      };
      agents.list = [
        {
          id = "main";
          tools.alsoAllow = ["lobster" "llm-task"];
        }
      ];
      tools.alsoAllow = ["lobster" "llm-task"];
      tools.web.search.provider = "brave";
      tools.web.search."brave".mode = "llm-context";
      tools.web.fetch = {
        firecrawl = {
          baseUrl = "https://api.firecrawl.dev";
          onlyMainContent = true;
          maxAgeMs = 172800000;
          timeoutSeconds = 60;
        };
      };
      # tools.web.search.provider = "firecrawl";
      # tools.web.search."firecrawl".baseURL = "https://api.firecrawl.dev";

      plugins.entries = {
        google-gemini-cli-auth.enabled = true;
        firecrawl.enabled = true;
        llm-task.enabled = true;
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
