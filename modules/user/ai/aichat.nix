{ lib
, config
, ...
}:
{
  # Gated by profiles.ai.enable (see ./default.nix). `or true` keeps this
  # module active in chains that don't declare the option.
  config = lib.mkIf (config.profiles.ai.enable or true) {
    programs.aichat = {
      enable = true;
      settings = {
        model = "ollama:minimax-m3:cloud";
        clients = [
          {
            type = "openai-compatible";
            name = "ollama";
            api_base = "http://localhost:11434/v1";
          }
        ];
      };
    };
  };
}
