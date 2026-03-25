{lib, ...}: let
  localAgents = import ./agents.nix {inherit lib;};
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
            "minimax-m2.5:cloud" = {
              _launch = true;
              name = "minimax-m2.5:cloud";
            };
            "glm-5:cloud" = {
              _launch = true;
              name = "glm-5:cloud";
            };
            "qwen3-coder-next:cloud" = {
              _launch = true;
              name = "qwen3-coder-next:cloud";
              limit = {
                context = 262144;
                output = 32768;
              };
            };
          };
        };
      };
      theme = "tokyonight";
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
        }) (builtins.fromJSON (builtins.readFile ../../config/agents.json)))
      // localAgents;
  };
}
