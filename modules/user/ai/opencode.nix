{lib, ...}: let
  localAgents = import ../ai/agents.nix {inherit lib;};
  agentsJsonPath = ../../config/agents.json;
  remoteAgentsList = if builtins.pathExists agentsJsonPath
    then builtins.fromJSON (builtins.readFile agentsJsonPath)
    else [];
in {
  programs.opencode = {
    enable = true;
    settings = {
      provider = {
        ollama = {
          name = "Ollama (cloud)";
          npm = "@ai-sdk/openai-compatible";
          options.baseURL = "http://localhost:11434/v1";
          models = {
            "lfm2.5-thinking:latest" = {
              _launch = true;
              name = "lfm2.5-thinking:latest";
            };
            "qwen3.6" = {
              _launch = true;
              name = "qwen3.6";
            };
            "minimax-m2.7:cloud" = {
              _launch = true;
              name = "minimax-m2.7:cloud";
            };
            "glm-5.1:cloud" = {
              _launch = true;
              name = "glm-5.1:cloud";
            };
            "deepseek-v4-flash:cloud" = {
              _launch = true;
              name = "deepseek-v4-flash:cloud";
              limit = {
                context = 1000000;
                output = 327680;
              };
            };

            "kimi-k2.6:cloud" = {
              _launch = true;
              name = "kimi-k2.6:cloud";
              limit = {
                context = 262144;
                output = 32768;
              };
            };
          };
        };
      };
      # theme = "tokyonight";
      formatter."alejandra" = {
        command = ["alejandra"];
        extensions = [".nix"];
      };
      lsp.nixd.command = ["nixd"];
    };
    agents =
      lib.listToAttrs (map (agent: {
        name = lib.removeSuffix ".md" (lib.last (lib.splitString "/" agent.url));
        value = builtins.readFile (builtins.fetchurl {
          url = agent.url;
          sha256 = agent.sha256;
        });
      }) remoteAgentsList)
      // localAgents;
  };
}
