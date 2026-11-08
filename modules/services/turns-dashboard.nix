# The agent-turn log as a reading surface: one SSE-pushed panel per turn, each
# able to hand a prompt to Hermes. The shim holds the store contract; this is a
# reader with its own token.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.turnsDashboard;

  package = pkgs.buildGoModule {
    pname = "turns-dashboard";
    version = "0.1.0";
    src = ./turns-dashboard;
    # Standard library only: the SSE wire format is nine lines and a dependency
    # to write it would be a dependency to audit.
    vendorHash = null;
    meta = {
      description = "Live reading surface over the agent-turn store";
      mainProgram = "turns-dashboard";
    };
  };

  # No client library: app.js reads the same text frames main.go writes, so the
  # page has no dependency to pin, mirror or keep in step with the server.
  site = pkgs.runCommand "turns-dashboard-site" {} ''
    mkdir -p $out
    cp ${./turns-dashboard/web/index.html} $out/index.html
    cp ${./turns-dashboard/web/style.css} $out/style.css
    cp ${./turns-dashboard/web/app.js} $out/app.js
  '';

  home = config.users.users.${cfg.user}.home;

  # One unit shape for both readers: the tailnet one can prompt, the public one
  # cannot. Sharing it keeps the hardening, the token file and the site from
  # drifting between two surfaces that are meant to differ in one flag.
  unit = {
    port,
    description,
    readOnly ? false,
    extraArgs ? [],
  }: {
    description = description;
    wantedBy = ["multi-user.target"];
    unitConfig.X-Fleet-Role = "daemon";
    after = ["agent-turns-shim.service" "network.target"];
    wants = ["agent-turns-shim.service"];
    serviceConfig = {
      Type = "simple";
      User = cfg.user;
      Group = "users";
      StateDirectory = cfg.stateDirectory;
      WorkingDirectory = "%S/${cfg.stateDirectory}";
      ExecStart = lib.concatStringsSep " " (
        [
          "${lib.getExe package}"
          "-addr"
          "127.0.0.1:${toString port}"
          "-shim"
          "http://127.0.0.1:${toString config.services.agentTurns.port}"
          "-token-file"
          config.sops.secrets.${cfg.tokenSecret}.path
          "-prompt-log"
          "/var/lib/${cfg.stateDirectory}/prompts.jsonl"
          "-site"
          site
          "-limit"
          "120"
        ]
        ++ lib.optional readOnly "-read-only"
        ++ extraArgs
      );
      Environment = [
        "HOME=${home}"
        # Hermes shells out to its subagents from PATH, and the wrapper
        # directory is where the setuid sudo lives.
        "PATH=/run/wrappers/bin:${home}/.nix-profile/bin:/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = 3;

      # Not `NoNewPrivileges`: a prompt is an operator turn, and Hermes'
      # subagents escalate through the setuid sudo wrapper.
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = ["/var/lib/${cfg.stateDirectory}"];
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      MemoryMax = "512M";
    };
  };
in {
  options.services.turnsDashboard = {
    enable = lib.mkEnableOption "the agent-turn dashboard (live SSE log with per-turn hermes prompts)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8099;
      description = ''
        Loopback port the dashboard listens on. It is published only through
        `services.servicePortal.mounts`, which is the single declaration of what
        is reachable on the tailnet.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "devji";
      description = ''
        The account the service runs as. It is the login user on purpose: a
        Hermes prompt is the operator's own turn, and Hermes reads its
        credentials (and writes its sessions) from that home. It also means the
        process can read its own token secret at 0400.
      '';
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "agent-turns-token-dashboard";
      description = ''
        sops secret holding this service's bearer token for the agent-turn shim.
        It must also be listed in `services.agentTurns.additionalTokens` with
        `owner = "${cfg.user}"`, or the shim refuses the read.
      '';
    };

    hermesPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.llm-agents.hermes-agent;
      description = ''
        Hermes binary a panel prompt runs through (`hermes -z <prompt>`). Null
        leaves the prompt form in place but answers "not configured", so the log
        still reads on a host without an agent.
      '';
    };

    publicPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = ''
        A second, prompt-less reader on loopback, for an exposure outside the
        tailnet. It runs with `-read-only` and no Hermes, so the public page has
        no prompt form and `POST /api/prompt` answers 403: whatever mount sits in
        front of this port can publish the log and nothing else.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "turns-dashboard";
      description = "systemd StateDirectory holding the append-only prompt log.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.agentTurns.enable;
        message = "services.turnsDashboard reads the turn store: enable services.agentTurns on this host.";
      }
    ];

    systemd.services.turns-dashboard = unit {
      port = cfg.port;
      description = "Live agent-turn dashboard with per-turn Hermes prompts";
      extraArgs =
        ["-hermes-home" home]
        ++ lib.optional (cfg.hermesPackage != null) "-hermes ${lib.getExe cfg.hermesPackage}";
    };

    # The public mount's reader: same store, same page, no prompt surface. Not
    # `-hermes ""` on the tailnet unit and not a 403 in front of it — a separate
    # process means the public page cannot prompt even if the proxy is later
    # edited by someone who has not read this file.
    systemd.services.turns-dashboard-public = lib.mkIf (cfg.publicPort != null) (unit {
      port = cfg.publicPort;
      description = "Read-only agent-turn dashboard for a non-tailnet mount";
      readOnly = true;
    });
  };
}
