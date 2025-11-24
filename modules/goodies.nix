{
  inputs,
  pkgs,
  lib,
  ...
}: {
  programs = {
    gemini-cli = {
      enable=true;
      settings = lib.literalExpression ''{"theme": "Default","vimMode": true,"preferredEditor": "nvim","autoAccept": true}'';
      defaultModel = "gemini-3-pro-preview";
      # defaultModel = "gemini-2.5-flash-lite";
      commands = {
        changelog = {
            prompt =
              ''
              Your task is to parse the `<version>`, `<change_type>`, and `<message>` from their input and use the `write_file` tool to correctly update the `CHANGELOG.md` file.
              '';
            description = "Adds a new entry to the project's CHANGELOG.md file.";
          };
          "git/fix" = { # Becomes /git:fix
            prompt = "Please analyze the staged git changes and provide a code fix for the issue described here: {{args}}.";
            description = "Generates a fix for a given GitHub issue.";
          };
          };
      context = lib.literalExpression ''{
          GEMINI = '''
            # Global Context

            You are a helpful AI assistant for software development.

            ## Coding Standards

            - Follow consistent code style
            - Write clear comments
            - Test your changes
          ''';

          AGENTS = ./path/to/agents.md;

          CONTEXT = '''
            Additional context instructions here.
            ''';'
        }'';
    };
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
