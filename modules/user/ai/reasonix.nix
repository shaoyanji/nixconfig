# reasonix — numtide's multi-model coding agent, the delegation CLI that is not
# a tool of the memory stack: own module, gated like the rest of the heavy
# suite. Usage: .agents/skills/reasonix.
{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf (config.profiles.ai.enable && config.profiles.ai.tier == "full") {
  home.packages = [pkgs.llm-agents.reasonix];
}
