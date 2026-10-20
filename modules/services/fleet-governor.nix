# Declarative Consolidated Fleet Governor & 3-Tier Escalation Router
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../global/user.nix;
  cfg = config.services.fleetGovernor;

  # Declarative rules configuration serialized into Nix store JSON
  rulesConfig = pkgs.writeText "fleet-governor-rules.json" (builtins.toJSON {
    s0 = {
      kiwix = {
        enabled = cfg.rules.s0Deterministic.kiwix.enable;
        endpoint = cfg.rules.s0Deterministic.kiwix.endpoint;
        service = cfg.rules.s0Deterministic.kiwix.service;
      };
      harmonia = {
        enabled = cfg.rules.s0Deterministic.harmonia.enable;
        endpoint = cfg.rules.s0Deterministic.harmonia.endpoint;
        service = cfg.rules.s0Deterministic.harmonia.service;
      };
      paperless_ghosts = {
        enabled = cfg.rules.s0Deterministic.paperlessGhosts.enable;
        consume_dir = cfg.rules.s0Deterministic.paperlessGhosts.consumeDir;
        quarantine_age_sec = cfg.rules.s0Deterministic.paperlessGhosts.quarantineAgeSec;
      };
      sqlite_idle = {
        enabled = cfg.rules.s0Deterministic.sqliteIdleWal.enable;
        wal_threshold_kb = cfg.rules.s0Deterministic.sqliteIdleWal.walThresholdKb;
      };
      btrfs_integrity = {
        enabled = cfg.rules.s0Deterministic.btrfsCleanCheck.enable;
        mount = cfg.rules.s0Deterministic.btrfsCleanCheck.mountPoint;
      };
      thermal_headroom = {
        enabled = cfg.rules.s0Deterministic.thermalNominal.enable;
        threshold_c = cfg.rules.s0Deterministic.thermalNominal.thresholdC;
      };
      memory_psi = {
        enabled = cfg.rules.s0Deterministic.memoryPsiNominal.enable;
        psi_threshold = cfg.rules.s0Deterministic.memoryPsiNominal.psiThreshold;
      };
    };
    s1 = {
      thermal_vs_stream = {
        enabled = cfg.rules.s1Contextual.thermalVsMedia.enable;
        protected_services = cfg.rules.s1Contextual.thermalVsMedia.protectedServices;
        max_emergency_temp_c = cfg.rules.s1Contextual.thermalVsMedia.maxEmergencyTempC;
      };
      memory_vs_cache = {
        enabled = cfg.rules.s1Contextual.memoryVsCache.enable;
        prefer_zram = cfg.rules.s1Contextual.memoryVsCache.preferZram;
      };
      wal_vs_concurrency = {
        enabled = cfg.rules.s1Contextual.walVsConcurrency.enable;
        bloat_threshold_kb = cfg.rules.s1Contextual.walVsConcurrency.bloatThresholdKb;
      };
    };
    s2 = {
      btrfs_corruption = {
        enabled = cfg.rules.s2Investigative.btrfsCorruption.enable;
        auto_snapshot = cfg.rules.s2Investigative.btrfsCorruption.autoSnapshot;
        stop_services = cfg.rules.s2Investigative.btrfsCorruption.stopServices;
      };
      flake_transitive_cve = {
        enabled = cfg.rules.s2Investigative.flakeTransitiveCve.enable;
        flake_path = cfg.rules.s2Investigative.flakeTransitiveCve.flakePath;
      };
      consensus_anomaly = {
        enabled = cfg.rules.s2Investigative.consensusAnomaly.enable;
        emit_handoff = cfg.rules.s2Investigative.consensusAnomaly.emitHandoff;
      };
    };
    settings = {
      auto_repair = cfg.autoRepair;
      allow_s2 = cfg.allowSystem2;
    };
  });
