# delphi over Gemini: the portfolio capsule on port 1965, plus its tailnet
# instance. Ports, certificates and the OCI ingress caveat live in
# .agents/deploy/hosts/delphi.md § The Gemini capsule.
{
  config,
  lib,
  pkgs,
  ...
}: let
  hostMeta = config.fleet.inventory.hosts.delphi;
  publicHost = hostMeta.network.domain;
  tailnetHost = "${hostMeta.network.tailscale_hostname}.cloudforest-kardashev.ts.net";

  capsule = import ../../lib/gemini-portal.nix {inherit pkgs lib;};

  publicPort = 1965;
  tailnetPort = 1966;

  acmeDir = "/var/lib/acme/${publicHost}";
  tailnetTlsDir = "/var/lib/gemini/tailnet";
  tailnetCert = "${tailnetTlsDir}/cert.pem";
  tailnetKey = "${tailnetTlsDir}/key.pem";

  # molly-brown reads the MIME type from the extension, so this only pins the
  # two résumés to `application/json` independently of Go's stdlib table.
  geminiSettings = {
    DefaultEncoding = "utf-8";
    MimeOverrides = {"\\.json$" = "application/json";};
  };

  tailnetConfig = (pkgs.formats.toml {}).generate "molly-brown-tailnet.toml" ({
      Port = tailnetPort;
      Hostname = tailnetHost;
      CertPath = tailnetCert;
      KeyPath = tailnetKey;
      DocBase = capsule;
      AccessLog = "/var/log/molly-brown-tailnet/access.log";
      ErrorLog = "/var/log/molly-brown-tailnet/error.log";
    }
    // geminiSettings);
in {
  # Only the tailnet key needs a group of its own; the public instance joins
  # nginx's (see `SupplementaryGroups` below).
  users.groups.gemini = {};

  # molly-brown loads its certificate at startup, so renewal reaches it through
  # a restart. The cert keeps nginx's group: the acme module asserts that every
  # declared consumer can read the key.
  security.acme.certs.${publicHost} = {
    reloadServices = ["molly-brown.service"];
  };

  services.molly-brown = {
    enable = true;
    port = publicPort;
    hostName = publicHost;
    certPath = "${acmeDir}/fullchain.pem";
    keyPath = "${acmeDir}/key.pem";
    docBase = capsule;
    settings = geminiSettings;
  };

  systemd.services.molly-brown = {
    # A first boot may find no certificate yet; the module's 100 ms retry would
    # spin the unit until ACME finished.
    after = ["acme-${publicHost}.service"];
    unitConfig.X-Fleet-Role = "daemon";
    serviceConfig = {
      SupplementaryGroups = [config.security.acme.certs.${publicHost}.group];
      RestartSec = 10;
    };
  };

  # tailscaled issues the MagicDNS name's certificate, so the tailnet capsule
  # needs no ACME line of its own.
  systemd.tmpfiles.rules = [
    "d ${tailnetTlsDir} 0750 root gemini -"
  ];

  systemd.services.gemini-tailnet-cert = {
    description = "Issue/renew the tailnet TLS certificate for the Gemini capsule";
    after = ["tailscaled.service" "network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.escapeShellArgs [
        "${config.services.tailscale.package}/bin/tailscale"
        "cert"
        "--cert-file=${tailnetCert}"
        "--key-file=${tailnetKey}"
        "--min-validity=720h"
        tailnetHost
      ];
      ExecStartPost = [
        "${pkgs.coreutils}/bin/chgrp gemini ${tailnetCert} ${tailnetKey}"
        "${pkgs.coreutils}/bin/chmod 0640 ${tailnetCert} ${tailnetKey}"
      ];
    };
  };

  systemd.timers.gemini-tailnet-cert = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.molly-brown-tailnet = {
    description = "Molly Brown gemini server (tailnet: ${tailnetHost})";
    after = ["network.target" "gemini-tailnet-cert.service"];
    # Ordering, not a hard requirement: a failed issuance must not wedge the
    # unit permanently, and `Restart=always` brings it up once the files exist.
    wants = ["gemini-tailnet-cert.service"];
    wantedBy = ["multi-user.target"];
    unitConfig.X-Fleet-Role = "daemon";
    serviceConfig = {
      DynamicUser = true;
      LogsDirectory = "molly-brown-tailnet";
      SupplementaryGroups = ["gemini"];
      ExecStart = "${pkgs.molly-brown}/bin/molly-brown -c ${tailnetConfig}";
      Restart = "always";
      RestartSec = 10;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [publicPort];
    # Never in the global list: only the mesh reaches 1966.
    interfaces.tailscale0.allowedTCPPorts = [tailnetPort];
  };
}
