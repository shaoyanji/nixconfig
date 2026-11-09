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
  # The host's one tailnet name, not a second copy of the suffix: the portal's
  # mounts, the console's links and this capsule's certificate must agree.
  tailnetHost = config.services.servicePortal.tailnetHost;

  capsule = import ../../lib/gemini-portal.nix {inherit pkgs lib;};
  mail = import ../../lib/gemini-mail.nix {inherit pkgs lib;};
  turns = import ../../lib/gemini-turns.nix {inherit pkgs lib;};

  # The tailnet instance is the portfolio plus the two live readers, and it is
  # the only one that names a CGI path. The public capsule has neither the trees
  # nor `CGIPaths`, so port 1965 can never reach the archive or the turn log.
  # The readers link each other, and both are linked from the portfolio index.
  tailnetCapsule = turns.capsule (mail.capsule (import ../../lib/gemini-portal.nix {
    inherit pkgs lib;
    extra = mail.indexSection ++ turns.indexSection;
  }));

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
      DocBase = tailnetCapsule;
      AccessLog = "/var/log/molly-brown-tailnet/access.log";
      ErrorLog = "/var/log/molly-brown-tailnet/error.log";
      # MUST be relative: config.go joins a relative entry to DocBase and leaves
      # an absolute one alone, then compares against the resolved filesystem
      # path (hosts/frieren/gemini.nix carries the same note).
      CGIPaths = ["cgi-bin"];
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

  # The turn reader presents a bearer token to the shim on loopback, and
  # molly-brown starts a CGI with an empty environment (`cmd.Env = []string{}`
  # in its dynamic.go), so the token cannot arrive through the unit's
  # environment — it has to be a file the capsule's group can read. Rendering the
  # existing secret through `sops.placeholder` keeps one credential rather than a
  # second copy of it, and /run/secrets/rendered is group-traversable (0751).
  sops.templates."gemini-turns-token" = {
    content = config.sops.placeholder."agent-turns-token";
    mode = "0440";
    group = "gemini";
  };

  # A rotated token reaches the shim through its own restartUnits; the reader
  # reads the file per request, but re-rendering replaces the inode, so it needs
  # the same nudge.
  sops.secrets."agent-turns-token".restartUnits = lib.mkAfter ["molly-brown-tailnet.service"];

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

  networking.firewall.allowedTCPPorts = [publicPort];

  # Never in the global list: only the mesh reaches 1966. The row goes into the
  # host's one exposure registry rather than onto the interface list, because a
  # port written by hand is a port that cannot follow the listener it belongs to.
  profiles.serviceExposure.services.gemini-tailnet = {
    port = tailnetPort;
    lan = false;
    tailnet = true;
  };
}