in {
  options.services.fleetGovernor = {
    enable = lib.mkEnableOption "Consolidated Fleet Governor with 3-Tier Escalation Router (S0/S1/S2)";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "Systemd OnCalendar expression for governor sweep (e.g. hourly, strictly avoids 03:00-05:30 backup window).";
    };

    autoRepair = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to execute automated fixes approved at S0/S1/S2 tiers.";
    };

    allowSystem2 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to allow fallback to System 2 Nemotron when escalated (default false to conserve quota).";
    };

    rules = {
      s0Deterministic = {
        kiwix = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 HTTP probe & restart for Kiwix offline knowledge.";
          };
          endpoint = lib.mkOption {
            type = lib.types.str;
            # Same source as the server's own option — no second copy of :8088.
            default = "http://127.0.0.1:${toString config.services.kiwix-serve.port}";
            description = "Kiwix endpoint URL.";
          };
          service = lib.mkOption {
            type = lib.types.str;
            default = "kiwix-serve";
            description = "Target systemd service.";
          };
        };
        harmonia = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 HTTP probe for Harmonia binary cache.";
          };
          endpoint = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:5000/nix-cache-info";
            description = "Harmonia cache endpoint URL.";
          };
          service = lib.mkOption {
            type = lib.types.str;
            default = "harmonia";
            description = "Target systemd service.";
          };
        };
        paperlessGhosts = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 quarantine for stalled 0-byte ghost PDFs.";
          };
          consumeDir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/paperless/consume";
            description = "Paperless consume directory.";
          };
          quarantineAgeSec = lib.mkOption {
            type = lib.types.int;
            default = 1800;
            description = "Age in seconds to consider stalled.";
          };
        };
        sqliteIdleWal = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 WAL checkpoint when database is idle.";
          };
          walThresholdKb = lib.mkOption {
            type = lib.types.int;
            default = 1024;
            description = "WAL bloat threshold in KB.";
          };
        };
        btrfsCleanCheck = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 clean check on Btrfs device error counts.";
          };
          mountPoint = lib.mkOption {
            type = lib.types.str;
            default = "/Volumes/data";
            description = "Btrfs filesystem mount point.";
          };
        };
        thermalNominal = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 thermal headroom check.";
          };
          thresholdC = lib.mkOption {
            type = lib.types.float;
            default = 76.0;
            description = "Package temperature threshold in Celsius.";
          };
        };
        memoryPsiNominal = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Direct S0 kernel memory PSI check.";
          };
          psiThreshold = lib.mkOption {
            type = lib.types.float;
            default = 15.0;
            description = "Memory PSI avg10 stall percentage threshold.";
          };
        };
      };

      s1Contextual = {
        thermalVsMedia = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "S1 Kelly arbitration: Thermals vs 4K TV / Jellyfin playback continuity.";
          };
          protectedServices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = ["niri" "jellyfin"];
            description = "Protected display / media services.";
          };
          maxEmergencyTempC = lib.mkOption {
            type = lib.types.float;
            default = 84.0;
            description = "Critical temperature overriding stream continuity.";
          };
        };
        memoryVsCache = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "S1 Kelly arbitration: Memory PSI vs database pagecache retention.";
          };
          preferZram = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Prefer zram compaction over dropping DB pagecache.";
          };
        };
        walVsConcurrency = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "S1 Kelly arbitration: Active write concurrency vs WAL truncation.";
          };
          bloatThresholdKb = lib.mkOption {
            type = lib.types.int;
            default = 10240;
            description = "WAL threshold in KB for active contention.";
          };
        };
      };

      s2Investigative = {
        btrfsCorruption = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "S2 escalation on non-zero Btrfs device corruption/IO errors.";
          };
          autoSnapshot = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Create emergency read-only snapshot before repair.";
          };
          stopServices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = ["transmission-daemon"];
            description = "Services to pause during corruption.";
          };
        };
        flakeTransitiveCve = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "S2 escalation on critical transitive flake CVE advisory.";
          };
          flakePath = lib.mkOption {
            type = lib.types.str;
            default = toString ../..;
            description = "Target flake path (defaults to this flake's source).";
          };
        };
        consensusAnomaly = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "S2 escalation when Julia-1 and Laya split on critical anomaly.";
          };
          emitHandoff = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Append findings directly to ${user.home}/HANDOFF.md.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fleet-governor = {
      description = "Consolidated Fleet Governor & 3-Tier Escalation Router (S0/S1/S2)";
      path = [
        pkgs.coreutils
        pkgs.btrfs-progs
        pkgs.sqlite
        pkgs.systemd
        pkgs.curl
        pkgs.gnugrep
        pkgs.gawk
        pkgs.procps
        pkgs.python3
        config.services.systemoneDecision.ensemblePackage
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = "${user.home}";
        ExecStart = ''
          ${pkgs.writeShellScript "run-fleet-governor" ''
            set -euo pipefail
            FLAGS="--rules ${rulesConfig}"
            if [ "${toString cfg.autoRepair}" = "1" ]; then
              FLAGS="$FLAGS --auto-repair"
            fi
            if [ "${toString cfg.allowSystem2}" = "1" ]; then
              FLAGS="$FLAGS --allow-s2"
            fi

            if command -v systemone-ensemble >/dev/null 2>&1; then
              systemone-ensemble govern $FLAGS
            else
              python3 ${toString ../..}/modules/services/systemone/ensemble.py govern $FLAGS
            fi
          ''}
        '';
      };
    };

    systemd.timers.fleet-governor = {
      description = "Scheduled Consolidated Fleet Governor Timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "60s";
      };
    };
  };
}
