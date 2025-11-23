{
  inputs,
  pkgs,
  ...
}: {
  programs = {
    amfora = {
      enable = true;
    };
    aichat = {
      enable = true;
      settings = {
        model = "groq:moonshotai/kimi-k2-instruct";
        clients = [
          {
            type = "openai-compatible";
            name = "groq";
            api_base = "https://api.groq.com/openai/v1";
          }
        ];
      };
    };
  };
}
