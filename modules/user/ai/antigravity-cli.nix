# Antigravity CLI (agy) — Google's successor to Gemini CLI.
# Config schema per https://antigravity.google/docs/cli/reference/ (settings.json keys).
# Settings land in ~/.gemini/antigravity-cli/settings.json (managed by home-manager);
# auth tokens are stored in the OS keyring at first `agy` run, NOT in settings.json.
_: {
  programs.antigravity-cli = {
    enable = true;
    # Fast Gemini model, set via $GEMINI_MODEL (HM module behavior).
    defaultModel = "gemini-3.7-flash";

    settings = {
      # Display
      colorScheme = "tokyo night";
      altScreenMode = "default"; # adaptive: alt-screen locally, inline over SSH
      # Safety & permissions: full autonomy (agy's "dangerously skip permissions")
      # Both values are documented enum members, not gemini-cli-isms.
      toolPermission = "always-proceed";
      artifactReviewPolicy = "always-proceed";
      # Editor: external program via $EDITOR; vim modal editing inside the prompt
      editor = "auto";
      editorMode = "vim";
      # Notifications
      notifications = true;
      # Telemetry off
      enableTelemetry = false;
    };

    # Gemini CLI custom commands, migrated to Antigravity global skills
    # (written to ~/.gemini/antigravity-cli/skills/<name>/SKILL.md by HM).
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

    # Global context: ~/.gemini/GEMINI.md is still read by Antigravity CLI
    # (identical workspace-rule behavior to Gemini CLI, per migration docs).
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

  # agy's self-updater writes versioned binaries to ~/.local/bin, which is
  # impossible on NixOS (read-only store paths) and would shadow the
  # nix-managed binary on darwin; documented opt-out:
  home.sessionVariables = {
    AGY_CLI_DISABLE_AUTO_UPDATE = "true";
  };
}
