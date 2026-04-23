# Sensible defaults for hermes-agent on AI hosts.
# Sets common settings that most hosts share. Hosts that differ
# (e.g. kellerbench with openrouter) override with regular definitions
# which win over mkDefault.
#
# Usage:
#   imports = [ ../../modules/profiles/hermes-defaults.nix ];
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  config = lib.mkIf (config.services.hermes-agent.enable or false) {
    services.hermes-agent = {
      package = lib.mkDefault inputs.hermes-agent.packages.${pkgs.system}.default;
      stateDir = lib.mkDefault "/var/lib/hermes";
      settings = lib.mkDefault {
        model = {
          # provider = "nous";
          default = "nvidia/nemotron-3-super-120b-a12b:free";
          # default = "xiaomi/mimo-v2-pro";
          # default = "arcee-ai/trinity-large-preview:free";
          provider = "openrouter";
        };
        terminal = {
          backend = "local";
          timeout = 180;
          cwd = "/var/lib/hermes/workspace";
        };
        compression = {
          enabled = true;
          threshold = 0.5;
          summary_provider = "gemini";
          summary_base_url = "";
          summary_model = "gemini-2.5-flash";
        };
        auxiliary = {
          compression = {
            provider = "gemini";
            base_url = "";
            model = "gemini-2.5-flash";
            api_key = "";
          };
          embeddings = {
            provider = "ollama";
            base_url = "http://localhost:11434";
            model = "all-minilm";
            api_key = "";
          };
          vision = {
            provider = "openai";
            base_url = "https://aihubmix.com/v1";
            model = "gpt-4.1-free";
            api_key = "";
          };
          session_search = {
            provider = "auto";
            base_url = "";
            model = "";
            api_key = "";
          };
          web_extract = {
            provider = "auto";
            base_url = "";
            model = "";
            api_key = "";
          };
          skills_hub = {
            provider = "auto";
            base_url = "";
            model = "";
            api_key = "";
          };
          mcp = {
            provider = "auto";
            base_url = "";
            model = "";
            api_key = "";
          };
          flush_memories = {
            provider = "auto";
            base_url = "";
            model = "";
            api_key = "";
          };
          approval = {
            provider = "auto";
            base_url = "";
            model = "";
            api_key = "";
          };
        };
        web = {
          backend = "tavily";
        };
        toolsets = ["all"];
        memory.provider = "holographic";
      };
    };
  };
}
