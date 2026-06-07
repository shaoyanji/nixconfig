{lib, ...}: let
  localAgents = import ../ai/agents.nix {inherit lib;};
  agentsJsonPath = ../../config/agents.json;
  remoteAgentsList =
    if builtins.pathExists agentsJsonPath
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
            "gemma4:31bcloud" = {
              _launch = true;
              name = "gemma4";
            };
            # "deepseek-v4-flash:cloud" = {
            #   _launch = true;
            #   name = "deepseek-v4-flash:cloud";
            #   limit = {
            #     context = 1000000;
            #     output = 327680;
            #   };
            # };
            "minimax-m3:cloud" = {
              _launch = true;
              name = "minimax-m3:cloud";
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
            inherit (agent) url;
            inherit (agent) sha256;
          });
        })
        remoteAgentsList)
      // localAgents;
  };
}
