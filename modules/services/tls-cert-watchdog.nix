# Autonomous Nginx SSL/TLS Certificate Expiry & OCSP Stapling Watchdog (EXP-050)
# Probes local certificate files and declared HTTPS endpoints to assert valid expiration windows.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tlsCertWatchdog;

  watchdogPy = ./tls-watchdog/watchdog.py;

  watchdogScript = pkgs.writeShellApplication {
    name = "tls-cert-watchdog";
    runtimeInputs = [
      pkgs.python3
      pkgs.openssl
    ];
    text = ''
      exec python3 "${watchdogPy}" \
        --warn-days "${toString cfg.warnDays}" \
        --critical-days "${toString cfg.criticalDays}" \
        ${lib.optionalString cfg.failOnCritical "--fail-on-critical"} \
        --endpoints ${lib.escapeShellArgs cfg.endpoints} \
        --cert-files ${lib.escapeShellArgs cfg.certFiles} \
        "$@"
    '';
  };
in {
  options.services.tlsCertWatchdog = {
    enable = lib.mkEnableOption "Nginx SSL/TLS Certificate Expiry & OCSP Stapling Watchdog (EXP-050)";

    package = lib.mkOption {
      type = lib.types.package;
      default = watchdogScript;
      description = "The tls-cert-watchdog package to execute.";
    };

    endpoints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "HTTPS endpoints to audit for TLS certificate expiration.";
    };

    certFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Filesystem paths to X.509 certificate files to audit.";
    };

    warnDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Days before certificate expiration to emit a warning.";
    };

    criticalDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Days before certificate expiration to flag critical failure.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar schedule.";
    };

    failOnCritical = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to exit non-zero on critical expiration status.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.services.tls-cert-watchdog = {
      description = "Nginx SSL/TLS Certificate Expiry Watchdog (EXP-050)";
      wantedBy = [];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/tls-cert-watchdog";
        User = "root";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    };

    systemd.timers.tls-cert-watchdog = {
      description = "Scheduled Nginx SSL/TLS Certificate Expiry Watchdog (EXP-050)";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
