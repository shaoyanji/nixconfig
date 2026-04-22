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
          provider = "nous";
          default = "nvidia/nemotron-3-super-120b-a12b:free";
          # default = "xiaomi/mimo-v2-pro";
        };
        terminal = {
          backend = "local";
          timeout = 180;
        };
        toolsets = ["all"];
        memory.provider = "holographic";
      };
    };
  };
}
