{
  inputs,
  pkgs,
  ...
}: {
  programs = {
    # mods ={
    #   enable = true;
    #   settings = {
    #       default-model = "llama3.2";
    #       apis = {
    #         ollama = {
    #           base-url = "http://localhost:11434/api";
    #           models = {
    #             "llama3.2" = {
    #               max-input-chars = 650000;
    #             };
    #           };
    #         };
    #       };
    #     };
    # };
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
