# Shared sops secrets for AI services infrastructure.
# Creates the ai-services-shared-env secret used by all services for
# model API keys and shared configuration.
#
# Usage:
#   imports = [ ../../modules/services/ai-services-secrets.nix ];
#   aiServices.sharedSecrets.enable = true;
{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.sharedSecrets;
in {
  options.aiServices.sharedSecrets = {
    enable = lib.mkEnableOption "AI services shared secrets (ai-services-shared-env)";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.ai-services-shared-env = {
      owner = "root";
      group = "root";
      mode = "0444";
    };
  };
}
