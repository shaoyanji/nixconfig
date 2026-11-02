# NpgsqlRest over a full-text email archive: loopback API, declared PostgreSQL
# role, attachments on disk and an optional Google Drive mirror.
# docs/email-archive.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.emailArchive;

  # The rclone remote is state, not config, for the same reason the calendar's
  # OAuth token is (modules/calendar.nix): a token exists only after a consent
  # flow, so no declaration can carry it. Nix owns the unit and the condition;
  # the operator owns one file, and the remote's client id/secret are the pair
  # already in sops (`googleDrive/*`) rather than a second credential.
  rcloneConfig = "${cfg.stateDir}/rclone.conf";

  # Upstream publishes one self-contained NativeAOT binary per arch; it links
  # only libc/libm, so autoPatchelfHook is the whole packaging story.
  npgsqlrest = pkgs.stdenv.mkDerivation rec {
    pname = "npgsqlrest";
    version = "3.21.0";

    src = pkgs.fetchurl {
      url = "https://github.com/NpgsqlRest/NpgsqlRest/releases/download/v${version}/npgsqlrest-linux-arm64";
      hash = "sha256-KoClZh7kJ8Px/oPNAhGD9ps8nfNEGyC/5BPRgTNQ+uE=";
    };

    # NativeAOT links libc/libm statically and dlopens TLS and GSSAPI at run
    # time, so these never appear as NEEDED entries: they have to be on the
    # RPATH or the process aborts with "No usable version of libssl was found".
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    # `.out` explicitly: openssl's first output is `bin`, whose `lib/` is empty,
    # so naming the package alone yields an RPATH that cannot resolve libssl.
    runtimeDependencies = [
      pkgs.openssl.out
      pkgs.krb5
      pkgs.zlib
    ];
    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/npgsqlrest
    '';

    meta = {
      description = "Automatic REST API for PostgreSQL";
      homepage = "https://npgsqlrest.github.io";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
      mainProgram = "npgsqlrest";
    };
  };

  settings = {
    Urls = "http://127.0.0.1:${toString cfg.port}";
    Config = {
      ParseEnvironmentVariables = true;
      AddEnvironmentVariables = false;
      EnvFile = null;
      ValidateConfigKeys = "Warning";
    };
    ConnectionStrings.Default = "Host=127.0.0.1;Port=5432;Database=${cfg.database};Username=${cfg.userName};Password={!PGPASSWORD}";
    DataProtection = {
      Storage = "FileSystem";
      FileSystemPath = "${cfg.stateDir}/data-protection-keys";
    };
    HealthChecks = {
      Enabled = true;
      Path = "/health";
      IncludeDatabaseCheck = true;
    };
    NpgsqlRest = {
      # Defaults are `/api/emails` behind an authorization scheme nothing
      # configures, and `OnlyAnnotated` comments (so a plain table yields no
      # endpoints at all — the enum has no `All`, an invalid value falls back to
      # the default). One dedicated database, so every public object is
      # published, and the tailnet is the boundary.
      # `/api` is the default and the only prefix that produces reachable
      # routes: `""` builds paths with no leading slash and every request 404s.
      UrlPathPrefix = "/api";
      CommentsMode = "ParseAll";
      IncludeSchemas = ["public"];
      RequiresAuthorization = false;
      # NpgsqlRest removed table CRUD in 3.14 ("exposing raw tables directly is
      # a questionable engineering practice"): endpoints come from SQL files or
      # routines. These files are the API, and they are type-checked against the
      # schema at startup.
      SqlFileSource = {
        Enabled = true;
        FilePattern = "${./email-archive-endpoints}/*.sql";
        ErrorMode = "Exit";
      };
      UploadOptions = {
        Enabled = true;
        LogUploadEvent = true;
        UploadHandlers = {
          FileSystemPath = "${cfg.stateDir}/attachments";
          FileSystemUseUniqueFileName = true;
          FileSystemCreatePathIfNotExists = true;
        };
      };
    };
  };

  appSettings = (pkgs.formats.json {}).generate "npgsqlrest-appsettings.json" settings;

  dbInit = pkgs.writeShellScript "email-archive-db-init" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [config.services.postgresql.finalPackage pkgs.coreutils]}:$PATH"

    password="$(cat "$CREDENTIALS_DIRECTORY/db-password")"

    # The role's password is not something ensureUsers can set, and it has to be
    # re-asserted on every activation so a rotated sops value lands. Ownership
    # is asserted here too: `ensureDBOwnership` only accepts a database named
    # after the role, and this one is not.
    psql -v ON_ERROR_STOP=1 -v pw="$password" -d postgres <<'SQL'
    ALTER ROLE ${cfg.userName} WITH LOGIN PASSWORD :'pw';
    ALTER DATABASE ${cfg.database} OWNER TO ${cfg.userName};
    SQL

    # Connect the way the app connects, so a wrong pg_hba rule fails here rather
    # than as a pod that starts and answers 500 for every endpoint.
    PGPASSWORD="$password" psql -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U ${cfg.userName} -d ${cfg.database} -f ${./email-archive.sql}
  '';
