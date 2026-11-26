# delphi — Oracle Cloud Infrastructure (OCI) Ampere A1 ARM64 headless server.
# Traps and retirements: note delphi-ops-traps; install: docs/delphi-install.md;
# runbook: .agents/deploy/hosts/delphi.md.
{
  self,
  pkgs,
  config,
  lib,
  user,
  nginxPkgs,
  ...
}: let
  # The address the whole tailnet points its DNS at (see the route group below).
  # Both this host and frieren bind it on lo and advertise it as the SAME /32,
  # which makes Tailscale treat them as one active/passive failover group: one
  # node answers, and the route moves when it disappears (~15 s).
  #
  # A /32 subnet route, not a 100.64/10 member address: Tailscale fails over
  # subnet routes, never between two global nameservers.
  # Home: docs/delphi-install.md §"Phase 4d — the 10.99.0.53 failover pair"; docs/dns-failover.md.
  dnsServiceAddress = "10.99.0.53";

  hostMeta = config.fleet.inventory.hosts.delphi;

  # Public HTTPS name; "" (registry's "unknown") → null — a vhost with an empty
  # server_name would be emitted (Trap: note delphi-ops-traps). The A record must
  # resolve before ACME renewals pass. Home: docs/delphi-install.md §"Phase 4c".
  publicDomain = let
    d = hostMeta.network.domain;
  in
    if d == ""
    then null
    else d;

  tailnetHost = "${hostMeta.network.tailscale_hostname}.${hostMeta.network.tailnet_domain}";
  # The key, not a MagicDNS name: `--accept-dns=false` (see below).
  tailnetIp = hostMeta.network.tailscale_ip;

  # Both landing pages from ONE compiled site: lib/delphi-site.nix.
  delphiSite = import ../../lib/delphi-site.nix {
    inherit pkgs;
    inventory = config.fleet.inventory;
    host = "delphi";
    cards = config.services.servicePortal.cards;
    inherit publicDomain tailnetHost;
    resolver = config.profiles.tailnetDnsAddress.address;
    nixosVersion = config.system.nixos.release;
  };
  publicPage = "${delphiSite}/public";
  tailnetPage = "${delphiSite}/tailnet";

  # A staleness gate compares `X-Site-Path` against `.#delphi-site.outPath` byte
  # for byte; the value is the SITE, and each `location` must set it itself.
  siteHeader = ''add_header X-Site-Path "${delphiSite}" always;'';

  # One cache policy for compiled static trees, shared with frieren's vhosts
  # (modules/config/nginx-static-cache.nix) so the two hosts cannot disagree
  # about how long a store path may be cached.
  staticCache = import ../../modules/config/nginx-static-cache.nix;

  # The public name hands a command-line client the terminal edition of the
  # dossier (`terminalDoc` in lib/delphi-site.nix) instead of the HTML, which a
  # program can neither read usefully nor colour.
  #
  # A POSITIVE match on known clients, not "anything that is not Mozilla":
  # invert the test and a crawler, a link unfurler or a monitoring probe also
  # gets plain text, and those are most of the audience the HTML page exists for.
  terminalClients = [
    "curl"
    "wget"
    "httpie"
    "xh"
    "nushell"
    "aria2"
    "python-requests"
    "python-urllib"
    "go-http-client"
    "libwww-perl"
    "node-fetch"
    "deno"
  ];
  terminalUa = "~*(${lib.concatStringsSep "|" terminalClients})";

  # The utility-layer recon report, from the store, `no-store` because the URL is
  # stable: hosts/delphi/reports/utility-layer-recon.html.
  reconReport = pkgs.writeTextDir "index.html" (builtins.readFile ./reports/utility-layer-recon.html);
  reconLocation = {
    alias = "${reconReport}/";
    extraConfig = ''
      autoindex off;
      add_header Cache-Control "no-store";
    '';
  };
  # `/recon` without the slash matches no location prefix, so a named exact match
  # redirects instead of relying on alias-implied 301 behaviour.
  reconRedirect = ''return 301 /recon/;'';

  # What makes a name inert on the internet though vhosts share 0.0.0.0:80:
  # 100.64/10 on tailscale0 is the allow-list.
  tailnetOnly = ''
    allow 127.0.0.1;
    allow ::1;
    allow 100.64.0.0/10;
    deny all;
  '';

  # A `location` inherits nothing, so each repeated fragment takes the gate as a
  # parameter; the trailing newline keeps the generated config byte-identical.
  gate = withGate: lib.optionalString withGate (tailnetOnly + "\n");
  healthzLocation = withGate: {
    "= /healthz".extraConfig =
      gate withGate
      + ''
        default_type text/plain;
        return 200 "ok";
      '';
  };
  sentinelLocations = withGate: {
    "/sentinel/" = {
      alias = "/var/lib/fleet-sentinel/www/";
      extraConfig =
        gate withGate
        + ''
          autoindex off;
          add_header Cache-Control "no-store";
        ''
        + siteHeader;
    };
  };
  reconLocations = {
    "/recon/" = reconLocation;
    "= /recon".extraConfig = reconRedirect;
  };
  # Eight explicit hex classes — a {8} quantifier is emitted SPLIT across lines
  # by the generator and nginx rejects the server (Trap: note delphi-ops-traps).
  hashedAssets = root: {
    "~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
      inherit root;
      extraConfig = staticCache.hashed;
    };
  };

  # Machine surfaces over the same data, tailnet only: the dossier JSON carries
  # `identity.tailnetIp`, which the public page is built never to print.
  dataLocation = withGate: let
    common =
      gate withGate
      + ''
        autoindex off;
        gzip_static on;
        add_header Cache-Control "no-store";
      '';
  in {
    "= /data/delphi.json" = {
      alias = "${delphiSite}/data/delphi.json";
      # This one IS `delphiSite`, so it carries the staleness header.
      extraConfig = common + siteHeader;
    };
    # No `X-Site-Path`: these bytes come from the portal's page package, not from
    # `delphiSite`, and that header is what the deploy gate compares.
    "= /data/services.json" = {
      alias = "${config.services.servicePortal.pages.tailnet}/data/services.json";
      extraConfig = common;
    };
  };

  telemetryLocations = withGate: {
    "/api/telemetry" = {
      proxyPass = "http://127.0.0.1:${toString config.services.servicePortal.telemetry.port}";
      extraConfig =
        gate withGate
        + ''
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_connect_timeout 1s;
          proxy_read_timeout 2s;
          add_header Cache-Control "no-store";
        '';
    };
  };

  # Guest removed — A1 has no KVM (Fact: inventory.toml); the dummy keeps
  # dependents evaluating (Story: note delphi-ops-traps).
  microvmGuest = {
    services = [];
    stirlingPath = "/microvm/stirling/";
    stirling = null;
    sshPort = 22;
    sshUser = "deck";
    sshHopTarget = "deck@localhost";
    sshHopGroup = "deck";
    sshHopKnownHosts = "/dev/null";
    sshHopKeyFile = "/dev/null";
  };
  microvmProxyLocations = withGate: let
    proxies =
      microvmGuest.services
      |> map (svc: {
        name = "/microvm/${svc.name}/";
        value =
          {
            # Trailing slash on both sides: /microvm/<name>/x -> upstream /x.
            proxyPass = "http://${microvmGuest.address}:${toString svc.port}/";
          }
          // lib.optionalAttrs withGate {extraConfig = tailnetOnly;};
      })
      |> lib.listToAttrs;
  in
    proxies
    // lib.optionalAttrs (microvmGuest.services != []) {
      # Bare /microvm is the namespace, not a page: send it to the first stub.
      "= /microvm".extraConfig =
        (lib.optionalString withGate tailnetOnly)
        + ''return 301 /microvm/${(lib.head microvmGuest.services).name}/;'';
    };

  # Stirling is tailnet-only on both vhosts; the public name redirects rather
  # than answering 403 from a gate a public client can never satisfy. It knows
  # its own prefix (SERVER_SERVLET_CONTEXT_PATH), so the path passes through
  # unchanged.
  stirlingTailnetUrl = "http://${tailnetHost}${microvmGuest.stirlingPath}/";
  stirlingProxyLocations = lib.optionalAttrs (microvmGuest.stirling != null) {
    "${microvmGuest.stirlingPath}/" = {
      proxyPass = "http://${microvmGuest.address}:${toString microvmGuest.stirling}${microvmGuest.stirlingPath}/";
      extraConfig =
        tailnetOnly
        + ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_buffering off;
          proxy_read_timeout 900s;
          client_max_body_size 512m;
        '';
    };
    "= ${microvmGuest.stirlingPath}".extraConfig = tailnetOnly + ''return 301 ${microvmGuest.stirlingPath}/;'';
  };
  stirlingPublicRedirect = lib.optionalAttrs (microvmGuest.stirling != null) {
    "${microvmGuest.stirlingPath}/".extraConfig = ''return 302 ${stirlingTailnetUrl};'';
    "= ${microvmGuest.stirlingPath}".extraConfig = ''return 302 ${stirlingTailnetUrl};'';
  };

  # The deck is a terminal app over ssh into the guest, so its web surface is an
  # address card: hosts/microvms/slideshow.md.
  slidesEnabled = microvmGuest.sshPort != null && microvmGuest.sshUser != null;
  slideshowPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>slideshow</title>
      </head>
      <body style="font-family: system-ui, sans-serif; margin: 3rem; max-width: 46rem">
        <h1>slideshow</h1>
        <p>A terminal deck: <code>slides</code> reading a markdown file inside the
          <code>sandbox</code> microVM on this host. It renders over ssh, so a
          browser has nothing to show yet.</p>
        <h2>Reach it</h2>
        <pre>ssh ${microvmGuest.sshUser}@${publicDomain}
        ssh -p ${toString microvmGuest.sshPort} ${microvmGuest.sshUser}@${tailnetHost}</pre>
        <p>Key-only, and the login <em>is</em> the deck: the account runs one
          forced command with no shell and no forwarding. The public name is port
          22, where the host's sshd hops into the guest; the tailnet name goes
          straight to the guest's own sshd.</p>
      </body>
    </html>
  '';

  # The public ssh door: port 22 (2222 is the tenancy's to add, not ours), an
  # account whose whole login is a hop into the guest, so the guest credential
  # never leaves this machine.
  slidesHopEnabled = microvmGuest.sshHopTarget != null;
  slidesHopCommand = lib.concatStringsSep " " [
    "${pkgs.openssh}/bin/ssh"
    # The outer session's stdin is the deck's terminal, so the inner client must
    # ask for a pty even when the outer login was `-T`.
    "-tt"
    "-o BatchMode=yes"
    "-o StrictHostKeyChecking=yes"
    "-o IdentitiesOnly=yes"
    "-o UserKnownHostsFile=${toString microvmGuest.sshHopKnownHosts}"
    # sntrup761x25519 costs about a minute of interpreted CPU under TCG; the
    # handshake times out before the banner without this.
    "-o KexAlgorithms=curve25519-sha256"
    "-o ConnectTimeout=30"
    # If the deck stops answering, end the hop instead of parking the outer
    # session on a dead channel — the guest's keepalive handles the other
    # direction, this one handles a silent peer.
    "-o ServerAliveInterval=30"
    "-o ServerAliveCountMax=3"
    "-i ${toString microvmGuest.sshHopKeyFile}"
    microvmGuest.sshHopTarget
  ];

  # Same treatment as /microvm/: locations inherit nothing.
  slideshowLocations = withGate: {
    "= /slideshow".extraConfig =
      (lib.optionalString withGate tailnetOnly)
      + ''return 301 /slideshow/;'';
    "/slideshow/" = {
      alias = "${slideshowPage}/";
      index = "index.html";
      extraConfig = lib.optionalString withGate tailnetOnly;
    };
  };

  freebuff-headless = import ../../modules/scripts/freebuff-headless.nix {inherit pkgs;};
