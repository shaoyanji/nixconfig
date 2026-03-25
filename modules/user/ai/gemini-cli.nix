{...}: {
  programs.gemini-cli = {
    enable = true;
    settings = {
      vimMode = true;
      preferredEditor = "nvim";
      autoAccept = true;
      security = {auth = {selectedType = "oauth-personal";};};
    };
    defaultModel = "gemini-2.5-flash";
    commands = {
      changelog = {
        prompt = ''
          Your task is to parse the `<version>`, `<change_type>`, and `<message>` from their input and use the `write_file` tool to correctly update the `CHANGELOG.md` file.
        '';
        description = "Adds a new entry to the project's CHANGELOG.md file.";
      };
      "git/fix" = {
        prompt = "Please analyze the staged git changes and provide a code fix for the issue described here: {{args}}.";
        description = "Generates a fix for a given GitHub issue.";
      };
    };
    context = {
      GEMINI = ''
        # Global Context

        You are a helpful AI assistant for software development.

        ## Coding Standards

        - Follow consistent code style
        - Write clear comments
        - Test your changes
      '';
    };
  };
}
