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
      # The Gemini API-key route, as a per-session profile. agy reads GEMINI_API_KEY
      # only when settings.json says modelProvider=gemini; the key alone is inert
      # (measured: `agy models` with the key exported lists only the account
      # models, and the same call with --settings '{"modelProvider":"gemini"}'
      # lists gemini-4-hydrogen-{low,medium,high,xhigh} and Carbon). --settings is
      # session-only and never saved, so the Pro OAuth session and the HM-owned
      # settings.json keep their account route as the default.
      (pkgs.writeShellApplication {
        name = "agy-gemini";
        runtimeInputs = [config.programs.antigravity-cli.package];
        text = ''
          usage() {
            cat <<'EOF'
          agy-gemini — agy on the Gemini API key route (Hydrogen), for this session only

            agy-gemini [agy args...]     e.g. agy-gemini -p 'hello'
            agy-gemini models            what the key unlocks

            Sets modelProvider=gemini via --settings, which agy never saves: the
            account route and ~/.gemini/antigravity-cli/settings.json are untouched,
            and requests bill the API key's project rather than the Pro plan. Pass
            your own --model to override the default.

          Env:
            GEMINI_API_KEY     required; a login shell exports it from the sops cache
            AGY_GEMINI_MODEL   default gemini-4-hydrogen-high
                               (low | medium | high | xhigh, as suffixed model ids)
            AGY_GEMINI_EFFORT  optional, passed as --effort (low|medium|high|xhigh|max)

          Budget: the free API tier allows a handful of requests per minute and about
          20 per day per project, and one agent turn is one request plus retries. A
          429 with quota_exceeded ends the day, so use this for a Hydrogen task and
          the account route for a long sweep. Unsuffixed ids (gemini-4-hydrogen) are
          the ones that answer 503 under load.
          EOF
          }

          case "''${1:-}" in
            -h | --help) usage; exit 0 ;;
          esac

          if [ -z "''${GEMINI_API_KEY:-}" ]; then
            echo "agy-gemini: GEMINI_API_KEY is unset — agy reads it only with modelProvider=gemini, which this sets." >&2
            exit 2
          fi

          args=(--settings '{"modelProvider":"gemini"}')

          # Subcommands (models, mcp, ...) take no model flag; everything else gets
          # the default unless the caller already picked one.
          model=0
          subcommand=0
          for a in "$@"; do
            case "$a" in
              --model) model=1 ;;
              models | agents | agent | mcp | plugin | plugins | acp | changelog | help | install | mic-serve | remote-control | update) subcommand=1 ;;
            esac
          done
          if [ "$subcommand" = 0 ] && [ "$model" = 0 ]; then
            args+=(--model "''${AGY_GEMINI_MODEL:-gemini-4-hydrogen-high}")
          fi
          if [ -n "''${AGY_GEMINI_EFFORT:-}" ]; then
            args+=(--effort "$AGY_GEMINI_EFFORT")
          fi

          exec agy "''${args[@]}" "$@"
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
