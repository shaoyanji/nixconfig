{...}: {
  programs.aichat = {
    enable = true;
    settings = {
      model = "ollama:minimax-m2.5:cloud";
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
