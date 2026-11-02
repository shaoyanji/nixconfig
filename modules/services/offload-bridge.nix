# The shelter side of a service offload: state that lives on a cloud host still
# gets a copy the household can reach, and the ingest door the humans already
# use keeps pointing somewhere.
#
# The premise is the `open-frieren-offload` note in AGENTS.nix: a service can
# leave the NAS, but "leave" must mean "the NAS is now a shelter", not "the only
# copy is in a datacentre". Three guarantees, one declaration:
#
#   - `sets`   — every tree is mirrored to `<root>/<set>/` on the shelter host
#                nightly, with each SQLite database replaced by a consistent
#                `sqlite3 .backup` copy (a WAL-mode database copied file-by-file
#                restores into a service that starts and then answers wrong).
#   - `ingest` — a directory the service no longer hosts (the scanner's drop
#                folder) is pulled here on a timer, so moving the service does
#                not silently break the way documents arrive.
#   - `migrate` — the units to stop on each side, and the assertion that proves
#                the cutover, so the move is one repeatable script instead of a
#                remembered sequence.
#
# docs/service-offload.md is the procedure; scripts/task/offload-{bridge,migrate}.sh
# are the two verbs.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.offloadBridge;
  user = import ../global/user.nix;

  configFile = (pkgs.formats.json {}).generate "offload-bridge.json" {
    shelter = {
      inherit (cfg) host root keyFile knownHosts;
    };
    sets =
      lib.mapAttrs (_: s: {
        inherit (s) path sqlite;
      })
      cfg.sets;
    inherit (cfg) ingest;
    migrate =
      lib.mapAttrs (_: m: {
        inherit (m) source stopSource stopTarget countSql healthUrl;
      })
      cfg.migrate;
  };

  bridge = pkgs.writeShellScript "offload-bridge" ''
    exec ${pkgs.bash}/bin/bash ${../../scripts/task/offload-bridge.sh} "$@"
  '';

  unitPath = [
    pkgs.rsync
    pkgs.openssh
    pkgs.sqlite
    pkgs.jq
    pkgs.findutils
    pkgs.coreutils
    pkgs.bash
    pkgs.curl
  ];
in {
  options.services.offloadBridge = {
    enable = lib.mkEnableOption "the shelter bridge for services offloaded from the NAS";

    host = lib.mkOption {
      type = lib.types.str;
      default = "${user.name}@frieren";
      description = "SSH target of the host that shelters this host's state.";
    };

    root = lib.mkOption {
      type = lib.types.str;
      default = "/srv/backup/offload";
      description = ''
        Directory on the shelter host, one subdirectory per set. It is mirrored,
        so it must belong to this bridge alone; the shelter's own restic snapshot
        is what versions it.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/${user.name}/.ssh/id_ed25519";
      description = "Key the push and the migration authenticate with (the units run as root).";
    };

    knownHosts = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/offload-bridge/known_hosts";
      description = "known_hosts file, so the first contact pins the host instead of prompting.";
    };

    startAt = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 03:10:00";
      description = ''
        Nightly push. After delphi's agent-turn export (03:05) and before the
        shelter's restic snapshots (03:28/03:30), which are what actually carry
        the copy off the shelter host.
      '';
    };

    ingestEvery = lib.mkOption {
      type = lib.types.str;
      default = "*:0/10";
      description = "OnCalendar for the ingest pull; the scanner's drop folder is polled, not pushed.";
    };

    sets = lib.mkOption {
      default = {};
      description = ''
        Trees to shelter, keyed by the name the shelter uses as its directory.
        `sqlite` lists database files relative to `path`; each is mirrored as a
        consistent snapshot instead of as bytes.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path of the tree this host owns.";
          };
          sqlite = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Database files inside `path`, relative to it.";
          };
        };
      });
    };

    ingest = lib.mkOption {
      default = {};
      description = ''
        Directories to pull here on a timer, keyed by name: `from` is an rsync
        source on the shelter host (`user@host:/path/`), `to` a local directory.
        Files are moved, not copied — the pull is the consumer of that door.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          from = lib.mkOption {type = lib.types.str;};
          to = lib.mkOption {type = lib.types.str;};
        };
      });
    };

    migrate = lib.mkOption {
      default = {};
      description = ''
        Per-set cutover facts, merged with `sets` by
        `scripts/task/offload-migrate.sh`: which units to stop on each side, the
        row count that proves both sides hold the same archive, and the URL that
        proves the service came back.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            default = cfg.host;
            description = "Host the state currently lives on.";
          };
          stopSource = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Units to stop on the source before the copy.";
          };
          stopTarget = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Units to stop here, then start again after verification.";
          };
          countSql = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "SQL whose single value must match on both sides.";
          };
          healthUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "URL polled after the restart; the migration fails if it never answers.";
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    # One readable config: the units read it, and so does a hand-run migration.
    environment.etc."offload-bridge/config.json".source = configFile;

    systemd.tmpfiles.rules = [
      "d /var/lib/offload-bridge 0700 root root -"
      "d /var/lib/offload-migrate 0700 root root -"
    ];

    systemd.services.offload-bridge-push = {
      description = "Mirror this host's offloaded service state to the shelter";
      # Root because the trees are 0700 to service users. No ProtectHome: the
      # unit authenticates with a key in a home directory.
      path = unitPath;
      serviceConfig = {
        Type = "oneshot";
        Environment = "BRIDGE_CONFIG=/etc/offload-bridge/config.json";
        ExecStart = "${bridge} push";
      };
    };

    systemd.timers.offload-bridge-push = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.startAt;
        Persistent = true;
        RandomizedDelaySec = "120s";
      };
    };

    systemd.services.offload-bridge-ingest = lib.mkIf (cfg.ingest != {}) {
      description = "Pull the ingest directory this host's service no longer hosts";
      path = unitPath;
      serviceConfig = {
        Type = "oneshot";
        Environment = "BRIDGE_CONFIG=/etc/offload-bridge/config.json";
        ExecStart = "${bridge} ingest";
      };
    };

    systemd.timers.offload-bridge-ingest = lib.mkIf (cfg.ingest != {}) {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.ingestEvery;
        Persistent = true;
      };
    };
  };
}
