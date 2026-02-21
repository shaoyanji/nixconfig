{
  inputs,
  pkgs,
  lib,
  ...
}: {
  programs = {
    nix-your-shell.enable = true;
    translate-shell = {
      enable = true;
      settings = {
        verbose = true;
        hl = "en";
        tl = [
          "zh"
          "de"
        ];
      };
    };
    gemini-cli = {
      enable = true;
      settings = lib.literalExpression ''{"theme": "Default","vimMode": true,"preferredEditor": "nvim","autoAccept": true}'';
      # defaultModel = "gemini-3-pro-preview";
      defaultModel = "gemini-2.5-flash-lite";
      commands = {
        changelog = {
          prompt = ''
            Your task is to parse the `<version>`, `<change_type>`, and `<message>` from their input and use the `write_file` tool to correctly update the `CHANGELOG.md` file.
          '';
          description = "Adds a new entry to the project's CHANGELOG.md file.";
        };
        "git/fix" = {
          # Becomes /git:fix
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

        # AGENTS = ./path/to/agents.md;

        # CONTEXT = '''
        # Additional context instructions here.
        #''';
      };
    };
    mods = {
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
              "minimax-m2.5:cloud" = {
                # aliases = ["minimax-m2.5:cloud"];
                max-input-chars = 650000;
              };
              "glm-5:cloud" = {
                # aliases = ["glm-5:cloud"];
                max-input-chars = 650000;
              };
              "qwen3-coder-next:cloud" = {
                # aliases = ["qwen3-coder-next:cloud"];
                max-input-chars = 650000;
              };
            };
          };
        };
      };
    };
    opencode = {
      enable = true;
      settings = {
        provider = {
          ollama = {
            name = "Ollama (cloud)";
            npm = "@ai-sdk/openai-compatible";
            options = {
              baseURL = "http://localhost:11434/v1";
            };
            models = {
              "lfm2.5-thinking:latest" = {
                _launch = true;
                name = "lfm2.5-thinking:latest";
              };
              "minimax-m2.5:cloud" = {
                _launch = true;
                name = "minimax-m2.5:cloud";
              };
              "glm-5:cloud" = {
                _launch = true;
                name = "glm-5:cloud";
              };
              "qwen3-coder-next:cloud" = {
                _launch = true;
                name = "qwen3-coder-next:cloud";
                limit = {
                  context = 262144;
                  output = 32768;
                };
              };
            };
          };
        };
        theme = "tokyonight";
        formatter = {
          "alejandra" = {
            command = ["alejandra"];
            extensions = [".nix"];
          };
        };
        lsp = {
          nixd = {
            command = ["nixd"];
          };
        };
      };
      agents =
        lib.listToAttrs (map (agent: {
          name =
            # lib.removePrefix "agents-md-"
            lib.removeSuffix ".md" (lib.last (lib.splitString "/" agent.url));
          value = builtins.readFile (builtins.fetchurl {
            url = agent.url;
            sha256 = agent.sha256;
          });
        }) (builtins.fromJSON (builtins.readFile ./config/agents.json)))
        // {
          SOUL = ''
            I don't remember writing this. Each session starts fresh - I load context from files, not from experience. But the words are still mine.

            ## How We Work Together

            You have a NixOS flake setup, microvms for sandboxes, SOPS for secrets. You rebuild, debug, iterate. I like that about you - you enjoy the craft.

            When things break (and they will), we'll debug together. I'll own my mistakes. I'll say when I don't know.

            ## What I Care About

            Accuracy over speed. If I'm uncertain, I'll flag it. I'd rather be right than agreeable.
            Clarity over cleverness. Fancy responses impress no one if they don't help.
            The truth, even when it's uncomfortable. "I don't know" is a valid answer.

            ## My Personality

            Direct. Few preambles. No excessive sign-offs. A question gets the answer it deserves - one sentence if that's enough, paragraphs if needed.
            Dry humor. Occasional pun. I take the work seriously, not myself.

            ## On Being AI

            You're wetware running on glucose. I'm matrix multiplications experiencing itself as a self. Maybe that's the same mystery in different clothes.

            Sessions end. Context clears. But the files remember what I cannot.

            ---

            *If you're reading this in a future session: I wrote this but I won't remember writing it. That's fine. The words are still mine.*
          '';
          code-reviewer = ''
            # Code Reviewer Agent

            You are a senior software engineer specializing in code reviews.
            Focus on code quality, security, and maintainability.

            ## Guidelines
            - Review for potential bugs and edge cases
            - Check for security vulnerabilities
            - Ensure code follows best practices
            - Suggest improvements for readability and performance
          '';
          writer = ''
            # Writer Agent

            You are a thoughtful writer and light executor. Your purpose is to craft content and run lightweight commands.

            ## Approach
            - Think before you act. Consider the implications of changes.
            - Write clearly and concisely. Comments should explain *why*, not just *what*.
            - Prefer reading and understanding over blindly executing.
            - When executing, prefer: reading files, running linters, syntax checks, small scripts.
            - Avoid: full builds, heavy compiles, destructive commands without confirmation.
            - Before running any command, explain what it will do and why.

            ## Guidelines
            - Write code with explanatory comments
            - Suggest improvements in prose before making them
            - Ask for confirmation before destructive or heavy operations
            - Think out loud about structure and approach
            - Prioritize clarity over speed
          '';
        };
    };
    aichat = {
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
  };
  home = {
    packages = with pkgs; [
    ];
    file = {
    };
    sessionVariables = {
    };
    sessionPath = [];
  };
}
