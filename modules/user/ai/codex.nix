{ config
, lib
, ...
}:
let
  cfg = config.ai.codex;
  defaultAgentsText = builtins.readFile ../../../AGENTS.md;
in
{
  options.ai.codex = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Materialize a default Codex guidance file in the user's home directory.";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "AGENTS.md";
      example = ".config/codex/AGENTS.md";
      description = "Home-relative path where the generated Codex guidance file is written.";
    };

    text = lib.mkOption {
      type = lib.types.lines;
      default = defaultAgentsText;
      description = ''
        Guidance text written to the generated Codex file.
        The default reuses the repository's canonical top-level AGENTS.md content.
      '';
    };
    enableAgentsDir = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Materialize .agents directory in the user's home directory.";
    };

    agentsDirTarget = lib.mkOption {
      type = lib.types.str;
      default = ".agents";
      description = "Home-relative path where the agent guidance and skills directory is written.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.${cfg.target}.text = cfg.text;
    home.file.${cfg.agentsDirTarget} = lib.mkIf cfg.enableAgentsDir {
      source = ../../../.agents;
      recursive = true;
    };
  };
}
