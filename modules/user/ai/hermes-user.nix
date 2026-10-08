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
# into every chat turn (see --ignore-rules in hermes --help). Managed
# declaratively via home.file — always in sync with the source.
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
}: let
  personaDir = ./hermes-persona;
in {
  options.programs.hermes-user.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Seed ~/.hermes with the resurrected OpenClaw persona files and install
      a handoff-restore helper. Only meaningful on frieren (the mainframe).
    '';
  };

  config = lib.mkIf (config.programs.hermes-user.enable && (config.profiles.ai.enable or true)) {
    # Persona files — declarative, always in sync with source.
    home.file."SOUL.md".source = "${personaDir}/SOUL.md";
    home.file."AGENTS.md".source = "${personaDir}/AGENTS.md";
    home.file."USER.md".source = "${personaDir}/USER.md";
    home.file."MEMORY.md".source = "${personaDir}/MEMORY.md";
    home.file."config.yaml".source = "${personaDir}/config.yaml";

    # Symlinks — directories/env links can't be expressed as
    # declarative home.file targets; activation is the only way.
    home.activation.hermesSymlinks = lib.hm.dag.entryAfter ["writeBoundary"] ''
    home.file."AGENTS.md".source = "${personaDir}/AGENTS.md";
    home.file."USER.md".source = "${personaDir}/USER.md";
    home.file."MEMORY.md".source = "${personaDir}/MEMORY.md";
    home.file."config.yaml".source = "${personaDir}/config.yaml";

    # Symlinks — managed via activation (directories and env links
    # can't be expressed as declarative home.file targets).
    home.activation.hermesSymlinks = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p $HOME/.hermes
      run ln -sf /Volumes/data/openclaw $HOME/.hermes/openclaw-archive
      run ln -sf ${config.home.homeDirectory}/.config/hermes/hermes.env $HOME/.hermes/.env
      run ln -sf ${config.home.homeDirectory}/.agents/skills $HOME/.hermes/skills/agents-sync
    '';
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
    # If `hermes gateway install` ran anyway, it writes a raw (non-store)
    # unit over the declarative one and HM's checkLinkTargets then aborts
    # the whole switch with "would be clobbered" (seen 2026-10-08 on the
    # service file and its default.target.wants enable-symlink). Clear any
    # non-store copy before the link check so the declarative unit wins.
    home.activation.hermesGatewayUnitCleanup = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      for f in \
        "$HOME/.config/systemd/user/hermes-gateway.service" \
        "$HOME/.config/systemd/user/default.target.wants/hermes-gateway.service"; do
        if [ -e "$f" ]; then
          target="$(readlink "$f" 2>/dev/null || true)"
          case "$target" in
            /nix/store/*) ;; # HM-managed, leave it
            *) run rm -f "$f" ;; # generated by hermes gateway install
          esac
        fi
      done
    '';

    systemd.user.services.hermes-gateway = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit = {
        Description = "Hermes Agent Gateway - Messaging Platform Integration";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
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
          # /run/wrappers/bin MUST come first: it holds the setuid sudo
          # wrapper. A pkgs.sudo pulled into ~/.nix-profile (e.g. via the
          # hermes-agent dependency tree) is a plain store binary without
          # setuid and makes child agents fail escalation with "sudo binary
          # lacks setuid" (seen 2026-10-08).
          "PATH=/run/wrappers/bin:${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
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
      Install.WantedBy = ["default.target"];
    };
  };
}