in {
  imports = [
    ./anki-sync.nix
    ./email-archive.nix
    ./nix-cache-edge.nix
    ./gemini.nix
    ./gok-artifacts.nix
    ./hardware-configuration.nix
    ./infra-stack.nix
    ./mataroa-console.nix
    ./minyx-keeper.nix
    ./needle-router.nix
    ./paperless.nix
    ./vaultwarden.nix
    ./zettel-graph.nix
    self.modules."profiles.base-node"
    self.modules."profiles.firewall-baseline"
    self.modules."profiles.hermes"
    self.modules."profiles.operator-tools"
    self.modules."profiles.service-exposure"
    self.modules."profiles.sops-user-identity"
    self.modules."net.dns.tailnet-address"
    self.modules."services.agent-turns"
    self.modules."services.appflow-board"
    self.modules."services.dsh-web"
    self.modules."services.dsh-free-models"
    self.modules."services.fleet-monitors"
    self.modules."services.clanker-runner"
    self.modules."services.job-db-scraper"
    self.modules."services.private-deals"
    self.modules."services.inventory-site"
    self.modules."services.link-vault"
    self.modules."services.mataroa-console"
    self.modules."services.media-relay"
    self.modules."services.offload-bridge"
    self.modules."services.paperless-watchdog"
    self.modules."services.service-portal"
    self.modules."services.systemone-decision"
    self.modules."services.turns-dashboard"
    self.modules."services.xs-notify"
  ];

  # --- YouTube relay: fetch where the peering is good, serve over the tailnet ---
  # Why, and what is still unproven (the home-side figure was measured while the
  # uplink was saturated): `docs/media-relay.md`.
  services.media-relay.enable = true;

  # The bucket half: `→ R2` on the page, playback from the edge (docs/media-relay.md)
  services.media-relay.r2.enable = true;

  # --- the job pipeline as a page ---
  # Five reads plus the two write routes over the archive's tables; consumer of
  # the appflow-single-writer cutover.
  services.appflowBoard.enable = true;

  # The searchable posting index beside it: boards and provider-backed search in,
  # one deduplicated SQLite/FTS5 database out. Loopback only; the portal mount
  # below is the exposure and supplies the origin a write is checked against.
  services.clankerRunner = {
    enable = true;
    inherit tailnetHost;
  };
  services.jobDbScraper = {
    enable = true;
    inherit tailnetHost;
  };
  services.privateDeals = {
    enable = true;
    inherit tailnetHost;
  };
  services.inventorySite = {
    enable = true;
    inherit tailnetHost;
    inventorySeedFile = ../../inventory.toml;
  };
  services.linkVault = {
    enable = true;
    inherit tailnetHost;
  };

  # --- the free-model relay, durable ---
  # The clanker proof in a unit instead of a tmux: the plugin fronts free lanes
  # (DeepSeek V4.1 Flash, Kimi K3) behind an OpenAI-compatible gateway on
  # loopback :8326, exposed on the tailnet by the `free-models` mount below.
  services.dshFreeModels = {
    enable = true;
    user = user.name;
    trustedHosts = ["${tailnetHost}:8443" "${tailnetHost}:8327"];
    environmentFile = config.sops.templates."dsh-web.env".path;
  };

  # One half of the failover group; frieren runs the same module and the same /32
  # (setting only `.address` does nothing — the bind is behind `enable`).
  profiles.tailnetDnsAddress = {
    enable = true;
    address = dnsServiceAddress;
    exitNode = true;
  };

  # Both public surfaces compile from these registry fields; empty fails at eval
  # rather than shipping a vhost with no `server_name`.
  assertions = [
    {
      assertion = hostMeta.network.domain != "";
      message = "inventory.toml [hosts.delphi.network]: `domain` is required for the public TLS vhost.";
    }
    {
      assertion = hostMeta.network.tailscale_hostname != "";
      message = "inventory.toml [hosts.delphi.network]: `tailscale_hostname` is required for the tailnet console's links.";
    }
    {
      assertion = hostMeta.network.tailnet_domain != "";
      message = "inventory.toml [hosts.delphi.network]: `tailnet_domain` is required — the MagicDNS name is `tailscale_hostname` + `tailnet_domain`.";
    }
    {
      assertion = hostMeta.network.tailscale_ip != "";
      message = "inventory.toml [hosts.delphi.network]: `tailscale_ip` is required for the console and the monitor card.";
    }
  ];

  # --- The gate toolchain -----------------------------------------------------
  # This box runs `task checks:*`, so `toon` and `python3` belong in the closure.
  # No browser: `checks:kg:canvas` skips its click step without `agent-browser`,
  # and ~700 MB for one optional half is a deliberate trade.
  profiles.operatorTools = {
    enable = true;
    browser = false;
  };

  # --- User-plane sops identity ----------------------------------------------
  # Home Manager activation runs as devji and needs a user-readable identity; this
  # host has no `~/.ssh/id_ed25519` (CA logins), so the host key yields the
  # `&delphi` recipient already in .sops.yaml. Frieren and fern use the TPM path.
  profiles.sopsUserIdentity.enable = true;

  # No `profiles.cachePush`: a post-build-hook on a 2-vCPU guest would upload
  # every local build. Delphi substitutes from cachix instead. Why:
  # docs/nix-cache-edge.md §"Who does not push".

  # --- OCI Networking & Paravirtualized DHCP ---
  networking.useDHCP = lib.mkDefault true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      80 # nginx (a landing page that proves the webserver)
      443 # reserved for the TLS vhost; nothing listens until a cert exists
    ];
    allowedUDPPorts = [41641]; # Tailscale direct WireGuard port
  };

  # --- Tailscale mesh: exit node + shared DNS service address ---
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    extraSetFlags = [
      "--accept-routes=true"
      # The resolver must never resolve through the address it serves:
      # [[flake/policies.nix#resolver-never-through-served-address]] (outage
      # loop — the host could not reach the tailnet it serves).
      "--accept-dns=false"
      # `--advertise-exit-node` and the `/32` route are emitted by
      # net/dns/tailnet-address.nix (`exitNode = true`), not here.
    ];
  };

  # The lo bind itself lives in net/dns/tailnet-address.nix (shared with
  # frieren, which advertises the same /32 as the passive member).

  # LIMIT: forwarding ad-blocker with no zone support — *.frieren.lan returns
  # NODATA (Story: note delphi-ops-traps). Fixes: docs/dns-failover.md.
  services.crab-hole = {
    enable = true;
    openFirewall = false;
    settings = {
      # UDP only: crab-hole v0.1.12 has no plain tcp downstream — no DNS-over-TCP
      # retry on truncation (Trap: note delphi-ops-traps).
      downstream = [
        {
          listen = "0.0.0.0";
          port = 53;
          protocol = "udp";
        }
      ];
      # DoT upstreams, IPv4-only (no IPv6 uplink — Fact: inventory.toml); envs.net
      # last as the privacy fallback. Why: docs/delphi-install.md §"DoT upstreams".
      upstream.name_servers = [
        {
          protocol = "tls";
          socket_addr = "1.1.1.1:853";
          tls_dns_name = "one.one.one.one";
          trust_nx_responses = false;
        }
        {
          protocol = "tls";
          socket_addr = "9.9.9.9:853";
          tls_dns_name = "dns.quad9.net";
          trust_nx_responses = false;
        }
        {
          protocol = "tls";
          socket_addr = "157.180.15.214:853";
          tls_dns_name = "dns.envs.net";
          trust_nx_responses = false;
        }
      ];
      # Same two lists frieren's pihole-ftl uses — failover answers must match:
      # flake/policies.nix#dns-failover-blocklist-parity.
      blocklist = {
        include_subdomains = true;
        lists = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
          "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
        ];
      };
      api = {
        listen = "127.0.0.1";
        port = 8081;
        show_doc = false;
      };
    };
  };

  # --- The tailnet firewall surface, from ONE registry ----------------------
  # Every port on the mesh, scoped to `tailscale0`, each value read from the option
  # that owns it so a moved service cannot leave a stale row; instrument:
  # task checks:ports HOST=delphi IFACE=tailscale0.
  profiles.serviceExposure = {
    enable = true;
    interfaces = ["tailscale0"];
    services =
      {
        # The fleet resolver. UDP is crab-hole's only plain DNS downstream.
        crabhole-dns = {
          port = 53;
          tcp = false;
          udp = true;
          lan = false;
          tailnet = true;
        };
        fleet-monitors = {
          port = config.services.fleetMonitors.port;
          lan = false;
          tailnet = true;
        };
      }
      // lib.optionalAttrs (lib.hasAttr "paperless" config.services) {
        # Moved off the NAS — offload: docs/service-offload.md + note open-frieren-offload.
        paperless = {
          port = config.services.paperless.port;
          lan = false;
          tailnet = true;
        };
      }
      // lib.optionalAttrs (lib.hasAttr "vaultwarden" config.services) {
        vaultwarden = {
          port = config.services.vaultwarden.config.ROCKET_PORT;
          lan = false;
          tailnet = true;
        };
      }
      // lib.optionalAttrs (lib.hasAttr "anki-sync-server" config.services) {
        anki-sync = {
          port = config.services.anki-sync-server.port;
          lan = false;
          tailnet = true;
        };
      };
  };

  # --- Fleet monitors, from OUTSIDE the LAN ---------------------------------
  # The other vantage point: an internet-path fact, not a LAN one, because frieren's
  # own gatus only probes loopback. Mechanism in modules/services/fleet-monitors.nix;
  # alerting stays off, since no SimpleX daemon runs here.
  services.fleetMonitors = {
    enable = true;
    # Monitors reach delphi via its tailnet address; they cannot probe 10.99.0.53 —
    # that sits behind the failover pair (Fact: inventory.toml).
    address = "0.0.0.0";
    endpoints = [
      {
        name = "delphi nginx";
        url = "http://127.0.0.1/healthz";
        group = "delphi";
        conditions = ["[STATUS] < 400"];
      }
      {
        name = "delphi sentinel";
        url = "http://127.0.0.1/sentinel/status.json";
        group = "delphi";
        conditions = ["[BODY].state == ok"];
      }
      # No DNS endpoint: crab-hole has no TCP listener on 53, so a `tcp://` probe can
      # only stay red. Why: docs/delphi-install.md §"Fleet monitors".
      {
        name = "frieren portal (tailnet)";
        url = "http://100.97.61.65/";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
      }
      # exp-105: the resolver monitored as a service — pihole-ftl answers on the
      # tailnet address, so a wrong zone or a dead daemon both go red here.
      {
        name = "frieren resolver (tailnet)";
        url = "100.97.61.65";
        group = "frieren";
        dns = {
          query-name = "dns-probe.frieren.lan";
          query-type = "A";
        };
        conditions = ["[DNS_RCODE] == NOERROR" "[BODY] == 192.168.3.25"];
      }
      {
        name = "frieren sentinel";
        url = "http://100.97.61.65/sentinel/status.json";
        group = "frieren";
        headers = {
          Host = "frieren.lan";
        };
        conditions = ["[BODY].state == ok"];
      }
      # NAS services probed over the tailnet since frieren's gatus retired (Story:
      # note frieren-ops-history); probes cannot outlive their exposure-registry
      # holes — audiobookshelf has no port, probed by name.
      {
        name = "frieren jellyfin";
        url = "http://100.97.61.65:8096";
        group = "frieren";
      }
      {
        name = "frieren immich";
        url = "http://100.97.61.65:2283";
        group = "frieren";
      }
      {
        name = "frieren home assistant";
        url = "http://100.97.61.65:8123";
        group = "frieren";
      }
      {
        name = "frieren harmonia";
        url = "http://100.97.61.65:5000";
        group = "frieren";
      }
      {
        name = "frieren audiobookshelf";
        url = "http://100.97.61.65/";
        group = "frieren";
        headers = {
          Host = "audiobooks.frieren.lan";
        };
      }
      # paperless came off the NAS; its check moves from frieren's retired list
      # to the host that serves it.
      {
        name = "paperless";
        url = "http://127.0.0.1:28981";
        group = "delphi";
      }
      # The console's own ledger is the assertion, probed on loopback because
      # delphi runs `--accept-dns=false` and the tailnet mount fronts this same
      # listener. `remote_count > 0` is the half that proves the blog is
      # reachable: a dead token renders a ledger too, just with nothing in it.
      # docs/mataroa-console.md#monitoring
      {
        name = "mataroa console";
        url = "http://127.0.0.1:8095/api/state";
        group = "delphi";
        conditions = [
          "[BODY].ok == true"
          "[BODY].remote_count > 0"
        ];
      }
      # Two of frieren's checks do not survive the move, and no probe can carry
      # them: the Steam cache binds loopback only (`/__health` on 127.0.0.1:8081,
      # no exposure entry, no vhost), and the resolver check names 10.99.0.53 —
      # the failover address THIS host also serves, so a probe from here would
      # only prove delphi to itself. Both stay host-local concerns; the sentinel
      # ledger (`[BODY].state`, above) is what reports the NAS's own pressure.
    ];
  };

  # Alerts are delivered by the only host that has an identity behind the
  # bridge: frieren's SimpleX profile posts to its #Fleet group, and this host's
  # bridge has no daemon to talk to (see `alerting.address` in
  # modules/services/fleet-monitors.nix and the exposure registry there).
  services.fleetMonitors.alerting.url = "http://100.97.61.65:5226/alert";

  # crab-hole owns :53 — the resolved stub collides (EADDRINUSE); it stays
  # stub-less (Trap: note delphi-ops-traps).
  services.resolved.settings.Resolve = {
    DNSStubListener = "no";
    LLMNR = false;
  };
  networking.networkmanager.dns = lib.mkForce "none";
  networking.nameservers = [
    "127.0.0.1"
    "::1"
  ];

  # No client can prelogin at the vault's own port: cli refuses http, the
  # *.frieren.lan cert lives on frieren's nginx, and crab-hole has no zone —
  # so the name gets a static answer: frieren's tailnet IP (Fact: inventory.toml).
  # rbw is the vault client; bw survives for passkeys only.
  networking.hosts."100.97.61.65" = ["vault.frieren.lan"];

  # --- The gokrazy appliance's build artifacts ---------------------------------
  # .github/workflows/gok.yml sends them here over Taildrop and
  # `task infra:gok:deploy` pushes from here; hosts/delphi/gok-artifacts.nix
  # explains why a runner publishes a file instead of pushing to the device.
  services.gokArtifacts.enable = true;

  # --- Webserver --------------------------------------------------------------
  # TLS comes from ACME on the public name; the :80 IP vhost stays as an edge
  # probe independent of DNS. OCI's security list must also allow 80/443
  # (console change, not declarable here — see .agents/deploy/hosts/delphi.md).
  #
  # The tailnet entry point is `tailscale serve` on 8443, not a second nginx
  # vhost: nginx binds 0.0.0.0:443, so tailscaled cannot take 443 on the tailnet
  # address (measured 2026-10-21: "bind: address already in use"), and serve
  # brings its own managed certificate for the MagicDNS name instead of another
  # ACME line. This vhost keeps only the public landing page and /healthz.
  # The served artifact, exposed where every other host build output lives, so
  # `.#delphi-site` can be THIS value instead of a host-free lookalike.
  system.build.delphiSite = delphiSite;

  services.nginx = {
    enable = true;
    # 1.30.7 from the nixpkgs-nginx pin — the CVE-2026-123007/123633 fix while
    # the fleet nixpkgs holds (Story: note delphi-ops-traps).
    package = nginxPkgs.nginx;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # `map` is an http-level directive, so it cannot live inside a vhost. The
    # variable is read by the public vhost's root location, which is why the
    # match list above is host-level and not location-level.
    mapHashBucketSize = 128;
    commonHttpConfig = ''
      map $http_user_agent $delphi_terminal {
        default 0;
        "${terminalUa}" 1;
      }
    '';

    # One virtualHosts definition per host — a module must not set the attrpath
    # twice; TLS merges with // (Trap: note delphi-ops-traps).
    virtualHosts =
      {
        delphi = {
          default = true;
          listen = [
            {
              addr = "0.0.0.0";
              port = 80;
            }
          ];
          root = "${publicPage}";
          # Liveness, the sentinel ledger, the recon report and hashed assets:
          # the fragments every vhost shares, defined once above.
          locations =
            {
              "/" = {
                index = "index.html";
                tryFiles = "$uri $uri/ =404";
                extraConfig = staticCache.html + siteHeader;
              };
            }
            // healthzLocation false
            // sentinelLocations false
            // reconLocations
            // hashedAssets publicPage;
        };

        # The tailnet console, loopback-only and reached through `tailscale
        # serve` on 8446. It is a vhost rather than a `return 200 "…"` so the
        # page keeps its own static root and the mounts stay the only ingress.
        delphi-portal = {
          listen = [
            {
              addr = "127.0.0.1";
              port = 8082;
            }
          ];
          root = "${tailnetPage}";
          locations =
            {
              "/" = {
                index = "index.html";
                tryFiles = "$uri $uri/ =404";
                extraConfig = staticCache.html + siteHeader;
              };
            }
            // hashedAssets tailnetPage
            // dataLocation false
            // telemetryLocations false;
        };

        # The console's TLS entry point is the :8446 mount, and this vhost adds the
        # port-80 form. Why: .agents/deploy/hosts/delphi.md §"Tailnet service mounts".
        "${tailnetHost}" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 80;
            }
          ];
          root = "${tailnetPage}";
          locations =
            {
              "/" = {
                index = "index.html";
                tryFiles = "$uri $uri/ =404";
                # No cache policy here: the allow-list IS the point of this vhost,
                # and the gate reads the same header the mesh client would.
                extraConfig = tailnetOnly + siteHeader;
              };
              # Taildrop's landing pad (hosts/delphi/gok-artifacts.nix), read by
              # `task infra:gok:deploy` and by a runner proving its artifact
              # arrived. Tailnet vhost only, deliberately: the appliance image has
              # the wifi PSK, the tailscale auth key and the update password baked
              # into it, so the mesh ACL is the whole authorization boundary and
              # there is no public counterpart.
              "/gok/" = {
                alias = "${config.services.gokArtifacts.directory}/";
                extraConfig =
                  ''
                    ${tailnetOnly}
                    autoindex off;
                    add_header Cache-Control "no-store";
                  ''
                  + siteHeader;
              };
            }
            // healthzLocation true
            // sentinelLocations true
            // hashedAssets tailnetPage
            // dataLocation true
            // telemetryLocations true
            // microvmProxyLocations true
            // stirlingProxyLocations
            // lib.optionalAttrs slidesEnabled (slideshowLocations true);
        };
      }
      # HTTPS vhost — inert until `publicDomain` names a record that resolves
      # here. The IP-addressed :80 vhost above stays the default, so
      # `http://<ip>/healthz` keeps working as an edge probe independent of DNS.
      // lib.optionalAttrs (publicDomain != null) {
        ${publicDomain} = {
          # No explicit listen: enableACME/forceSSL emit both halves; a manual 443 listen
          # orphaned the :80 challenge (HTTP-01 404; Trap: note delphi-ops-traps).
          enableACME = true;
          forceSSL = true;
          root = "${publicPage}";
          locations =
            {
              "/" = {
                index = "index.html";
                tryFiles = "$uri $uri/ =404";
                # Anchored to / — unanchored, the rewrite ate every 404 and subpath
                # (2026-11-08; Trap: note delphi-ops-traps).
                extraConfig =
                  ''
                    if ($delphi_terminal) { rewrite ^/$ /terminal.txt last; }
                  ''
                  + staticCache.html
                  + siteHeader;
              };
              # The terminal edition itself. Listed even when a browser asks, so
              # a person who wants the text can have it at the same address.
              "= /terminal.txt" = {
                root = "${publicPage}";
                extraConfig =
                  ''
                    default_type "text/plain; charset=utf-8";
                    gzip_static on;
                    add_header Cache-Control "public, max-age=300" always;
                    add_header X-Content-Type-Options "nosniff" always;
                  ''
                  + siteHeader;
              };
            }
            // hashedAssets publicPage
            // healthzLocation false
            // sentinelLocations false
            // reconLocations
            # The agent-turn log, readable by anyone with the URL: the row carries
            # no prompt form and /api/prompt answers 403 there, so this mount can
            # publish the field and spend nothing.
            // lib.optionalAttrs (config.services.turnsDashboard.publicPort != null) {
              "/turns/" = {
                proxyPass = "http://127.0.0.1:${toString config.services.turnsDashboard.publicPort}/";
                extraConfig = ''
                  proxy_http_version 1.1;
                  proxy_set_header Connection "";
                  # SSE is the page: a buffering proxy delivers the log in bursts
                  # or not at all, and a short read timeout drops an idle stream.
                  proxy_buffering off;
                  proxy_cache off;
                  proxy_read_timeout 1h;
                  add_header Cache-Control "no-store";
                '';
              };
              "= /turns".extraConfig = "return 301 /turns/;";
            }
            // microvmProxyLocations false
            // stirlingPublicRedirect
            // lib.optionalAttrs slidesEnabled (slideshowLocations false);
          # No harness location — the worker retired to the shadow file (Story: note
          # delphi-ops-traps); the fallback JSON route stays for manual checks.
        };
      };
  };

  # dsh-web retired to hosts/delphi/dsh-web.shadow.nix; the import stays for a
  # one-uncomment revive (Story: note delphi-ops-traps).

  # --- System One decision engine (Julia-1 / Laya) ----------------------------
  # The engine is stdlib Python (no torch, no model weights at runtime): its
  # profiles describe the architectures, and `query`/`triage-*` answer locally in
  # milliseconds. That is why it belongs on an aarch64 2-core VM as much as on
  # eisen: fleet decisions stay available when the home hosts are busy or asleep.
  # exp-120 carries the missing piece (a serve mode for other agents).
  services.systemoneDecision = {
    enable = true;
    defaultModel = "julia-1";
    # 8091 — 8090 is eisen's Laya; one port per mount (Fact: inventory.toml).
    serve = {
      enable = true;
      port = 8091;
    };
  };

  # Native, not the guest: A1 has no KVM and a JVM under TCG starved the 2-OCPU
  # box (Story: note delphi-ops-traps). The empty guest-path fragments below
  # stay for the flag-flip.
  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = "7351";
      # Loopback: the portal's 8445 mount is the only client, so the JVM (Spring's
      # `server.address`) has no reason to hold 0.0.0.0:7351.
      SERVER_ADDRESS = "127.0.0.1";
      SECURITY_ENABLELOGIN = "false";
      JAVA_TOOL_OPTIONS = "-Xms128m -Xmx512m -XX:+UseG1GC -XX:SoftRefLRUPolicyMSPerMB=50";
    };
  };
  systemd.services.stirling-pdf.serviceConfig = {
    MemoryHigh = "640M";
    MemoryMax = "768M";
  };

  # Private Meta-Search Engine (SearXNG on Tailnet)
  services.searx = {
    enable = true;
    redisCreateLocally = true;
    settings = {
      server.port = 8888;
      server.bind_address = "127.0.0.1";
      server.secret_key = "delphi-searxng-salt-secret";
      search.safe_search = 0;
      # `json` is the agent-facing route: flake/epistemics.nix declares the
      # tailnet SearXNG as the unmetered, fan-out transport for `web`, and a
      # program cannot read the HTML page. NixOS defaults to html only, which is
      # why the endpoint answered 403 on `format=json` until this line.
      search.formats = ["html" "json"];
    };
  };

  # uptime-kuma retired 2026-11-26: zero monitors, a second empty dashboard
  # beside `services.fleetMonitors`, which is where the checks live. The :8448
  # mount went with it (Story: docs/service-offload.md, docs/delphi-runtime.md).

  # --- Miniflux: the reading, not the mail queue -----------------------------
  # Every newsletter that publishes a feed belongs here instead of the inbox:
  # subscribing is a click, unsubscribing is a sender gone from the list, and
  # nothing arrives that has to be triaged. BASE_URL is the tailnet origin (not
  # the loopback port) because Miniflux puts it in feed URLs and login links.
  # The database is created by the module (`createDatabaseLocally`) on the
  # postgres this host already runs for the mail archive.
  sops.secrets."miniflux/admin_password" = {
    sopsFile = ../../modules/secrets.yaml;
    mode = "0400";
  };
  # `EnvironmentFile` format is ADMIN_USERNAME=… / ADMIN_PASSWORD=…, which is
  # why this is a template and not the raw secret.
  sops.templates."miniflux-admin.env" = {
    mode = "0400";
    content = ''
      ADMIN_USERNAME=admin
      ADMIN_PASSWORD=${config.sops.placeholder."miniflux/admin_password"}
    '';
  };
  services.miniflux = {
    enable = true;
    config = {
      # 8093 is the agent-turns shim — miniflux lost it once (EADDRINUSE, 2026-11-06);
      # 8098 is the next free port (Fact: docs/delphi-runtime.md; Story: note delphi-ops-traps).
      LISTEN_ADDR = "127.0.0.1:8098";
      # mounts are a sequential namespace — 8453/8454 zettel+mataroa (Fact: docs/delphi-runtime.md).
      BASE_URL = "https://${tailnetHost}:8455";
    };
    adminCredentialsFile = config.sops.templates."miniflux-admin.env".path;
  };

  # --- Umami: first-party analytics for the fleet's own pages ----------------
  # Small enough to sit beside the other tailnet services, and it replaces a
  # third-party script on pages we own. APP_SECRET signs sessions; it is a sops
  # secret rather than a literal so the store never holds the signing key.
  sops.secrets."umami/app-secret" = {
    sopsFile = ../../modules/secrets.yaml;
    mode = "0400";
  };
  services.umami = {
    enable = true;
    settings = {
      HOSTNAME = "127.0.0.1";
      # NOT 8094 — media-relay's vhost owns it; the collision killed every vhost
      # (2026-11-07; Trap: note delphi-ops-traps).
      PORT = 8061;
      APP_SECRET_FILE = config.sops.secrets."umami/app-secret".path;
      DISABLE_TELEMETRY = true;
    };
  };

  # --- Radicale: calendar and contacts without a third-party token -----------
  # vdirsyncer, khal and DAVx5 already speak CalDAV, so this replaces the Google
  # OAuth round trip rather than competing with it. `owner_only` keeps every
  # principal inside its own collections; the htpasswd file is rendered at start
  # from a sops value, so no password hash lives in the store either.
  #
  # The client end is `accounts.calendar.accounts.radicale` in
  # `modules/calendar.nix`, and the phone is DAVx5 at the tailnet origin. A
  # server nobody subscribes to is the failure this pair is written against.
  sops.secrets."radicale/password" = {
    sopsFile = ../../modules/secrets.yaml;
    mode = "0400";
    # ExecStartPre runs as User= too — a root-owned 0400 file breaks the render
    # (Trap: note delphi-ops-traps).
    owner = config.services.radicale.user;
    group = config.services.radicale.group;
  };
  services.radicale = {
    enable = true;
    settings = {
      # Loopback only — the `tailscale serve` mount is the whole exposure. The
      # module's default would bind 0.0.0.0:5232 and rely on the firewall alone.
      server.hosts = ["127.0.0.1:5232"];
      auth = {
        type = "htpasswd";
        # A runtime file, not a state file: it is rendered from sops on every
        # start, so it belongs in the directory systemd hands the unit writable.
        htpasswd_filename = "/run/radicale/users";
        htpasswd_encryption = "bcrypt";
      };
      rights.type = "owner_only";
    };
  };
  # /var/lib/radicale arrives root-owned under a read-only / — RuntimeDirectory
  # makes it (preStart died 2026-11-06; Trap: note delphi-ops-traps).
  # with `Read-only file system`, then `Permission denied`, on every start).
  systemd.services.radicale.serviceConfig = {
    RuntimeDirectory = "radicale";
    RuntimeDirectoryMode = "0700";
  };
  systemd.services.radicale.preStart = lib.mkBefore ''
      umask 077
      ${lib.getExe' pkgs.apacheHttpd "htpasswd"} -nbB ${user.name} \
        "$(cat ${config.sops.secrets."radicale/password".path})" > /run/radicale/users
    # Seed the default collection: a CalDAV server with none served 302 + zero
    # calendars for nine days (Story: note delphi-ops-traps); checks:caldav needs
    # something to write.
      collections=/var/lib/radicale/collections/collection-root/${user.name}
      mkdir -p "$collections/personal"
      [ -f "$collections/personal/.Radicale.props" ] || printf '%s' \
        '{"tag": "VCALENDAR", "D:displayname": "Personal"}' > "$collections/personal/.Radicale.props"
  '';

  # One push server, one channel (topic `fleet`): static user because DynamicUser
  # cannot take a sops secret (Trap: note delphi-ops-traps); checks:ntfy proves
  # delivery end-to-end. Access closed — a guessable topic is a credential, so
  # anonymous publish/subscribe is denied and the one writer user authenticates
  # every send.
  users.groups.ntfy = {};
  users.users.ntfy = {
    isSystemUser = true;
    group = "ntfy";
    description = "ntfy push notification server";
  };
  sops.secrets."ntfy/fleet-password" = {
    sopsFile = ../../modules/secrets.yaml;
    key = "ntfy/fleet-password";
    owner = "ntfy";
    group = "ntfy";
    mode = "0400";
  };
  # The CLI needs the same file the server reads, and its own default path is
  # `/etc/ntfy/server.yml`, so `ntfy user add` and `ntfy access` need no flags.
  environment.etc."ntfy/server.yml".text = ''
    listen-http: 127.0.0.1:8096
    base-url: https://${tailnetHost}:8458
    behind-proxy: true
    cache-file: /var/lib/ntfy/cache.db
    cache-duration: 12h
    attachment-cache-dir: /var/lib/ntfy/attachments
    auth-file: /var/lib/ntfy/user.db
    auth-default-access: deny-all
  '';
  systemd.services.ntfy = {
    description = "ntfy push notification server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    # A push server has to come back on its own; it is not a job that retires.
    unitConfig."X-Fleet-Role" = "daemon";
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.ntfy-sh} serve --config /etc/ntfy/server.yml";
      ExecStartPost = pkgs.writeShellScript "ntfy-provision" ''
        set -euo pipefail
        NTFY_PASSWORD="$(cat ${config.sops.secrets."ntfy/fleet-password".path})" \
          ${lib.getExe pkgs.ntfy-sh} user add --ignore-exists --role=user fleet
        ${lib.getExe pkgs.ntfy-sh} access fleet fleet read-write
      '';
      User = "ntfy";
      Group = "ntfy";
      StateDirectory = "ntfy";
      StateDirectoryMode = "0700";
      Restart = "always";
      IPAddressAllow = "localhost";
      IPAddressDeny = "any";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      UMask = "0077";
    };
  };

  # --- Vikunja: tasks, with an API the agents can drive ---------------------
  # Replaces a paid subscription and speaks CalDAV, so due dates sit beside the
  # events in the same client. SQLite on the service's own state directory; the
  # JWT secret is an environment file, because `settings` is rendered into the
  # world-readable store.
  sops.secrets."vikunja/jwt-secret" = {
    sopsFile = ../../modules/secrets.yaml;
    mode = "0400";
  };
  # Root-owned 0400 is fine here: systemd reads `EnvironmentFile` before it
  # drops into the dynamic user, so the app never opens this path itself.
  sops.templates."vikunja.env" = {
    mode = "0400";
    content = ''
      VIKUNJA_SERVICE_JWTSECRET=${config.sops.placeholder."vikunja/jwt-secret"}
    '';
  };
  services.vikunja = {
    enable = true;
    # doCheck off: upstream suites are not this host's regression surface —
    # aarch64 CI capped at 60min twice (Story: note delphi-ops-traps).
    # with them off is the same artifact without the wait.
    package = pkgs.vikunja.overrideAttrs (_final: prev: {
      doCheck = false;
      frontend = prev.frontend.overrideAttrs (_: {doCheck = false;});
    });
    environmentFiles = [config.sops.templates."vikunja.env".path];
    frontendScheme = "https";
    frontendHostname = "${tailnetHost}:8459";
    address = "127.0.0.1";
    port = 8097;
  };

  # --- Agent turn coordination store ----------------------------------------
  # xs holds one summary per agent turn, so an agent can see who is working on
  # what, from which base commit, before it starts a parallel edit. The module
  # keeps the store on a Unix socket with no network namespace; the mount below
  # is the entire exposed surface, and the bearer token comes from sops. The
  # endpoint is coordination state, not a chat relay and not a merge authority.
  services.agentTurns.enable = true;
  # The outcome lane out of the log: a minutely watcher pushes changed turn
  # outcomes to the operator on Telegram (token is the `hermes` sops key,
  # aliased for this service — delphi's own bot keeps its `delphi-telegram`).
  # The shim is loopback on this host, so the poll needs no TLS or tailnet hop.
  services.xsNotify = {
    enable = true;
    url = "http://127.0.0.1:${toString config.services.agentTurns.port}/v1/events";
  };
  # One revocable token per external holder — no single machine carries the
  # fleet credential (Rule: note delphi-ops-traps).
  services.agentTurns.additionalTokens = [
    "agent-turns-token-netbook"
    "agent-turns-token-muse"
    "agent-turns-token-vesper"
    {
      name = "agent-turns-token-dashboard";
      owner = user.name;
      group = config.services.agentTurns.user;
      # Both ends read this file: the shim loads every token at start, and the
      # dashboard presents this one — owner-only left the shim unable to boot
      # (Trap: note delphi-ops-traps).
      mode = "0440";
    }
  ];

  # --- The turn log as a reading surface ------------------------------------
  # Read-only over the shim, plus one prompt box per turn that runs the same
  # `hermes -z` an operator would type. The mount below is the whole exposure.
  services.turnsDashboard.enable = true;
  # Public mount OFF: the exploration-phase demo, not a requirement. 8070 brings
  # back the unit and its nginx location together.
  # [[docs/turns-dashboard.md]]
  services.turnsDashboard.publicPort = null;
  # The store is the fleet's shared memory and it lives only here, so it gets a
  # nightly dump that leaves the host. 03:05 is inside frieren's maintenance
  # window and ahead of its 03:28 BurgerNAS and 03:30 local restic snapshots —
  # those are what actually carry the dumps off the box, this only lands them.
  services.agentTurns.backup = {
    enable = true;
    pushTo = "${user.name}@${config.fleet.inventory.hosts.frieren.network.tailscale_hostname}:/srv/backup/agent-turns/";
  };

  # --- Shelter for the services that moved off the NAS ------------------------
  # Paperless, Vaultwarden and Anki now run here; frieren keeps the copy that
  # makes a switch-back cheap. Three declarations, one per guarantee: mirror the
  # state nightly (a consistent SQLite snapshot, never rsync'd bytes), keep
  # pulling the scanner's drop folder that stayed on the NAS share, and record
  # what a cutover has to stop and what proves it worked.
  #
  # The push lands in frieren's restic window on purpose: 03:10 is after the
  # agent-turn export (03:05) and before the 03:28 BurgerNAS and 03:30 local
  # snapshots, so the same nightly chain that protects the NAS protects these.
  # `docs/service-offload.md` is the procedure; the note is `open-frieren-offload`.
  # The ingestion probe followed its service: it asserts the four paperless units
  # are active and that nothing has sat unconsumed past the stall threshold. It
  # matters more here than it did on frieren, because the drop folder is now
  # reached over the bridge (`ingest`) rather than being local.
  services.paperlessWatchdog = {
    enable = true;
    consumeDir = "/var/lib/paperless/consume";
  };

  services.offloadBridge = {
    enable = true;
    host = "${user.name}@${config.fleet.inventory.hosts.frieren.network.tailscale_hostname}";

    sets = {
      paperless = {
        path = "/var/lib/paperless";
        sqlite = ["db.sqlite3"];
      };
      vaultwarden = {
        path = "/var/lib/vaultwarden";
        sqlite = ["db.sqlite3"];
      };
      # The vault's own sqlite-consistent dump, written by its backup unit.
      vaultwarden-backup.path = "/var/backup/vaultwarden";
      anki.path = "/var/lib/anki-sync-server";
    };

    ingest.paperless = {
      from = "${user.name}@${config.fleet.inventory.hosts.frieren.network.tailscale_hostname}:/srv/data/paperless/consume/";
      to = "/var/lib/paperless/consume/";
    };

    migrate = {
      paperless = {
        stopSource = ["paperless-web" "paperless-task-queue" "paperless-consumer" "paperless-scheduler"];
        stopTarget = ["paperless-web" "paperless-task-queue" "paperless-consumer" "paperless-scheduler"];
        countSql = "select count(*) from documents_document";
        healthUrl = "http://127.0.0.1:28981/";
      };
      vaultwarden = {
        stopSource = ["vaultwarden"];
        stopTarget = ["vaultwarden"];
        countSql = "select count(*) from users";
        healthUrl = "http://127.0.0.1:8222/alive";
      };
      anki = {
        stopSource = ["anki-sync-server"];
        stopTarget = ["anki-sync-server"];
      };
    };
  };

  # --- Tailnet-only HTTPS mounts, from ONE registry --------------------------
  # Each mount is a `tailscale serve` https front for a loopback listener; the
  # portal card is generated from the same declaration, so the service list on
  # the tailnet page cannot drift from the mounts that exist. Ports are checked
  # for collisions, upstreams for being loopback, and `requires` for naming a
  # unit that exists — see `modules/services/service-portal.nix`.
  services.servicePortal = {
    enable = true;
    title = "delphi";
    subtitle = "OCI Ampere A1 · aarch64-linux · NixOS · tailnet DNS 10.99.0.53";
    groups = ["Tailnet services"];
    inherit tailnetHost;
    # The exposure registry above is the firewall surface, not a card source:
    # those ports are reached by frieren's nginx under the `*.frieren.lan`
    # names, while the cards here are the `tailscale serve` mounts. Different
    # audiences, so no card is derived from the registry.
    includeExposure = false;
    telemetry = {
      enable = true;
      targets = {
        job-db = {
          baseUrl = "http://127.0.0.1:${toString config.services.jobDbScraper.port}";
          metrics = [
            {
              key = "active_postings";
              label = "active postings";
            }
            {
              key = "companies";
              label = "companies";
            }
            {
              key = "remote";
              label = "remote";
            }
          ];
        };
        private-deals = {
          baseUrl = "http://127.0.0.1:${toString config.services.privateDeals.port}";
          metrics = [
            {
              key = "deals";
              label = "deals";
            }
            {
              key = "products";
              label = "products";
            }
            {
              key = "alerts_pending";
              label = "alerts pending";
            }
          ];
        };
        inventory-site = {
          baseUrl = "http://127.0.0.1:${toString config.services.inventorySite.port}";
          metrics = [
            {
              key = "items";
              label = "items";
            }
            {
              key = "locations";
              label = "locations";
            }
            {
              key = "warranty_expiring_90d";
              label = "warranty ≤90d";
            }
          ];
        };
        clanker-runner = {
          baseUrl = "http://127.0.0.1:${toString config.services.clankerRunner.port}";
          metrics = [
            {
              key = "total_jobs";
              label = "jobs";
            }
            {
              key = "running_jobs";
              label = "running";
            }
            {
              key = "failed_jobs";
              label = "failed";
            }
          ];
        };
        link-vault = {
          baseUrl = "http://127.0.0.1:${toString config.services.linkVault.port}";
          metrics = [
            {
              key = "bookmarks";
              label = "bookmarks";
            }
            {
              key = "read";
              label = "read";
            }
            {
              key = "tags";
              label = "tags";
            }
          ];
        };
      };
    };
    mounts =
      {
        # dsh card retired with the harness — hosts/delphi/dsh-web.shadow.nix (note delphi-ops-traps).
        systemone = {
          port = 8444;
          upstream = "http://127.0.0.1:8091";
          title = "System One decisions";
          description = "POST /v1/systemone — the state+questions → answers envelope.";
          requires = ["systemone-decision-serve.service"];
        };
        pdf = {
          port = 8445;
          upstream = "http://127.0.0.1:7351";
          title = "Stirling PDF";
          description = "PDF merge, split, OCR and conversion (native ARM64).";
          requires = ["stirling-pdf.service"];
        };
        portal = {
          port = 8446;
          upstream = "http://127.0.0.1:8082";
          title = "Service portal";
          description = "This page, served only on the tailnet.";
          requires = ["nginx.service"];
          # The page lists the mounts; listing its own mount is noise.
          hideCard = true;
        };
        search = {
          port = 8447;
          upstream = "http://127.0.0.1:8888";
          title = "SearXNG";
          description = "Private, ad-free meta-search engine on the tailnet.";
          requires = ["searx.service"];
        };
        miniflux = {
          port = 8455;
          upstream = "http://127.0.0.1:8098";
          title = "Miniflux";
          description = "Feed reader: the newsletters that do not need to be mail.";
          requires = ["miniflux.service"];
        };
        umami = {
          port = 8456;
          upstream = "http://127.0.0.1:8061";
          title = "Umami";
          description = "First-party analytics for pages we own; no third-party script.";
          requires = ["umami.service"];
        };
        radicale = {
          port = 8457;
          upstream = "http://127.0.0.1:5232";
          title = "Radicale";
          description = "CalDAV and CardDAV: calendars and contacts without a third-party token.";
          requires = ["radicale.service"];
        };
        ntfy = {
          port = 8458;
          upstream = "http://127.0.0.1:8096";
          title = "ntfy";
          description = "Push to the phone, topic fleet, one sops user and anonymous denied. The appflow sync publishes a parked question here; gatus pages through the SimpleX bridge.";
          requires = ["ntfy.service"];
        };
        vikunja = {
          port = 8459;
          upstream = "http://127.0.0.1:8097";
          title = "Vikunja";
          description = "Tasks with CalDAV and a REST API, in place of a paid service.";
          requires = ["vikunja.service"];
        };
        email-archive = {
          port = 8450;
          upstream = "http://127.0.0.1:8080";
          title = "Email archive";
          description = "NpgsqlRest over the mail archive: full-text search, uploads, file-system handlers.";
          requires = ["npgsqlrest.service"];
          # NpgsqlRest has no page at `/` (404), so it is not a card: the archive is
          # browsed through `mail-atlas`, and the endpoint is machine-facing.
          hideCard = true;
        };
        # 8451 — reserved for the archive's document benchmark (Fact: docs/delphi-runtime.md).
        mail-atlas = {
          port = 8452;
          upstream = "http://127.0.0.1:${toString config.services.mailAtlas.port}";
          title = "Mail atlas";
          description = "The archive as a field: fuzzy finding, a tag taxonomy and a relation graph.";
          requires = ["nginx.service"];
        };
        # A reading surface with a prompt box per turn, so it is a card: this is
        # the page a person opens, and the inventory link points at the same port.
        turns = {
          port = 8460;
          upstream = "http://127.0.0.1:${toString config.services.turnsDashboard.port}";
          title = "Agent turns";
          description = "The turn log as a field: one panel per turn, live, with a Hermes prompt on each.";
          requires = ["turns-dashboard.service"];
        };
        # Machine-facing: POST /v1/events and GET /v1/events, bearer token, no
        # browsing surface, so no card on the tailnet page.
        agent-turns = {
          port = 8449;
          upstream = "http://127.0.0.1:${toString config.services.agentTurns.port}";
          title = "Agent turns (xs)";
          description = "Append-only agent-turn coordination store; bearer token required.";
          requires = ["agent-turns-shim.service"];
          hideCard = true;
        };
        # The blog as files: the ledger, the editor, and a publish that is a
        # deployment rather than the only copy. Same shape as the zettel mount —
        # the port is the module's, because the origin a write is checked against
        # is `https://<tailnetHost>:<port>`.
        mataroa = {
          port = config.services.mataroaConsole.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.mataroaConsole.port}";
          title = "Mataroa console";
          description = "Posts as markdown files; publish and unpublish against mataroa.blog.";
          requires = ["mataroa-console.service"];
        };
        # The pipeline, from the archive: stage counts, a search over company,
        # role and next action, and the record behind a click. The vhost proxies
        # five GET reads plus the two POST write routes (application-update,
        # application-upsert) so agents can write records through the tailnet
        # mount — no auth on any of it.
        appflow = {
          # The tailnet port is not the vhost's: `tailscale serve` and nginx both
          # bind, and sharing a number puts them on the same socket.
          port = 8463;
          upstream = "http://127.0.0.1:${toString config.services.appflowBoard.port}";
          title = "Job pipeline";
          description = "Applications and their mail, read and written through the archive database.";
          requires = ["nginx.service"];
        };
        job-db = {
          port = config.services.jobDbScraper.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.jobDbScraper.port}";
          title = "Job database";
          description = "Scraped postings, deduplicated into SQLite FTS5: search, source health and a JSON API.";
          requires = ["job-db-scraper.service"];
        };
        private-deals = {
          port = config.services.privateDeals.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.privateDeals.port}";
          title = "Private deals";
          description = "Tracked products, deal watchlists and price history in SQLite FTS5, with search and a JSON API.";
          requires = ["private-deals.service"];
        };
        inventory-site = {
          port = config.services.inventorySite.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.inventorySite.port}";
          title = "Inventory";
          description = "Fleet hardware and personal assets: locations, tags, serials, warranties, value and FTS5 search.";
          requires = ["inventory-site.service"];
        };
        clanker-runner = {
          port = config.services.clankerRunner.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.clankerRunner.port}";
          title = "Clanker runner";
          description = "InstaBox VM state, wake and exec triggers, Nix/agent-browser jobs and FTS5 run history.";
          requires = ["clanker-runner.service"];
        };
        link-vault = {
          port = config.services.linkVault.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.linkVault.port}";
          title = "Link vault";
          description = "Bookmark and research archive with extracted page text, tags, collections, states and FTS5 search.";
          requires = ["link-vault.service"];
        };
        # The dsh dashboard, back on its retired port — hosts/delphi/dsh-web.shadow.nix
        # named 8443 the harness's home and nothing else has taken it.
        dsh = {
          port = 8443;
          upstream = "http://127.0.0.1:${toString config.services.dshFreeModels.webPort}";
          title = "Free models";
          description = "dsh dashboard for the free-model roster (DeepSeek V4.1 Flash, Kimi K3, ...).";
          requires = ["dsh-free-models.service"];
        };
        # Machine-facing: OpenAI-compatible /v1, api-key gated (minted at first
        # run under ~/.dsh/openai-gateway/). No card — a client reads this, not a browser.
        free-models = {
          port = 8327;
          upstream = "http://127.0.0.1:${toString config.services.dshFreeModels.gatewayPort}";
          title = "Free-model gateway";
          description = "OpenAI-compatible relay; the bearer key lives in ~/.dsh/openai-gateway/api-key.";
          requires = ["dsh-free-models.service"];
          hideCard = true;
        };
      }
      // lib.optionalAttrs (lib.hasAttr "zettelGraph" config.services) {
        # Read, write and publish. The service is loopback; this mount, behind the
        # tailnet, is the whole exposure. The port is the module's, because the
        # origin a write is checked against is `https://<tailnetHost>:<port>` and a
        # second literal here is how that check starts rejecting the open page.
        zettel = {
          port = config.services.zettelGraph.tailnetPort;
          upstream = "http://127.0.0.1:${toString config.services.zettelGraph.port}";
          title = "Zettel graph";
          description = "The vault as a reader: notes, their web, edits and PDF publishing.";
          requires = ["zettel-graph.service"];
        };
      }
      // lib.optionalAttrs (lib.hasAttr "media-relay" config.services) {
        # The library, not a player: a browse page with fuzzy search over the files,
        # plus Range support a player can stream from. The vhost binds loopback and
        # the library lives on this host's disk, so this mount is the whole exposure
        # — there is no firewall row and no public counterpart.
        media = {
          port = 8461;
          upstream = "http://127.0.0.1:${toString config.services.media-relay.port}";
          title = "Media relay";
          description = "Fetched media, range-served: fuzzy search over the library, YouTube search with thumbnails, and a field that queues a fetch.";
          requires = ["nginx.service"];
        };
      };
    entries.gatus = {
      title = "Fleet monitors (external vantage)";
      description = "Gatus checks that watch frieren from outside its LAN, on the tailnet IP.";
      group = "Tailnet services";
      audience = "tailnet";
      external = true;
      href = "http://${tailnetIp}:8181";
      badge = "${tailnetIp}:8181";
    };
  };

  # Model credential: the turn dies MISSING_CREDENTIAL without it. Rendered
  # 0400 — never in the store or argv. The sopsFile must live in the TRACKED
  # flake (Trap: note delphi-ops-traps); fleet hosts share keys, agents get their own.
  sops.secrets."deepseek/api/key" = {
    sopsFile = ../../modules/secrets.yaml;
    key = "deepseek/api/key";
    owner = user.name;
    group = "users";
    mode = "0400";
  };
  sops.templates."dsh-web.env" = {
    owner = user.name;
    group = "users";
    mode = "0400";
    content = ''
      DEEPSEEK_API_KEY=${config.sops.placeholder."deepseek/api/key"}
    '';
  };

  # ACME client settings only exist when a cert is actually being requested.
  security.acme = lib.mkIf (publicDomain != null) {
    acceptTerms = true;
    defaults.email = user.email;
  };

  # Same shape as frieren's sync: shallow clone, worktree, quiet 04:00 commit,
  # force-with-lease push to a branch fleet peers ff. Staggered +30min so the
  # two hosts never push in one window. Plain `github:` — the tarball fetcher
  # rejects submodules=1 and git fetchers need root creds the box lacks (Trap:
  # note delphi-ops-traps). A dirty checkout is invisible: the 04:00 `git add -A`
  # would fold it into the snapshot.
  system.autoUpgrade = {
    enable = true;
    flake = "github:shaoyanji/nixconfig#delphi";
    # `--upgrade` only updates root's `nixos` channel; it is a no-op for a flake
    # system (the unit already warns "no channels to update") and channels are
    # disabled fleet-wide. The github: ref is fetched fresh on every run.
    upgrade = false;
    dates = "04:30";
    allowReboot = true;
    persistent = true;
  };

  # profiles.hermes: CLI, ~/.hermes, sops-rendered creds and the gateway unit.
  # secrets.yaml + telegramSecret must exist BEFORE first switch —
  # sops-install-secrets aborts activation (Trap: note delphi-ops-traps);
  # the file lands via `task infra:secrets:edit:secrets`.
  profiles.hermes = {
    enable = true;
    gateway.enable = true;
    telegramSecret = "delphi-telegram";
    # No SimpleX identity here — alerting rides frieren's bridge (Fact: inventory.toml).
    simplex.daemon = false;
  };

  # globalModulesContainers (noDE) switches the AI CLI stack OFF for container
  # hosts, and that stays off here: hermes is the exception, not a reason to
  # install Chromium/qmd/agent-browser. The gateway units follow `enable` (set by
  # profiles.hermes); seeding the persona is this host's own declaration.
  home-manager.users.${user.name} = {
    imports = [self.modules."services.mail-agent"];
    # `programs.edgeCaller` is NOT enabled here, and the reason is arithmetic, not
    # taste: flake/daemons.nix scores it ev = -1.1 s (p=0.5, save=-1.0, cost=1.2)
    # against the agent naming the pattern itself, and
    # [[flake/policies.nix#daemon-clears-kelly]] refuses a resident helper whose
    # best case is a loss. It was activated here on 2026-11-02 and switched off the
    # same day; the module stays for the pipeline path (agents:call:batch).
    # `nix eval --json .#daemons.daemons` prints the current numbers.
    programs.hermes-user = {
      persona = true;
    };
    # Plain-English triage over the himalaya account, plus a nightly sweep of
    # bulk mail. Dry run unless --apply; no delete tool exists. docs/mail-agent.md
    programs.mailAgent = {
      enable = true;
      account = "jisifu";
      sweep = {
        mode = "apply";
        # Marketing senders only. A dry run over the real inbox is what earned
        # each one; anything not listed is held for review, never archived.
        trustedSenders = [
          "mail.gocity.com"
          "hello@ollama.com"
          "steampowered.com"
          "redditmail.com"
          "email.openai.com"
          "tryhackme.com"
        ];
      };
    };
    # gh uses HTTPS token auth (Fact: inventory.toml).
    programs.gh.settings.git_protocol = lib.mkForce "https";
  };

  # User lingering: without it the per-user systemd manager only exists while
  # devji has a session, so hermes-gateway (a --user unit) would stop at logout
  # and never start at boot. On frieren this was set by hand (`loginctl
  # enable-linger`); declaring it here is what makes a headless agent host
  # actually run its agent. scoped to this host deliberately — the fleet has no
  # blanket linger policy, and desktop hosts do not need one.
  users.users.${user.name}.linger = true;

  # Public door on the one port OCI's edge admits besides ssh/http (Fact:
  # inventory.toml — ingress is 22/80/443 only). Every login runs the hop;
  # no shell, no guest credential handed out.
  users.users.slides = lib.mkIf slidesHopEnabled {
    isNormalUser = true;
    description = "Terminal deck over ssh (forced command hops into the sandbox microVM)";
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
    # The hop keypair is group-readable by design; this account is its only member.
    extraGroups = [microvmGuest.sshHopGroup];
  };

  # AuthorizedPrincipalsFile lives under /var/lib — an /etc store symlink fails
  # StrictModes and the list silently empties (Trap: note delphi-ops-traps).
  # "none" means the login name; the fleet principal also accepts the CA's own
  # certs, so no wildcard is needed.
  systemd.tmpfiles.rules = lib.mkIf slidesHopEnabled [
    "d /var/lib/ssh-deck 0755 root root -"
    # `\\n` is a literal backslash-n: tmpfiles turns it into the trailing
    # newline sshd expects, while a real newline would end the rule early.
    "f+ /var/lib/ssh-deck/principals 0644 root root - ${user.name}\\n"
  ];

  # Last block in sshd_config, which is where `extraConfig` lands and the only
  # place a Match may appear.
  services.openssh.extraConfig = lib.mkIf slidesHopEnabled ''
    Match User slides
      ForceCommand ${slidesHopCommand}
      AuthorizedPrincipalsFile /var/lib/ssh-deck/principals
      AllowTcpForwarding no
      AllowAgentForwarding no
      X11Forwarding no
      PermitTunnel no
  '';

  # --- OCI Serial Console & Early Kernel Logging ---
  # Allows debugging boots via OCI Cloud Shell / Console Connection.
  boot.kernelParams = [
    "console=ttyAMA0,115200"
    "console=tty0"
    "earlycon"
  ];

  # --- Headless logging footprint --------------------------------------------
  # The journal cap is a fleet default (modules/global/global.nix).
  # profiles/server-hardening.nix stays unimported: it bind-mounts /var/log to a
  # NAS path and ships /etc/pihole tmpfiles for a user this host never creates.
  boot.tmp.cleanOnBoot = true;

  # --- Headless Server Packages & Lightweight Base Closure ---
  # Keep the base closure small: btop and helix instead of baking a heavy
  # Neovim/Nixvim closure into every system generation.
  environment.systemPackages = with pkgs; [
    btop
    helix
    tmux
    git
    curl
    wget
    rsync
    jq
    ripgrep
    fd
    # Resolver/route debugging without installing a toolkit.
    dnsutils
    iproute2
    tcpdump
    gh
    antigravity-cli
    # The same binary's Gemini API key route: `agy-gemini` sets modelProvider=gemini
    # for one session, so Hydrogen runs without touching the account route.
    self.packages.${pkgs.stdenv.hostPlatform.system}.cli.ai.agy-gemini
    llm-agents.freebuff
    freebuff-headless
    # Autonomous Cloud Workspace Seeder: sets up ~/Documents/nixconfig and ~/vaults/personal
    # directly from upstream GitHub via GitHub CLI / HTTPS, avoiding missing SSH key blocks.
    # Never clone over a notes checkout: flake/policies.nix#seeder-never-clones-over-notes.
    (let
      delphi-seed = writeShellApplication {
        name = "delphi-seed-workspace";
        runtimeInputs = [
          git
          gh
          openssh
          coreutils
        ];
        text = ''
                set -euo pipefail
                echo "=== [delphi] Seeding Autonomous Cloud Workspace ==="
                mkdir -p "$HOME/Documents" "$HOME/vaults"

                # The credential helper belongs to `programs.gh`, not to this file; a second
                # `!gh` entry shadowed it under a thin PATH. Why:
                # docs/nix-patterns.md §"Agent failure modes".
                if [ "$(git config --file "$HOME/.gitconfig" --get url.https://github.com/.insteadOf || true)" != "git@github.com:" ]; then
                  git config --file "$HOME/.gitconfig" url."https://github.com/".insteadOf "git@github.com:"
                fi
                for scope in github.com gist.github.com; do
                  git config --file "$HOME/.gitconfig" --unset-all "credential.https://$scope.helper" || true
                done

                REPO="$HOME/Documents/nixconfig"
                if [ ! -d "$REPO/.git" ]; then
                  echo "--> Cloning nixconfig to $REPO (with recursive submodules)..."
                  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                    gh repo clone https://github.com/shaoyanji/nixconfig "$REPO" -- --recurse-submodules
                  else
                    git clone --recurse-submodules https://github.com/shaoyanji/nixconfig.git "$REPO"
                  fi
                else
                  # Same read-before-write as the vault below: compare with origin
                  # first (ls-remote writes nothing) and pull only on real drift, so a
                  # checkout already at origin/main costs no fetch.
                  if [ "$(git -C "$REPO" config --get url.https://github.com/.insteadOf || true)" != "git@github.com:" ]; then
                    git -C "$REPO" config url."https://github.com/".insteadOf "git@github.com:"
                  fi
                  branch=$(git -C "$REPO" branch --show-current)
                  here=$(git -C "$REPO" rev-parse HEAD)
                  there=$(git -C "$REPO" ls-remote origin "refs/heads/$branch" 2>/dev/null | cut -f1)
                  if [ -z "$branch" ]; then
                    echo "--> $REPO has no branch checked out (detached HEAD); not pulling" >&2
                  elif [ -z "$there" ]; then
                    echo "--> could not read origin ($branch) to compare; leaving $REPO as-is" >&2
                  elif [ "$here" = "$there" ]; then
                    echo "--> $REPO is current at $(printf '%.8s' "$here") ($branch)"
                  elif [ "$there" = "$(git -C "$REPO" rev-parse "refs/remotes/origin/$branch" 2>/dev/null || true)" ]; then
                    # origin has not moved since the last fetch, so the only commits
                    # here are local ones: a pull could not bring anything in.
                    echo "--> $REPO is ahead of origin/$branch (local $(printf '%.8s' "$here")); not pulling"
                  else
                    echo "--> $REPO drifted: local $(printf '%.8s' "$here") -> origin $(printf '%.8s' "$there"); pulling"
                    git -C "$REPO" pull --recurse-submodules ||
                      echo "--> pull did not complete cleanly (see above); $REPO left as-is" >&2
                  fi
                  # `submodule sync` and `update` rewrite every submodule's config
                  # even when nothing is out of place, so they run only when one is
                  # missing or pinned wrong ('-' uninitialised, '+' out of sync).
                  pending=$(git -C "$REPO" submodule status --recursive 2>/dev/null | grep -c '^[-+]' || true)
                  if [ "$pending" -gt 0 ]; then
                    git -C "$REPO" submodule sync --recursive || true
                    git -C "$REPO" submodule update --init --recursive ||
                      echo "--> submodule update failed; $REPO may be missing a submodule" >&2
                  fi
                fi

          # Seed = clone-if-absent + fast-forward, never touching a current one — the
          # vault is a repository (an earlier mkdir-only seed left notes "missing",
          # 2026-10-26; Story: note delphi-ops-traps). Never clone over notes:
          # flake/policies.nix#seeder-never-clones-over-notes.
                VAULT="$HOME/vaults/personal"
                VAULT_REPO=shaoyanji/Obsidian-Git-Sync
                if [ -d "$VAULT/.git" ]; then
                  # `git config` rewrites .git/config even when the value already
                  # matches, so the rewrite is only written when it is absent.
                  if [ "$(git -C "$VAULT" config --get url.https://github.com/.insteadOf || true)" != "git@github.com:" ]; then
                    git -C "$VAULT" config url."https://github.com/".insteadOf "git@github.com:"
                  fi
                  branch=$(git -C "$VAULT" branch --show-current)
                  here=$(git -C "$VAULT" rev-parse HEAD)
                  # ls-remote only reads: no FETCH_HEAD, ORIG_HEAD or config is
                  # written. Counting commits behind would need the objects a fetch
                  # writes, so drift is reported as the two revisions.
                  there=$(git -C "$VAULT" ls-remote origin "refs/heads/$branch" 2>/dev/null | cut -f1)
                  if [ -z "$branch" ]; then
                    echo "--> $VAULT has no branch checked out (detached HEAD); left as-is" >&2
                  elif [ -z "$there" ]; then
                    echo "--> could not read $VAULT_REPO ($branch) to compare; $VAULT left as-is" >&2
                  elif [ "$here" = "$there" ]; then
                    echo "--> $VAULT is current at $(printf '%.8s' "$here") ($branch)"
                  else
                    echo "--> $VAULT drifted: local $(printf '%.8s' "$here") -> remote $(printf '%.8s' "$there"); fast-forwarding"
                    git -C "$VAULT" pull --ff-only --quiet ||
                      echo "--> vault pull did not fast-forward (local commits or dirty tree); left as-is" >&2
                  fi
                elif [ -d "$VAULT" ] && [ -n "$(ls -A "$VAULT" 2>/dev/null)" ]; then
            # Never clone over a notes checkout — [[flake/policies.nix#seeder-never-clones-over-notes]]; the vault is a repository.
                  echo "--> $VAULT holds files but is not a git checkout; refusing to clone over it." >&2
                else
                  echo "--> Cloning the vault from $VAULT_REPO into $VAULT..."
                  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                    gh repo clone "$VAULT_REPO" "$VAULT" -- --quiet ||
                      echo "--> vault clone failed; left $VAULT empty" >&2
                  else
                    mkdir -p "$VAULT"
                    echo "--> gh not authenticated; initialized $VAULT empty."
                  fi
                fi

                echo "=== [delphi] Workspace ready at ~/Documents/nixconfig ==="
        '';
      };
    in
      runCommand "delphi-workspace-seeders" {} ''
        mkdir -p "$out/bin"
        ln -s "${delphi-seed}/bin/delphi-seed-workspace" "$out/bin/delphi-seed-workspace"
        ln -s "${delphi-seed}/bin/delphi-seed-workspace" "$out/bin/seed-workspace"
      '')
  ];

  # agy-daemon-web retired — the cascade drives `agy -p` headless (Story: note delphi-ops-traps).

  # Modal editor defaults (Catppuccin Mocha theme, relative line numbers).
  # This nixpkgs revision has no NixOS programs.helix module, so helix comes
  # from environment.systemPackages above and the config is deployed
  # system-wide via the XDG config search path (/etc/xdg).
  environment.variables.EDITOR = "hx";

  environment.etc."xdg/helix/config.toml".text = ''
    theme = "catppuccin_mocha"

    [editor]
    line-number = "relative"

    [editor.cursor-shape]
    insert = "bar"
    normal = "block"
    select = "underline"
  '';

  # Ephemeral / on-demand Neovim runner from kickstart.nixvim flake:
  # full IDE functionality on demand without permanently inflating the VM
  # closure (see PART V of the fleet closure policy).
  programs.bash.shellAliases = {
    nvim = "nix run github:shaoyanji/kickstart.nixvim --";
    vim = "helix";
    seed-workspace = "delphi-seed-workspace";
  };

  system.stateVersion = "25.05";
}
