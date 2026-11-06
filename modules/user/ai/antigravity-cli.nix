# Antigravity CLI (agy) — Google's successor to Gemini CLI.
{
  lib,
  config,
  pkgs,
  ...
}: {
  # Gated by profiles.ai.enable (see ./default.nix). `or true` keeps this
  # module active in chains that don't declare the option.
  config = lib.mkIf (config.profiles.ai.enable or true) {
    programs.antigravity-cli = {
      enable = lib.mkDefault true;
      package = pkgs.llm-agents.antigravity-cli;
      # Fast Gemini model, set via $GEMINI_MODEL (HM module behavior).
      defaultModel = "gemini-3.8-flash";

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
    home.sessionVariables = lib.mkIf config.programs.antigravity-cli.enable {
      AGY_CLI_DISABLE_AUTO_UPDATE = "true";
    };

    # Hermes' main subagent runner. One headless agy call, JSON on stdout, so a
    # parent turn parses a result instead of scraping a TUI. Every flag here is
    # one the skill proves by hand; the point of the wrapper is that the model
    # comes from GEMINI_MODEL (the same knob the gateway unit exports) and that
    # the git-work-tree precondition fails with a message rather than a hang.
    home.packages = lib.mkIf config.programs.antigravity-cli.enable [
      (pkgs.writeShellApplication {
        name = "agy-subagent";
        runtimeInputs = [config.programs.antigravity-cli.package pkgs.git pkgs.llm-agents.toon];
        text = ''
          usage() {
            cat <<'EOF'
          agy-subagent — run agy headless as a Hermes subagent; JSON on stdout

            agy-subagent '<prompt>' [--schema FILE] [--mode plan|auto|accept-edits] [--dir DIR] [--toon]

            --schema FILE   JSON schema (path or inline JSON) the final answer must satisfy
            --mode MODE     agent execution mode for the session
            --dir DIR       working directory (default: $PWD); must be a git work tree
            --toon          project the result to TOON (stdout); the size stat goes to stderr

          Env:
            GEMINI_MODEL          model for the run (default: gemini-3.8-flash)
            AGY_SUBAGENT_TIMEOUT  print-mode time limit in seconds (default: 900)
          EOF
          }

          prompt=""
          schema=""
          mode=""
          dir="$PWD"
          toon=0
          while [ $# -gt 0 ]; do
            case "$1" in
              --schema) schema="$2"; shift 2 ;;
              --mode) mode="$2"; shift 2 ;;
              --dir) dir="$2"; shift 2 ;;
              --toon) toon=1; shift ;;
              -h | --help) usage; exit 0 ;;
              -*) echo "agy-subagent: unknown flag $1" >&2; exit 2 ;;
              *) prompt="''${prompt:+$prompt }$1"; shift ;;
            esac
          done

          if [ -z "$prompt" ]; then
            usage >&2
            exit 2
          fi
          if [ ! -d "$dir" ]; then
            echo "agy-subagent: no such directory: $dir" >&2
            exit 2
          fi

          cd "$dir" || exit 2
          if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "agy-subagent: $dir is not a git work tree — agy refuses to start outside one" >&2
            exit 2
          fi

          args=(--model "''${GEMINI_MODEL:-gemini-3.8-flash}" --dangerously-skip-permissions --print "$prompt" --output-format json --print-timeout "''${AGY_SUBAGENT_TIMEOUT:-900}s")
          if [ -n "$schema" ]; then args+=(--json-schema "$schema"); fi
          if [ -n "$mode" ]; then args+=(--mode "$mode"); fi

          if [ "$toon" = 1 ]; then
            agy "''${args[@]}" | toon -e --stats
          else
            agy "''${args[@]}"
          fi
        '';
      })
    ];

    # Antigravity standalone project fallback to avoid project store read failures
    # when starting sessions without an explicit active workspace project.
    # Prevent Home Manager activation collisions when agy mutates settings.json at runtime
    home.file = lib.mkIf config.programs.antigravity-cli.enable {
      ".gemini/antigravity-cli/settings.json".force = true;

      ".gemini/config/projects/outside-of-project.json".text = builtins.toJSON {
        id = "outside-of-project";
        name = "Outside of Project";
        projectResources = {};
      };
    };
  };
}
