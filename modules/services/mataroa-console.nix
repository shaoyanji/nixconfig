# A tailnet console over a mataroa blog: the posts are files on this host, and
# the blog is a deployment target. The API is not the source of truth, so
# "what is on my blog?" is a `grep`, a `diff` and a `git log`. docs/mataroa-console.md
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mataroaConsole;

  # Posts, their git history, and nothing else. The store holds the program; the
  # state directory holds the writing, which is the thing worth backing up.
  stateDir = "/var/lib/${cfg.stateDirectory}";

  # LoadCredential, not a path in the environment: the token is read from
  # $CREDENTIALS_DIRECTORY, sent as a bearer header, and never rendered, logged
  # or written into a post file.
  tokenPath = config.sops.secrets.${cfg.tokenSecret}.path;

  origin = "https://${cfg.tailnetHost}:${toString cfg.tailnetPort}";

  # The server is Go since 2026-11-07: one static binary, no interpreter in the
  # closure, and the reader of the posts is the same program that writes them.
  # Measured against the Python it replaced in tools/turns-runtime/README.md.
  goPackage = pkgs.buildGoModule {
    pname = "mataroa-console";
    version = "0.1.0";
    src = ./mataroa-console/server;
    vendorHash = null;
    env.CGO_ENABLED = "0";
    meta.mainProgram = "mataroa-console";
  };
in {
  options.services.mataroaConsole = {
    enable = lib.mkEnableOption "the mataroa console, served on this host's tailnet";

    port = lib.mkOption {
      type = lib.types.port;
      # 8093 is agent-turns and 8094 is media-relay on delphi; 8095 measured free
      # 2026-11-05.
      default = 8095;
      description = ''
        Loopback port the console listens on. The tailnet mount proxies it; this
        service never binds a public or tailnet address itself.
      '';
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        MagicDNS name the console is served under. A write is accepted only when
        the browser's Origin is this name and port: a page somewhere else can
        send a cross-site request to a tailnet address, and the origin check is
        what makes that request not a write. Required.
      '';
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      # 8453 is zettel-graph; the mounts on delphi are a sequential namespace.
      default = 8454;
      description = ''
        The `tailscale serve` port the mount binds. It is not the loopback port:
        the browser's Origin is `https://<tailnetHost>:<this>`, and the portal
        mount reads this option so the two cannot disagree.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "mataroa-console";
      description = "systemd StateDirectory holding `posts/` and its git history.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mataroa-console";
      description = "System user that owns the posts, the service and its commits.";
    };

    blogUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Public blog address, shown in the console's header.";
    };

    apiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://mataroa.blog/api";
      description = "API root; overridable so a test can point at a local stub.";
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "mataroa/api/key";
      description = "sops secret holding the mataroa bearer token.";
    };

    tokenSopsKey = lib.mkOption {
      type = lib.types.str;
      default = "mataroa_api_key";
      description = ''
        Key in `modules/secrets.yaml` the token secret reads. The tracked fleet
        file, not `modules/secrets/apikeys.yaml`: that directory is a submodule
        outside the flake, so a `sopsFile` pointing there is a path that does not
        exist in the store.

        One flat segment, because sops-nix resolves `key` as a path: a key
        written as `mataroa/api/key` makes the installer look for a top-level
        `mataroa` and fail with "the key 'mataroa' cannot be found", which is a
        build failure before activation, not a runtime one.
      '';
    };

    commit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Commit every write in the state directory, so `git log` is the edit trail.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.mataroaConsole: `tailnetHost` is required — a write without an expected origin is a write any page in the browser may send.";
      }
      {
        assertion = cfg.port != cfg.tailnetPort;
        message = "services.mataroaConsole: the loopback port and the tailnet mount port must differ; one is proxied to the other.";
      }
      {
        assertion = cfg.port != 80 && cfg.port != 443;
        message = "services.mataroaConsole: 80 and 443 belong to nginx on this host.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      # No colon: NixOS writes this into the passwd GECOS field, which the
      # `users.users.*.description` type refuses to let a colon through.
      description = "Mataroa console, the blog's posts as files";
    };

    sops.secrets.${cfg.tokenSecret} = {
      sopsFile = ../../modules/secrets.yaml;
      key = cfg.tokenSopsKey;
      owner = cfg.user;
      group = cfg.user;
      mode = "0400";
    };

    systemd.services.mataroa-console = {
      description = "Mataroa console (loopback; ledger, edit and publish)";
      wantedBy = ["multi-user.target"];
      # Wants, not Requires: without the network the ledger still renders, and a
      # file edit needs no API at all.
      wants = ["network-online.target"];
      after = ["network-online.target"];
      unitConfig = {
        X-Fleet-Role = "daemon";
        StartLimitIntervalSec = 0;
      };
      # A unit gets no login PATH and `path` is a service option, not a
      # serviceConfig directive — written inside serviceConfig it is dropped and
      # the binary dies at exec with status 127. The server shells out to git for
      # its commits and to comrak to render markdown.
      path = [pkgs.git pkgs.comrak pkgs.coreutils pkgs.bash];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0750";
        LoadCredential = "mataroa-token:${tokenPath}";
        ExecStart = lib.concatStringsSep " " ([
            "${goPackage}/bin/mataroa-console"
            "--state ${stateDir}"
            "--port ${toString cfg.port}"
            "--origin ${origin}"
            "--api-base ${cfg.apiBase}"
            "--comrak ${pkgs.comrak}/bin/comrak"
          ]
          ++ lib.optional (cfg.blogUrl != "") "--blog-url ${cfg.blogUrl}"
          ++ lib.optional (!cfg.commit) "--no-commit");
        Environment = ["HOME=${stateDir}"];
        Restart = "always";
        RestartSec = 5;
        RestartSteps = 10;
        RestartMaxDelaySec = "30s";
        TimeoutStopSec = 20;
        UMask = "0027";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [stateDir];
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        MemoryMax = "256M";
      };
    };
  };
}
