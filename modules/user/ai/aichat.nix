_: {
  programs.aichat = {
    enable = true;
    settings = {
      model = "ollama:kimi-k2.6:cloud";
      clients = [
        {
          type = "openai-compatible";
          name = "ollama";
          api_base = "http://localhost:11434/v1";
        }
      ];
    };
  };
}
