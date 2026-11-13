# hermes — Nous Research's self-improving agent, frieren user-space persona.
{
  lib,
  config,
  pkgs,
  # ~/AGENTS.md itself comes from modules/user/ai/home-agents.nix (the flake's
  # `.#homeAgents.<host>`, injected via extraSpecialArgs in
  # modules/global/nixos.nix). This module only mirrors that link into
  # ~/.hermes/ for the gateway daemon.
  ...
}: let
  # ~/.hermes/.env is DERIVED: the rendered credential file plus the keys only
  # this host defines (see scripts/task/hermes-env-sync.sh for why a plain file
  # shadowing a symlink was worse than either option alone).
  hermesEnvSync = pkgs.writeShellApplication {
    name = "hermes-env-sync";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gawk
      gnugrep
    ];
    text = builtins.readFile ../../../scripts/task/hermes-env-sync.sh;
  };

  # chatplayground: the `cpg` client. Three consumers, one binary — the advice
  # lane (`cpg chat`, `.agents/skills/cpg-advice`), image generation
  # (`cpg image`, `.agents/skills/cpg-image`), and the `serve` shim aichat
  # points at. No unit is needed for the first two: the thread lives server
  # side and only the new prompt is ever sent.
  #
  # Session credential: ~/.chatplayground/auth.json (0600), written by
  # `chatplayground-go login` or harvested from a signed-in browser. It is NOT a
  # secret managed here — the Clerk session behind it rotates, and a sops copy
  # would go stale silently. Every request mints a 60 s token from the
  # long-lived `__client` cookie, so an idle client pays nothing.
  #
  # buildGo127Module, not buildGoModule: the default Go here is 1.26.8 and
  # go.mod asks for 1.27.1, which fails the vendor FOD with "go.mod requires go
  # >= 1.27.1 (running go 1.26.8)". nixpkgs carries go_1_27 (1.27.2).
  chatplaygroundCli = pkgs.buildGo127Module rec {
    pname = "chatplayground-go";
    version = "1.2.3";
    src = pkgs.fetchFromGitHub {
      owner = "shaoyanji";
      repo = "chatplayground-go";
      rev = "016f7370361ed6881d61958dcc81cb778e8bb9f8";
      hash = "sha256-Lt/rqEx1c4SXix4xuwaftM6bvwWWQiDsD2k7IfOJ84w=";
    };
    vendorHash = "sha256-t1Bqg6w5O1AT7NGqIfptbTQsjY/X4NosMxRlz+VBxiw=";
    subPackages = ["."];
    ldflags = ["-s" "-w" "-X main.Version=1.2.3"];
    # `cpg` is the name that gets typed; the upstream binary keeps its own name
    # for the shim's ExecStart and for anyone following the project's docs.
    postInstall = ''
      ln -s chatplayground-go $out/bin/cpg
    '';
    meta = {
      description = "chatplayground client: self-contained `cpg chat`, plus an OpenAI-compatible serve mode";
      mainProgram = "cpg";
      license = pkgs.lib.licenses.mit;
    };
  };
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

    persona = lib.mkEnableOption ''
      the ~/.hermes persona files on this host. Per-host declaration rather than a
      hostname list compiled in this module: the gateway units are gated by
      `enable` alone, and a host opts into seeding where it declares this.
    '';

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

    chatplayground = {
      enable = lib.mkEnableOption ''
        the chatplayground-serve shim on 127.0.0.1:8799 — an OpenAI-compatible
        /v1 endpoint over the chatplayground web chat models, for the hermes
        `custom:chatplayground` provider
      '';

      port = lib.mkOption {
        type = lib.types.port;
        default = 8799;
        description = ''
          Loopback port to serve on. Deliberately not 8787: the *arr stack's
          readarr already listens there on this fleet.
        '';
      };

      toolsEmulate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Let the shim emulate OpenAI tool calls. The chatplayground wire format
          has no tool-calling support at all: the shim advertises the caller's
          tools in the prompt, parses a fenced JSON block out of the reply and
          returns it as `tool_calls`. Off is the honest chat-only mode.
        '';
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
  # whether the heavy agent suite (Chromium, qmd, agent-browser) is installed, and
  # host containers turn it off. Hermes has its own `enable`, set by
  # profiles/hermes.nix — coupling the two meant a cloud host had to install
  # the whole AI stack to get one agent.
  config = lib.mkIf config.programs.hermes-user.enable {
    # Persona files — symlinked to nixconfig source.
    # Runtime edits modify the repo directly (version controlled).
    home.activation.hermesPersonaSymlinks = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${lib.optionalString (!config.programs.hermes-user.persona) "exit 0"}

      run mkdir -p $HOME/.hermes
      run mkdir -p $HOME/.hermes/memories

      REPO_DIR="$HOME/Documents/nixconfig"
      if [ ! -d "$REPO_DIR/.git" ] && [ -d "$HOME/nixconfig/.git" ]; then
        REPO_DIR="$HOME/nixconfig"
      elif [ ! -d "$REPO_DIR/.git" ] && [ -e "${../../..}/flake.nix" ]; then
        # No checkout here: fall back to this flake's evaluated source, never a
        # machine-specific mount path.
        REPO_DIR="${../../..}"
      fi

      # Persona source of last resort: a store copy of
      # modules/user/ai/hermes-persona. A host with no nixconfig checkout
      # (delphi is a cloud VM) would otherwise seed NOTHING here, and the
      # repo-symlink branch would fail silently rather than loudly. Store
      # copies cannot version-control a runtime edit, which is the right trade
      # for a host that needs the persona, not the repo.
      PERSONA_STORE="${./hermes-persona}"

      # Personas are per-host. The activation script runs under `set -u`, so the
      # name has to come from somewhere: `uname -n` always exists, while nothing
      # exports HOST_NAME into an activation sandbox.
      HOST_NAME="$(uname -n | cut -d. -f1)"

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
      # ~/.hermes/.env is not created here any more. The old block symlinked
      # the sops-rendered file only when `.env` was ABSENT — a guard against
      # clobbering a hermes-managed token that produced the opposite failure: a
      # host that had once run an auth flow kept a plain `.env` that shadowed
      # every later rotation, while hermes reads exactly `$HERMES_HOME/.env`.
      # home.activation.hermesEnvSync below re-derives the file instead, and
      # keeps this host's non-rendered keys in ~/.hermes/.env.local.
      if [ ! -e "$HOME/.hermes/skills/agents-sync" ] && [ -d "$HOME/.agents/skills" ]; then
        run mkdir -p "$HOME/.hermes/skills"
        run ln -sf "$HOME/.agents/skills" "$HOME/.hermes/skills/agents-sync"
      fi
    '';

    # Derived credential file. Runs for every host that enables the program,
    # persona or not: hermes' own dotenv load (and therefore the gateway's
    # SimpleX/telegram keys, which the unit's EnvironmentFile does not carry)
    # reads this path regardless of which persona files were seeded.
    home.activation.hermesEnvSync = lib.hm.dag.entryAfter ["writeBoundary"] (
      let
        rendered =
          if config.programs.hermes-user.envFile != null
          then config.programs.hermes-user.envFile
          else "${config.home.homeDirectory}/.config/hermes/hermes.env";
      in
        lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          if [ -e ${lib.escapeShellArg rendered} ]; then
            run ${hermesEnvSync}/bin/hermes-env-sync
          else
            echo "hermes-env-sync: ${rendered} is not rendered on this host; ~/.hermes/.env left alone"
          fi
        ''
    );

    # Port of the old agent's handoff-restore discipline: hermes sessions
    # already capture scrollback; this helper restores the *operational*
    # state (persona pointers + latest archive savepoint) into a new chat.
    home.packages =
      [
        pkgs.llm-agents.hermes-agent
        hermesEnvSync
      ]
      # The client is installed whenever hermes-user is on, not only when the
      # shim is: `cpg chat` is the part that works with no service running.
      ++ lib.optional pkgs.stdenv.hostPlatform.isLinux chatplaygroundCli
      ++ [
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
    # Declared here, never via `hermes gateway install`: the generator bakes the
    # bare nix interpreter into ExecStart (no hermes_cli on sys.path, so it
    # crash-loops) and writes a non-store unit that aborts the switch at
    # `checkLinkTargets`. Its stop hooks are -prefixed cosmetics; KillMode=mixed
    # already tears the cgroup down. Checklist: `.agents/deploy/hosts/frieren.md`.
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

    # chatplayground-serve: loopback only. It holds a live web-chat session, so
    # it is never exposed beyond 127.0.0.1 — the hermes child agents on this host
    # are the only intended client.
    systemd.user.services.chatplayground-serve = lib.mkIf (config.programs.hermes-user.chatplayground.enable && pkgs.stdenv.hostPlatform.isLinux) {
      Unit = {
        Description = "chatplayground-serve — OpenAI-compatible shim over chatplayground web chat";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "simple";
        ExecStart = let
          c = config.programs.hermes-user.chatplayground;
        in
          "${chatplaygroundCli}/bin/chatplayground-go serve --addr 127.0.0.1:${toString c.port}"
          + lib.optionalString c.toolsEmulate " --tools-emulate";
        WorkingDirectory = config.home.homeDirectory;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "USER=${config.home.username}"
        ];
        # The auth file can be rewritten under it (a login, a rotation); the
        # process reads it per request, so a restart is not needed. Only a dead
        # port is: the unit is cheap, so let it restart rather than linger sick.
        Restart = "always";
        RestartSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = ["default.target"];
    };

    # The session lives in a browser cookie. When it dies, chat, image
    # generation and the advice lane die together, and nothing says so until a
    # request fails. One mint an hour keeps the 60-second token fresh and makes
    # a dead session a failed unit within the hour. It cannot resurrect one:
    # that needs `chatplayground-go login` in a real browser.
    systemd.user.services.chatplayground-refresh = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit = {
        Description = "chatplayground session keepalive — mint a Clerk token from the stored client cookie";
        # No auth file, no job: a host that never logged in is not a failure.
        ConditionPathExists = "${config.home.homeDirectory}/.chatplayground/auth.json";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "oneshot";
        # --json plus a non-zero exit on a dead session: that is the signal.
        ExecStart = "${chatplaygroundCli}/bin/cpg refresh --json";
        # The mint shells out to `node`. Inheriting the user manager's PATH made
        # this an hourly `node: executable file not found` the moment a profile
        # stopped carrying nodejs, which reads as a dead session and blocks
        # every `cpg` call. Pin the interpreter instead of hoping for PATH.
        path = [pkgs.nodejs];
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "USER=${config.home.username}"
        ];
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.chatplayground-refresh = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Hourly chatplayground session keepalive";
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5min";
        AccuracySec = "1min";
      };
      Install.WantedBy = ["timers.target"];
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
          # agy is the subagent a hermes turn shells out to. Home Manager's
          # sessionVariables never reach a systemd unit, so without these the
          # daemon calls the local agy with no model and may attempt a
          # self-update against the read-only store. The model comes from the
          # antigravity module, not a second literal.
          "AGY_CLI_DISABLE_AUTO_UPDATE=true"
          "GEMINI_MODEL=${
            # A null attr is not a missing one: attrByPath returns the value it
            # finds, so an unset model coerced here and failed the whole switch
            # (measured 2026-11-06 on delphi). Fall back rather than crash.
            let
              model = config.programs.antigravity-cli.defaultModel or null;
            in
              if model == null
              then "gemini-3.8-flash"
              else model
          }"
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
