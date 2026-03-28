{...}: {
  programs.mods = {
    enable = true;
    settings = {
      default-api = "ollama";
      default-model = "qwen3-coder-next:cloud";
      mcp-timeout = "15s";
      format = false;
      roles = {"default" = [];};
      raw = false;
      quiet = false;
      temp = 1.0;
      topp = 1.0;
      topk = 50;
      no-limit = false;
      word-wrap = 80;
      include-prompt-args = false;
      include-prompt = 0;
      max-retries = 5;
      fanciness = 10;
      status-text = "Generating";
      theme = "charm";
      max-input-chars = 12250;
      max-completion-tokens = 100;
      apis = {
        ollama = {
          base-url = "http://localhost:11434";
          models = {
            "minimax-m2.7:cloud".max-input-chars = 650000;
            "glm-5:cloud".max-input-chars = 650000;
            "qwen3-coder-next:cloud".max-input-chars = 650000;
          };
        };
      };
    };
  };
}
