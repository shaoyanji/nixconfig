# Default ollama config for AI hosts with cloud model serving.
# Only applies when services.ollama is already enabled by the host.
# Kellerbench overrides with cuda package and no loadModels.
{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.services.ollama.enable or false) {
    services.ollama = {
      host = lib.mkDefault "0.0.0.0";
      openFirewall = lib.mkDefault true;
      loadModels = lib.mkDefault [
        "gemma4:31b-cloud"
        "minimax-m2.7:cloud"
        "glm-5.1:cloud"
        "qwen3-coder-next:cloud"
        "kimi-k2.5:cloud"
        "qwen3.5:cloud"
      ];
    };
  };
}
