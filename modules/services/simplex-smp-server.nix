# `services.simplex-smp-server`: SimpleX SMP relay under systemd, TLS from the proxy.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.simplex-smp-server;
in {
  options.services.simplex-smp-server = {
    enable = lib.mkEnableOption "SimpleX Messaging Protocol (SMP) server broker";

    package = lib.mkPackageOption pkgs "smp-server" {};

    port = lib.mkOption {
      type = lib.types.port;
      default = 5223;
      description = "Port to listen on for incoming SMP TLS connections.";
    };

    ip = lib.mkOption {
      type = lib.types.str;
      default = "192.168.3.25";
      description = "Primary LAN IP address or FQDN for server TLS certificate generation.";
    };

    tailscaleIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "100.97.61.65";
      description = "Tailscale IPv4 address for remote access over Tailnet.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the SMP server port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.smp = {
      isSystemUser = true;
      group = "smp";
      home = "/var/lib/simplex";
      createHome = true;
    };
    users.groups.smp = {};

    systemd.tmpfiles.rules = [
      "d /etc/opt 0755 root root -"
      "d /etc/opt/simplex 0750 smp smp -"
      "d /var/opt 0755 root root -"
      "d /var/opt/simplex 0750 smp smp -"
      "d /var/lib/simplex 0750 smp smp -"
    ];

    systemd.services.smp-server = {
      unitConfig.X-Fleet-Role = "daemon";
      description = "SimpleX SMP Server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      path = with pkgs; [
        cfg.package
        openssl
        coreutils
        gnused
        bash
      ];

      preStart = ''
        if [ ! -f /etc/opt/simplex/smp-server.ini ]; then
          echo "Initializing SimpleX SMP server..."
          ${cfg.package}/bin/smp-server init -y \
            --ip ${cfg.ip} \
            --disable-web \
            --no-password

          # Restrict listening port to configured port only (prevent colliding on 443 with nginx)
          sed -i 's/^port = .*/port = ${toString cfg.port}/' /etc/opt/simplex/smp-server.ini

          # Ensure source_code property is set under [INFORMATION]
          if ! grep -q "^source_code" /etc/opt/simplex/smp-server.ini; then
            sed -i '/^\[INFORMATION\]/a source_code = https://github.com/simplex-chat/simplexmq' /etc/opt/simplex/smp-server.ini
          fi

          ${lib.optionalString (cfg.tailscaleIp != null) ''
          # If tailscaleIp is defined, advertise both LAN and Tailscale IPs in transport host
          sed -i 's/^host = .*/host = ${cfg.ip},${cfg.tailscaleIp}/' /etc/opt/simplex/smp-server.ini
        ''}
        fi
      '';

      serviceConfig = {
        User = "smp";
        Group = "smp";
        ExecStart = "${cfg.package}/bin/smp-server start";
        Restart = "always";
        RestartSec = 5;
        LimitNOFILE = 65535;
        KillSignal = "SIGINT";
        TimeoutStopSec = "infinity";
        WorkingDirectory = "/var/lib/simplex";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
  };
}