in {
  options.services.emailArchive = {
    enable = lib.mkEnableOption "the NpgsqlRest email archive";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Loopback port the API listens on; the tailnet front is a `tailscale serve` mount.";
    };

    database = lib.mkOption {
      type = lib.types.str;
      default = "email_archive";
      description = "Database holding the archive.";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      default = "npgsqlrest";
      description = "PostgreSQL role and system user the API runs as. Owns the database.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/npgsqlrest";
      description = "Working directory: appsettings, data-protection keys and the attachment tree.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = npgsqlrest;
      description = "NpgsqlRest binary.";
    };

    gdrive = {
      enable = lib.mkEnableOption "the hourly attachment mirror to Google Drive";

      remote = lib.mkOption {
        type = lib.types.str;
        default = "gdrive-email";
        description = "rclone remote name, defined by the operator in the service user's rclone.conf.";
      };

      folder = lib.mkOption {
        type = lib.types.str;
        default = "email-archive/attachments";
        description = "Destination path inside the remote.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      ensureDatabases = [cfg.database];
      ensureUsers = [
        {
          name = cfg.userName;
        }
      ];
      # Local socket stays trust so `sudo -u postgres psql` works; the app's TCP
      # connection is the only authenticated path, and it is loopback-only.
      authentication = ''
        local all all trust
        host  all all 127.0.0.1/32 scram-sha-256
        host  all all ::1/128      scram-sha-256
      '';
    };

    sops.secrets."email-archive/db-password" = {
      sopsFile = ../secrets.yaml;
      mode = "0400";
    };

    sops.templates."npgsqlrest.env" = {
      content = ''
        PGPASSWORD=${config.sops.placeholder."email-archive/db-password"}
      '';
      owner = cfg.userName;
      mode = "0400";
    };

    users.users.${cfg.userName} = {
      isSystemUser = true;
      group = cfg.userName;
      home = cfg.stateDir;
    };
    users.groups.${cfg.userName} = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.userName} ${cfg.userName} -"
      "d ${cfg.stateDir}/attachments 0750 ${cfg.userName} ${cfg.userName} -"
      "d ${cfg.stateDir}/data-protection-keys 0700 ${cfg.userName} ${cfg.userName} -"
      # `L+` because the target carries a store hash: a rebuild must retarget it.
      "L+ ${cfg.stateDir}/appsettings.json - - - - ${appSettings}"
    ];

    systemd.services.email-archive-db-init = {
      description = "Apply the email archive schema and role password";
      wantedBy = ["multi-user.target"];
      # ensureUsers/ensureDatabases run in postgresql-setup, which is ordered
      # *after* the server: waiting on postgresql.service alone races the role.
      after = ["postgresql-setup.service"];
      requires = ["postgresql-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        LoadCredential = "db-password:${config.sops.secrets."email-archive/db-password".path}";
        ExecStart = dbInit;
      };
    };

    systemd.services.npgsqlrest = {
      description = "NpgsqlRest API for the email archive";
      unitConfig.X-Fleet-Role = "daemon";
      wantedBy = ["multi-user.target"];
      after = [
        "postgresql.service"
        "email-archive-db-init.service"
        "network.target"
      ];
      requires = ["email-archive-db-init.service"];
      # The settings live behind a symlink, which systemd cannot diff: without
      # this a config change lands on disk and never reaches the process.
      restartTriggers = [appSettings];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/npgsqlrest";
        User = cfg.userName;
        Group = cfg.userName;
        WorkingDirectory = cfg.stateDir;
        StateDirectory = "npgsqlrest";
        EnvironmentFile = [config.sops.templates."npgsqlrest.env".path];
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      };
    };

    # One-way by design: Drive holds a mirror, never the source of truth. The
    # unit is skipped — not failed — on a host with no remote yet, so the timer
    # ticks from the first boot and the mirror starts the moment a token exists.
    systemd.services.email-archive-gdrive-sync = lib.mkIf cfg.gdrive.enable {
      description = "Mirror email attachments to Google Drive";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.ConditionPathExists = rcloneConfig;
      serviceConfig = {
        Type = "oneshot";
        User = cfg.userName;
        Group = cfg.userName;
        ExecStart = "${pkgs.rclone}/bin/rclone --config ${rcloneConfig} sync ${cfg.stateDir}/attachments ${cfg.gdrive.remote}:${cfg.gdrive.folder} --create-empty-src-dirs --log-level INFO --stats-one-line";
      };
    };

    systemd.timers.email-archive-gdrive-sync = lib.mkIf cfg.gdrive.enable {
      description = "Hourly email attachment mirror";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
}
