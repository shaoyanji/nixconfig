# hermes — Nous Research's self-improving agent, frieren user-space persona.
#
# Hermes (pkgs.llm-agents.hermes-agent) runs on frieren (the mainframe, as a
# host package — see hosts/frieren/tools.nix) and on delphi (the OCI ARM64
# bastion, via profiles/hermes.nix). Hosts are opted in per name through
# `programs.hermes-user.hosts`; the default is still frieren alone. This module
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
# into every chat turn (see --ignore-rules in hermes --help). On a host with a
# nixconfig checkout they are symlinked to source, so runtime edits
# version-control themselves; a host without one (delphi) gets a read-only
# store copy instead of silently seeding nothing.
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
  osConfig ? {},
  # ~/AGENTS.md itself comes from modules/user/ai/home-agents.nix (the flake's
  # `.#homeAgents.<host>`, injected via extraSpecialArgs in
  # modules/global/nixos.nix). This module only mirrors that link into
  # ~/.hermes/ for the gateway daemon.
  ...
}: let
  hostName = osConfig.networking.hostName or "";
  hosts = config.programs.hermes-user.hosts;
in {
  options.programs.hermes-user = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Seed ~/.hermes with the resurrected OpenClaw persona files and install
        hermes-agent CLI and environment.
      '';
    };

    hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["frieren"];
      description = ''
        Hosts on which the ~/.hermes persona activation runs. Hermes was
        frieren-only; the gate is a list so a second host (delphi) can opt in
        without forking the module. The runtime activation honours the same
        list, so a host that is enabled but not listed seeds nothing.
      '';
    };

    gateway = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the background messaging gateway daemon (Telegram/Discord/SimpleX).
          Disabled by default on client machines to avoid Telegram bot token polling conflicts.
        '';
      };
    };

    simplex = {
      daemon = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to run simplex-chat as a background WebSocket daemon (port 5225)
          for local Hermes gateway and multi-agent fleet integration.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5225;
        description = "Port for the simplex-chat WebSocket daemon.";
      };
    };

    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Absolute path to a dotenv file loaded into the gateway unit via
        EnvironmentFile (e.g. the sops-rendered /run/secrets/rendered/hermes.env).
        Null leaves credential loading entirely to hermes' own $HERMES_HOME/.env.
      '';
    };
  };

  # Deliberately NOT gated on `profiles.ai.enable`: that flag also decides
  # whether the heavy agent suite (Chromium, qmd, crush) is installed, and
  # host containers turn it off. Hermes has its own `enable`, set by
  # profiles/hermes.nix — coupling the two meant a cloud host had to install
  # the whole AI stack to get one agent.
  config = lib.mkIf (config.programs.hermes-user.enable && builtins.elem hostName hosts) {
    # Persona files — symlinked to nixconfig source.
    # Runtime edits modify the repo directly (version controlled).
    home.activation.hermesPersonaSymlinks = lib.hm.dag.entryAfter ["writeBoundary"] ''
      HOST_NAME="$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "${lib.head hosts}")"
      case " ${lib.concatStringsSep " " hosts} " in
        *" $HOST_NAME "*) : ;;
        *)
          echo "hermes-user: skipping activation on unlisted host ($HOST_NAME); see programs.hermes-user.hosts"
          exit 0
          ;;
      esac

      run mkdir -p $HOME/.hermes
      run mkdir -p $HOME/.hermes/memories

      REPO_DIR="$HOME/Documents/nixconfig"
      if [ ! -d "$REPO_DIR/.git" ] && [ -d "/Volumes/data/projects/nixconfig/.git" ]; then
        REPO_DIR="/Volumes/data/projects/nixconfig"
      elif [ ! -d "$REPO_DIR/.git" ] && [ -d "$HOME/nixconfig/.git" ]; then
        REPO_DIR="$HOME/nixconfig"
      fi

      # Persona source of last resort: a store copy of
      # modules/user/ai/hermes-persona. A host with no nixconfig checkout
      # (delphi is a cloud VM) would otherwise seed NOTHING here, and the
      # repo-symlink branch would fail silently rather than loudly. Store
      # copies cannot version-control a runtime edit, which is the right trade
      # for a host that needs the persona, not the repo.
      PERSONA_STORE="${./hermes-persona}"

      # Clean up misplaced files in $HOME from earlier experiments
      for f in SOUL.md USER.md MEMORY.md config.yaml; do
        if [ -L "$HOME/$f" ]; then
          run rm -f "$HOME/$f"
        fi
      done

      # 1. Base Hermes runtime config & memories in ~/.hermes/
      for f in config.yaml USER.md MEMORY.md; do
        run rm -f "$HOME/.hermes/$f"
        if [ -f "$REPO_DIR/modules/user/ai/hermes-persona/$f" ]; then
          run ln -s "$REPO_DIR/modules/user/ai/hermes-persona/$f" "$HOME/.hermes/$f"
        elif [ -f "$PERSONA_STORE/$f" ]; then
          run ln -s "$PERSONA_STORE/$f" "$HOME/.hermes/$f"
        fi
      done

      # 2. Host-specific persona (SOUL.md) in ~/.hermes/
      run rm -f "$HOME/.hermes/SOUL.md"
      if [ -f "$REPO_DIR/modules/user/ai/personas/$HOST_NAME/SOUL.md" ]; then
        run ln -s "$REPO_DIR/modules/user/ai/personas/$HOST_NAME/SOUL.md" "$HOME/.hermes/SOUL.md"
      elif [ -f "$REPO_DIR/modules/user/ai/personas/default/SOUL.md" ]; then
        run ln -s "$REPO_DIR/modules/user/ai/personas/default/SOUL.md" "$HOME/.hermes/SOUL.md"
      elif [ -f "$REPO_DIR/modules/user/ai/hermes-persona/SOUL.md" ]; then
        run ln -s "$REPO_DIR/modules/user/ai/hermes-persona/SOUL.md" "$HOME/.hermes/SOUL.md"
      elif [ -f "$PERSONA_STORE/SOUL.md" ]; then
        run ln -s "$PERSONA_STORE/SOUL.md" "$HOME/.hermes/SOUL.md"
      fi

      # 3. ~/AGENTS.md is Home Manager's (modules/user/ai/home-agents.nix →
      # `.#homeAgents.<host>`: fleet preamble + compiled inventory card +
      # persona). Do NOT recreate it here: home.file already links it during
      # writeBoundary, and this hook runs after — an `rm` + `ln -s` here would
      # fight that manager on every switch. This block only mirrors the link
      # into ~/.hermes/AGENTS.md for the systemd gateway daemon.
      run rm -f "$HOME/.hermes/AGENTS.md"
      if [ -f "$HOME/AGENTS.md" ]; then
        run ln -s "$HOME/AGENTS.md" "$HOME/.hermes/AGENTS.md"
      fi

      # /Volumes/data is the frieren NAS mount. A cloud host has none, and a
      # dangling symlink here makes hermes-handoff's `find` complain on every
      # run, so only link it when the archive is actually reachable.
      if [ ! -e "$HOME/.hermes/openclaw-archive" ] && [ -d /Volumes/data/openclaw ]; then
        run ln -s /Volumes/data/openclaw $HOME/.hermes/openclaw-archive
      fi
      # Hermes reads credentials exclusively from $HERMES_HOME/.env
      # (hermes_cli/config.py get_env_path). The sops template renders to
      # ~/.config/hermes/hermes.env (modules/profiles/hermes.nix envPath), so
      # bridge it here. Deleting this symlink on every switch is what broke
      # the gateway on 2026-10-09: it started without TELEGRAM_BOT_TOKEN,
      # exited 78, and RestartPreventExitStatus stopped systemd from
      # retrying. Only bridge when the target exists and .env is absent —
      # never clobber a real hermes-managed .env (auth flows write there).
      if [ ! -e "$HOME/.hermes/.env" ] && [ -e "$HOME/.config/hermes/hermes.env" ]; then
        run ln -s "$HOME/.config/hermes/hermes.env" "$HOME/.hermes/.env"
      fi
      if [ ! -e "$HOME/.hermes/skills/agents-sync" ] && [ -d "$HOME/.agents/skills" ]; then
        run mkdir -p "$HOME/.hermes/skills"
        run ln -sf "$HOME/.agents/skills" "$HOME/.hermes/skills/agents-sync"
      fi
    '';

    # Port of the old agent's handoff-restore discipline: hermes sessions
    # already capture scrollback; this helper restores the *operational*
    # state (persona pointers + latest archive savepoint) into a new chat.
    home.packages = [
      pkgs.llm-agents.hermes-agent
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
            /nix/store/*)
              ${lib.optionalString (!config.programs.hermes-user.gateway.enable) ''
        run rm -f "$f"
      ''}
              ;;
            *) run rm -f "$f" ;; # generated by hermes gateway install
          esac
        fi
      done
    '';

    systemd.user.services.simplex-chat = lib.mkIf (config.programs.hermes-user.simplex.daemon && pkgs.stdenv.hostPlatform.isLinux) {
      Unit = {
        Description = "SimpleX Chat WebSocket Daemon";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.simplex-chat}/bin/simplex-chat -p ${toString config.programs.hermes-user.simplex.port}";
        WorkingDirectory = "${config.home.homeDirectory}";
        Restart = "always";
        RestartSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = ["default.target"];
    };

    systemd.user.services.hermes-gateway = lib.mkIf (config.programs.hermes-user.gateway.enable && pkgs.stdenv.hostPlatform.isLinux) {
      Unit = {
        Description = "Hermes Agent Gateway - Messaging Platform Integration";
        After = ["network-online.target"] ++ lib.optional config.programs.hermes-user.simplex.daemon "simplex-chat.service";
        Wants = ["network-online.target"] ++ lib.optional config.programs.hermes-user.simplex.daemon "simplex-chat.service";
        # Hermes supervises its own restarts; never let systemd rate-limit it
        # into a permanent stop.
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.llm-agents.hermes-agent}/bin/hermes gateway run";
        WorkingDirectory = "${config.home.homeDirectory}/.hermes";
        # Inject the sops-rendered credential file directly into the unit so
        # the gateway never depends on the ~/.hermes/.env bridge symlink
        # being present at start time. "-" tolerates a missing file.
        EnvironmentFile =
          lib.mkIf (config.programs.hermes-user.envFile != null)
          "-${config.programs.hermes-user.envFile}";
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
