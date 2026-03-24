{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.aiServices.openclawGateway;
in {
  options.aiServices.openclawGateway = {
    enable = lib.mkEnableOption "OpenClaw gateway service bundle";
    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/openclaw";
      description = "OpenClaw state/workspace root for host-level bind mount assumptions.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/openclaw";
      description = "Optional EnvironmentFile for the openclaw-gateway service.";
    };
    telegramTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/vanta-telegram";
      description = "Optional tokenFile path for openclaw telegram channel config.";
    };
  };

  config = lib.mkIf cfg.enable {
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
                  id = "nvidia/openai/gpt-oss-120b";
                  name = "nvidia/openai/gpt-oss-120b";
                }

                {
                  id = "qwen/qwen3-coder-480b-a35b-instruct";
                  name = "qwen/qwen3-coder-480b-a35b-instruct";
                }
                {
                  id = "qwen/qwen3.5-122b-a10b";
                  name = "qwen/qwen3.5-122b-a10b";
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
                  id = "minimax-m2.7:cloud";
                  name = "minimax-m2.7:cloud";
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
            primary = "openrouter/nvidia/nemotron-3-super-120b-a12b:free";
            fallbacks = [
              "openrouter/openrouter/free"
              "nvidia/qwen/qwen3.5-122b-a10b"
              "openai-codex/gpt-5.4"
              "nvidia/openai/gpt-oss-20b"
              "nvidia/openai/gpt-oss-120b"
              "nvidia/qwen/qwen3-coder-480b-a35b-instruct"
              "nvidia/moonshotai/kimi-k2.5"
              "ollama/kimi-k2.5:cloud"
              "ollama/minimax-m2.7:cloud"
            ];
          };

          models = {
            "openrouter/openrouter/free" = {};
            "openrouter/nvidia/nemotron-3-super-120b-a12b:free" = {};
            "ollama/qwen3-coder-next:cloud" = {alias = "Qwen Coder";};
            "ollama/kimi-k2.5:cloud" = {alias = "Kimi";};
            "ollama/minimax-m2.7:cloud" = {alias = "MiniMax";};
            "ollama/glm-5:cloud" = {alias = "GLM";};
            "ollama/qwen3.5:cloud" = {alias = "Qwen";};
            "openai-codex/gpt-5.4" = {alias = "Codex";};
            "nvidia/openai/gpt-oss-20b" = {};
            "nvidia/openai/gpt-oss-120b" = {};
            "nvidia/moonshotai/kimi-k2.5" = {};
            "nvidia/qwen/qwen3-coder-480b-a35b-instruct" = {};
            "nvidia/qwen/qwen3.5-122b-a10b" = {};
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
        plugins.enabled = true;
        plugins.allow = [
          "llm-task"
          "ollama"
          "vllm"
          "telegram"
          "open-prose"
          # "diffs"
          "lobster"
          "acpx"
          # "firecrawl"
          "google-gemini-cli-auth"
        ];
        plugins.entries = {
          # firecrawl.enabled = true;
          open-prose.enabled = true;
          google-gemini-cli-auth.enabled = true;
          llm-task.enabled = true;
          ollama.enabled = true;
          acpx.enabled = true;
          vllm.enabled = true;
          telegram.enabled = true;
          # diffs.enabled = true;
          lobster.enabled = true;
        };
        channels.telegram = {
          dmPolicy = "allowlist";
          allowFrom = [8207284912];
        } // lib.optionalAttrs (cfg.telegramTokenFile != null) {
          tokenFile = cfg.telegramTokenFile;
        };
      };
      environmentFiles = lib.optionals (cfg.environmentFile != null) [
        cfg.environmentFile
      ];

      environment = {
        NODE_COMPILE_CACHE = "/tmp";
        OPENCLAW_NO_RESPAWN = "1";
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
      morrow-telegram = {
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
  };
}
