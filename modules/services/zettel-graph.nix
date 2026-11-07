# Zettel web: the private reader plus an export of the private vault, served on
# this host's tailnet, with write and publish going through the vault's own
# scripts. docs/zettel-graph.md
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.zettelGraph;

  # The state directory is the working tree of both checkouts and the tree the
  # page is served from; nothing about the vault lives in the store, because a
  # private repo is not something a binary cache may hold.
  stateDir = "/var/lib/${cfg.stateDirectory}";
  frontendDir = "${stateDir}/frontend";
  vaultDir = "${stateDir}/vault";
  wwwDir = "${stateDir}/www";

  # pyyaml is the exporter's one import (scripts/check_links.py) and the
  # publisher's config reader. typst is what publish_md.py shells out to.
  python = pkgs.python3.withPackages (ps: [ps.pyyaml]);

  # The reader is a Go service and the vault's scripts stay the vault's: one
  # static binary serves the page and shells out to `export_graph.py`,
  # `create_note.py` and `publish_md.py` under the interpreter above. Nothing
  # here parses markdown — a second copy of those rules is how the page and the
  # gate start disagreeing.
  serverPackage = pkgs.buildGoModule {
    pname = "zettel-graph";
    version = "0.1.0";
    src = ./zettel-graph/server;
    # Standard library only.
    vendorHash = null;
    meta = {
      description = "Zettel reader and vault write surface";
      mainProgram = "zettel-graph";
    };
  };

  # `fetch --quiet origin <ref>` creates FETCH_HEAD, so the ref may be a branch
  # or a commit; a pinned sha is how a reader regression gets held back without
  # editing this module again.
  sync = pkgs.replaceVarsWith {
    src = ../scripts/zettel-graph-sync.sh;
    isExecutable = true;
    replacements = {
      inherit stateDir frontendDir vaultDir wwwDir python;
      vaultUrl = "https://github.com/${cfg.vault.repo}.git";
      frontendUrl = "https://github.com/${cfg.frontend.repo}.git";
      vaultRef = cfg.vault.ref;
      frontendRef = cfg.frontend.ref;
    };
  };

  # LoadCredential, not a path in the environment: the module conventions say a
  # secret is never on a command line, and the sync script reads it from
  # $CREDENTIALS_DIRECTORY.
  tokenSecret = config.sops.secrets.${cfg.githubTokenSecret}.path;
