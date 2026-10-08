# hermes — Nous Research's self-improving agent, frieren user-space persona.
#
# Hermes (pkgs.llm-agents.hermes-agent) is installed ONLY on frieren (the
# mainframe), as a host package — see hosts/frieren/tools.nix. This module
# seeds ~/.hermes with the resurrected OpenClaw persona from
# /Volumes/data/openclaw (agent "Vanta", 2026-03/04),
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
{ lib
, config
, pkgs
, ...
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
      if [ -L "$HOME/.hermes/.env" ] || [ ! -e "$HOME/.hermes/.env" ]; then
        if [ -f "$HOME/.config/hermes/hermes.env" ]; then
          run ln -sf "$HOME/.config/hermes/hermes.env" "$HOME/.hermes/.env"
        elif [ -f "/run/secrets/hermes" ]; then
          run ln -sf "/run/secrets/hermes" "$HOME/.hermes/.env"
        fi
      fi
      # Sync ~/.agents/skills/ into hermes scan path so HM-deployed
      # skills become visible automatically on activation.
      if [ ! -e "$HOME/.hermes/skills/agents-sync" ]; then
        run ln -sf "$HOME/.agents/skills" "$HOME/.hermes/skills/agents-sync"
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

    # --- Messaging gateway (Telegram, Discord, …) ------------------------
    # Declared here instead of leaving it to `hermes gateway install`, because
    # that generator cannot produce a working unit under a Nix install: it bakes
    # sys.executable — the bare nix interpreter — into ExecStart, and that
    # interpreter has neither hermes_cli nor the gateway extras on sys.path, so
    # the unit crash-loops with ModuleNotFoundError (seen 2026-10-07: restart
    # counter 466). The llm-agents wrapper puts the entire dependency set on
    # sys.path itself and exports HERMES_PYTHON for child processes, so
    # ExecStart is just the wrapper.
    #
    # Do NOT run `hermes gateway install` on this host: it rewrites
    # ~/.config/systemd/user/hermes-gateway.service and clobbers this unit.
    #
    # The generated unit's ExecStop/ExecStopPost hooks
    # (`python -m gateway.systemd_stop_mark` / `gateway.cgroup_cleanup`) are
    # deliberately omitted: they are `-`-prefixed (non-fatal) and only maintain
    # a cosmetic stop marker in gateway_state.json, while llm-agents does not
    # export the dependency-bearing interpreter they need. KillMode=mixed still
    # tears the cgroup down on stop, and the gateway clears a stale marker on
    # next start.
    systemd.user.services.hermes-gateway = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit = {
        Description = "Hermes Agent Gateway - Messaging Platform Integration";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        # Hermes supervises its own restarts; never let systemd rate-limit it
        # into a permanent stop.
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.llm-agents.hermes-agent}/bin/hermes gateway run";
        WorkingDirectory = "${config.home.homeDirectory}/.hermes";
        Environment = [
          "HERMES_HOME=${config.home.homeDirectory}/.hermes"
          "HERMES_SUPERVISED_CHILD=1"
          "HOME=${config.home.homeDirectory}"
          "USER=${config.home.username}"
          "PATH=${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
        ];
        Restart = "always";
        RestartSec = 5;
        RestartForceExitStatus = 75;
        SuccessExitStatus = 75;
        RestartPreventExitStatus = 78;
        KillMode = "mixed";
        KillSignal = "SIGTERM";
        TimeoutStopSec = 70;
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
