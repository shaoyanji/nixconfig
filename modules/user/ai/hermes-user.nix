# hermes — Nous Research's self-improving agent, frieren user-space persona.
#
# Hermes (pkgs.llm-agents.hermes-agent, v2026.9.14) is installed ONLY on
# frieren (the mainframe). This module seeds ~/.hermes with the resurrected
# OpenClaw persona from /Volumes/data/openclaw (agent "Vanta", 2026-03/04),
# whose four runtime files map 1:1 onto Hermes' auto-injected context:
#
#   OpenClaw (old)   ->  Hermes (~/.hermes)   ->  Purpose
#   ---------------------------------------------------------
#   SOUL.md          ->  SOUL.md              ->  orientation/voice
#   AGENTS.md        ->  AGENTS.md            ->  operational rules
#   USER.md          ->  USER.md              ->  user profile (Matt)
#   MEMORY.md        ->  MEMORY.md            ->  memory policy
#
# Hermes reads these from $HERMES_HOME (default ~/.hermes) and injects them
# into every chat turn (see --ignore-rules in hermes --help). The old daily
# memory log (95 files in /Volumes/data/openclaw/memory/) is NOT auto-loaded
# by Hermes; it stays as a greppable archive and can be curated into
# MEMORY.md over time (hermes memory setup can also attach mem0/Honcho).
#
# First-run (interactive, NOT declarative — hermes stores model/API config
# in ~/.hermes/config.yaml + .env):
#   hermes setup          # full wizard
#   hermes model          # provider + model picker (Nous Portal / OpenAI-
#                         # compatible / OpenRouter / Anthropic ...)
#   hermes memory setup   # optional external memory provider
#   hermes status         # verify
{
  lib,
  config,
  pkgs,
  ...
}:
let
  personaDir = ./hermes-persona;
in
{
  options.programs.hermes-user.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Seed ~/.hermes with the resurrected OpenClaw persona files and install
      a handoff-restore helper. Only meaningful on frieren (the mainframe).
    '';
  };

  config = lib.mkIf (config.programs.hermes-user.enable && (config.profiles.ai.enable or true)) {
    # Persona files are the user's live context — copy once on first
    # activation, never overwrite runtime edits afterwards.
    home.activation.hermesPersonaSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p $HOME/.hermes
      ${lib.concatMapStringsSep "\n"
        (f: ''
          if [ ! -e "$HOME/.hermes/${f}" ]; then
            run install -m 0644 ${personaDir}/${f} $HOME/.hermes/${f}
          fi
        '')
        [
          "SOUL.md"
          "AGENTS.md"
          "USER.md"
          "MEMORY.md"
          "config.yaml"
        ]
      }
      # Greppable archive of the old agent's daily memory log (95 files,
      # 2026-02..04). Symlinked read-write so future curation edits land
      # in one place alongside the live ~/.hermes.
      if [ ! -e "$HOME/.hermes/openclaw-archive" ]; then
        run ln -s /Volumes/data/openclaw $HOME/.hermes/openclaw-archive
      fi
      # Link .env to sops-managed hermes.env if present
      if [ ! -e "$HOME/.hermes/.env" ]; then
        if [ -f "$HOME/.config/hermes/hermes.env" ]; then
          run ln -sf "$HOME/.config/hermes/hermes.env" "$HOME/.hermes/.env"
        elif [ -f "/run/secrets/hermes" ]; then
          run ln -sf "/run/secrets/hermes" "$HOME/.hermes/.env"
        fi
      fi
    '';

    # Port of the old agent's handoff-restore discipline: hermes sessions
    # already capture scrollback; this helper restores the *operational*
    # state (persona pointers + latest archive savepoint) into a new chat.
    home.packages = [
      (pkgs.writeShellApplication {
        name = "hermes-handoff";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          gnused
        ];
        text = ''
          # hermes-handoff: print a resume-brief for the resurrected Vanta
          # persona from the OpenClaw archive + live ~/.hermes state.
          set -euo pipefail
          ARCHIVE="''${HERMES_ARCHIVE:-$HOME/.hermes/openclaw-archive}"

          latest_savepoint() {
            find "$ARCHIVE/memory" -name '*.md' -type f 2>/dev/null | sort | tail -"''${1:-1}" | head -1
          }

          echo "# Hermes handoff brief — $(date '+%Y-%m-%d %H:%M %Z')"
          echo
          echo "## Persona pointers"
          for f in SOUL.md AGENTS.md USER.md MEMORY.md; do
            if [ -f "$HOME/.hermes/$f" ]; then
              echo "- $f: $HOME/.hermes/$f ($(wc -l < "$HOME/.hermes/$f") lines)"
            fi
          done
          echo
          echo "## Latest archive savepoints"
          find "$ARCHIVE/memory" -name '*.md' -type f 2>/dev/null | sort | tail -3 | while read -r f; do
            echo "- $(basename "$f")  ($(head -1 "$f" | cut -c1-72))"
          done
          echo
          echo "## Restore"
          echo "hermes chat -z \"Read ~/.hermes/SOUL.md and \"
            \"\$($HOME/.hermes/openclaw-archive/handoffs/BOOT.md 2>/dev/null || echo 'the archive BOOT notes')\""
        '';
      })
    ];
  };
}