in {
  options.services.zettelGraph = {
    enable = lib.mkEnableOption "the zettel reader and vault export, served on this host's tailnet";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = ''
        Loopback port the reader listens on. The tailnet mount proxies it; this
        service never binds a public or tailnet address itself.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "zettel-graph";
      description = "systemd StateDirectory holding both checkouts and the served tree.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "zettel-graph";
      description = "System user that owns the checkouts, the service and its commits.";
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        MagicDNS name the page is served under. A write is accepted only when the
        browser's Origin is this name and port: a public page can send a
        cross-site request to a tailnet address, and the origin check is what
        makes that request not a write.
      '';
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      # 8452 is taken by another project on this host; the mounts are a
      # sequential namespace and this one starts at 8453.
      default = 8453;
      description = ''
        The `tailscale serve` port the mount binds. It is not the loopback port:
        the browser's Origin is `https://<tailnetHost>:<this>`, and the portal
        mount reads this option so the two cannot disagree.
      '';
    };

    vault = {
      repo = lib.mkOption {
        type = lib.types.str;
        default = "shaoyanji/Obsidian-Git-Sync";
        description = "`owner/name` of the private vault repository.";
      };
      ref = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Branch a write is pushed to, and the branch the sync merges.";
      };
    };

    frontend = {
      repo = lib.mkOption {
        type = lib.types.str;
        default = "shaoyanji/zettel-graph";
        description = "`owner/name` of the private reader repository.";
      };
      ref = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Branch or commit of the reader to serve; a sha pins a bad release out.";
      };
    };

    githubTokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "zettel-graph/github-token";
      description = "sops secret holding a token that can read both private repos.";
    };

    githubTokenKey = lib.mkOption {
      type = lib.types.str;
      default = "ghsudo";
      description = ''
        Key in `modules/secrets.yaml` the token secret reads. It is the fleet's
        `gh` token (`ghsudo`), not `modules/secrets/apikeys.yaml#GITHUB`: that
        directory is a submodule outside the flake, and this host builds from a
        GitHub tarball that carries only its gitlink.
      '';
    };

    commit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Commit a page write in the vault checkout, so `git log` is the edit trail.";
    };

    push = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Push a page write to `vault.ref`. Off means edits stay on this host until
        the sync timer's push, which is the same commit arriving later.
      '';
    };

    publish = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow `/api/publish` to render PDFs through the vault's `publish_md.py`.";
    };

    syncInterval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = "systemd calendar for the fetch-and-export run.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.zettelGraph: `tailnetHost` is required — a write without an expected origin is a write any page in the browser may send.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Zettel reader and vault checkout";
    };

    sops.secrets.${cfg.githubTokenSecret} = {
      sopsFile = ../../modules/secrets.yaml;
      key = cfg.githubTokenKey;
      owner = cfg.user;
      group = cfg.user;
      mode = "0400";
      restartUnits = ["zettel-graph-sync.service"];
    };

    systemd.services.zettel-graph-sync = {
      description = "Fetch the private vault and reader, then rebuild the served tree";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      # A unit gets no login PATH and `path` is a service option, not a
      # serviceConfig directive — written inside serviceConfig it is dropped and
      # the script dies at exec with status 127. The script's shebang is
      # `#!/usr/bin/env bash` and its body runs git and coreutils.
      path = [pkgs.bash pkgs.git pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0750";
        LoadCredential = "github-token:${tokenSecret}";
        ExecStart = sync;
        # A cold clone of the vault is smaller than this by two orders of
        # magnitude; the timeout exists so a hung fetch cannot hold boot.
        TimeoutStartSec = 300;
        UMask = "0027";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [stateDir];
        NoNewPrivileges = true;
        MemoryMax = "1G";
      };
    };

    systemd.timers.zettel-graph-sync = {
      description = "Keep the served zettel tree within a quarter hour of both repos";
      wantedBy = ["timers.target"];
      timerConfig = {
        # One schedule, not three: an early run after boot, then the calendar.
        # `OnUnitActiveSec` alongside `OnCalendar` fires at activation + 15 min
        # as well, which puts half the runs off the quarter hour for no gain.
        OnBootSec = "2min";
        OnCalendar = cfg.syncInterval;
        # False on purpose: this is a cache of two remotes, and a run missed
        # while the host was off is not owed.
        Persistent = false;
        RandomizedDelaySec = "30s";
      };
    };

    systemd.services.zettel-graph = {
      description = "Zettel reader and vault exporter (loopback; write and publish)";
      wantedBy = ["multi-user.target"];
      # Wants, not Requires: a failed fetch must not take down a page that can
      # still serve the last good graph.json.
      wants = ["zettel-graph-sync.service"];
      after = ["zettel-graph-sync.service"];
      unitConfig = {
        X-Fleet-Role = "daemon";
        StartLimitIntervalSec = 0;
      };
      # The publisher is a subprocess of this unit: typst compiles the PDF, and
      # git both commits and pushes what the page wrote. Set on the service, not
      # in serviceConfig, or it is silently dropped.
      path = [python pkgs.typst pkgs.git pkgs.coreutils pkgs.bash];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0750";
        LoadCredential = "github-token:${tokenSecret}";
        ExecStart = lib.concatStringsSep " " ([
            "${lib.getExe serverPackage}"
            "--www ${wwwDir}"
            "--vault ${vaultDir}"
            "--port ${toString cfg.port}"
            "--origin https://${cfg.tailnetHost}:${toString cfg.tailnetPort}"
            "--ref ${cfg.vault.ref}"
            "--python ${python}/bin/python3"
          ]
          ++ lib.optional cfg.commit "--commit"
          ++ lib.optional cfg.push "--push"
          ++ lib.optional cfg.publish "--publish");
        Environment = [
          "HOME=${stateDir}"
          "PYTHONDONTWRITEBYTECODE=1"
        ];
        Restart = "always";
        RestartSec = 5;
        RestartSteps = 10;
        RestartMaxDelaySec = "30s";
        TimeoutStopSec = 20;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [stateDir];
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        MemoryMax = "1G";
      };
    };
  };
}
