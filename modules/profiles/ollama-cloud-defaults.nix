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
      host = lib.mkDefault "127.0.0.1";
      openFirewall = lib.mkDefault true;
      loadModels = lib.mkDefault [
        "minimax-m2.7:cloud"
        "glm-5.1:cloud"
        "kimi-k2.6:cloud"
        "deepseek-v4-flash:cloud"
      ];
    };
  };
}
