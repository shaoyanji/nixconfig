# Declarative Agent Scheduler (EXP-016).
#
# Provides a declarative registry for autonomous agent jobs across the fleet
# (e.g. nightly health auditing, handoff execution, repository upkeep).
#
# Replaces ad-hoc, hand-rolled user timer/service definitions with:
#   - Structured options per job (schedule, command, working directory, lock).
#   - Automatic mutex locking via flock to enforce "at most one rebuild/audit at a time".
#   - Consistent PATH injection with setuid wrappers (/run/wrappers/bin) first.
#   - Full integration with systemd user timers under user linger.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.agentScheduler;
  user = import ../global/user.nix;

  jobType = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Unique unit name for this scheduled agent job.";
      };

      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this scheduled job is enabled.";
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = "Scheduled agent execution: ${name}";
        description = "Service description for systemd.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        description = "systemd OnCalendar expression (e.g. '*-*-* 05:00:00').";
      };

      command = lib.mkOption {
        type = lib.types.package;
        description = "Executable package/script to run.";
      };

      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = user.home;
        description = "Working directory for the job.";
      };

      lockFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "/tmp/agent-scheduler.lock";
        description = ''
          Flock lockfile path to prevent overlapping agent executions or concurrent
          rebuild collisions. Null disables locking.
        '';
      };

      persistent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the timer should catch up if missed while suspended.";
      };

      randomizedDelaySec = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional jitter delay for the timer.";
      };
    };
  });
in {
  options.services.agentScheduler = {
    enable = lib.mkEnableOption "declarative autonomous agent scheduler";

    jobs = lib.mkOption {
      type = lib.types.attrsOf jobType;
      default = {};
      description = "Attribute set of scheduled agent jobs.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services = lib.mapAttrs' (_: job:
      lib.nameValuePair job.name {
        inherit (job) description;
        after = ["network.target"];
        serviceConfig = {
          Type = "oneshot";
          WorkingDirectory = job.workingDirectory;
          Environment = [
            "HOME=${user.home}"
            "USER=${user.name}"
            "PATH=/run/wrappers/bin:${user.home}/.nix-profile/bin:/etc/profiles/per-user/${user.name}/bin:/run/current-system/sw/bin:${user.home}/.local/bin"
            "SHELL=/run/current-system/sw/bin/bash"
          ];
          ExecStart =
            if job.lockFile != null
            then "${pkgs.util-linux}/bin/flock -w 60 ${job.lockFile} ${job.command}"
            else "${job.command}";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      })
    (lib.filterAttrs (_: j: j.enable) cfg.jobs);

    systemd.user.timers = lib.mapAttrs' (_: job:
      lib.nameValuePair job.name {
        description = "Timer for ${job.description}";
        timerConfig =
          {
            OnCalendar = job.schedule;
            Persistent = job.persistent;
          }
          // lib.optionalAttrs (job.randomizedDelaySec != null) {
            RandomizedDelaySec = job.randomizedDelaySec;
          };
        wantedBy = ["timers.target"];
      })
    (lib.filterAttrs (_: j: j.enable) cfg.jobs);
  };
}
