# aichat: model roles and providers, gated by `profiles.ai`.
{
  lib,
  config,
  ...
}: {
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
          # chatplayground's web chat models via the local shim
          # (programs.hermes-user.chatplayground). Small prompts only: the
          # upstream takes ONE message of at most 15,000 characters per request,
          # so a long pasted file will be refused where a normal chat turn is
          # not. `aichat -m chatplayground:gpt-6-luna "…"`.
          {
            type = "openai-compatible";
            name = "chatplayground";
            api_base = "http://127.0.0.1:8799/v1";
            api_key = "local-shim";
            models = [
              {
                name = "gpt-6-luna";
                max_input_tokens = 14000;
              }
              {
                name = "claude-haiku-5-5";
                max_input_tokens = 14000;
              }
              {
                name = "deepseek-v4.1-flash";
                max_input_tokens = 14000;
              }
            ];
          }
        ];
      };
    };
  };
}
