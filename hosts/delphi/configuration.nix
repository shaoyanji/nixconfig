# delphi — Oracle Cloud Infrastructure (OCI) Ampere A1 ARM64 headless server.
{
  pkgs,
  config,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;

  # The address the whole tailnet points its DNS at (see the route group below).
  # Both this host and frieren bind it on lo and advertise it as the SAME /32,
  # which makes Tailscale treat them as one active/passive failover group: one
  # node answers, and the route moves when it disappears (~15 s).
  #
  # Deliberately NOT a 100.64/10 tailnet member address: a /32 subnet route is
  # the only way to give clients ONE resolver address backed by several hosts.
  # Tailscale does not fail over between two global nameservers, so listing
  # "frieren then delphi" would just break DNS when the first one dies.
  dnsServiceAddress = "10.99.0.53";

  # Registry facts, not constants: `inventory.toml` carries the public name and
  # the tailnet address, and the dossier below reads the same values. A host that
  # moves one address cannot leave its own page pointing at the old one.
  hostMeta = config.fleet.inventory.hosts.delphi;

  # Public HTTPS name. null = the box serves plain HTTP on :80 only.
  #
  # Setting this is the ONLY thing needed to bring up TLS, and it belongs here
  # rather than in a manual step: `enableACME` issues and renews a Let's Encrypt
  # cert over HTTP-01 (port 80, now reachable), `forceSSL` adds the :80→:443
  # redirect, and nginx reloads on renewal. The one part nixconfig cannot own is
  # the DNS A record — and a wrong or missing record turns every renewal into a
  # failing unit, so do not set this before the name resolves to the instance's
  # RESERVED public IP (an ephemeral IP changes on stop/start).
  #
  # `""` (the registry's "unknown") becomes null, or `lib.optionalAttrs` would
  # generate a vhost with an empty `server_name`.
  publicDomain = let
    d = hostMeta.network.domain;
  in
    if d == ""
    then null
    else d;

  # DeepSeek Harness, TAILNET ONLY. tailscaled terminates TLS for the MagicDNS
  # name with a certificate no public client can present, and forwards to the
  # same loopback app — so the harness is not reachable from the internet at
  # all. That matters because the only gate out there was a bearer token, and
  # the worker runs as a user that holds the fleet SSH CA key.
  #
  # Mounted at the root: no prefix to strip, so the proxy is a plain
  # pass-through and the session cookie is keyed to exactly one authority
  # (`tailnetHost:servePort`).
  #
  # 8443 on purpose. nginx owns 0.0.0.0:443 for the public landing page, and a
  # listener on the tailnet address at 443 fails while that bind exists
  # (measured: "bind: address already in use").
  # The tailnet suffix is fleet-wide and typed once per host that needs it; the
  # node name is a registry fact.
  tailnetHost = "${hostMeta.network.tailscale_hostname}.cloudforest-kardashev.ts.net";
  # Stable per node key, and the only address that works here: delphi runs
  # `--accept-dns=false` (a resolver must not resolve through the address it
  # serves), so a MagicDNS name does not resolve from inside this host.
  tailnetIp = hostMeta.network.tailscale_ip;
  servePort = 8443;
  dshPort = 3080;
  dshPath = "/";
  dshUrl = "https://${tailnetHost}:${toString servePort}/";

  # Both landing pages, from ONE compiled site (`lib/delphi-site.nix`): the
  # public dossier and the tailnet console are two projections of a single
  # evaluated structure, so a count on the dossier and the card list on the
  # console cannot disagree. The dossier's facts come from the registry, the
  # knowledge graph and `services.servicePortal.cards` — the same declaration
  # that generates the `tailscale serve` units.
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

  # Which store path a vhost is serving, said by the vhost itself. A deploy can
  # finish and still leave the previous generation's tree in place (a boot-only
  # activation, a rollback, a flake ref that did not move), and from outside both
  # look identical — so a staleness gate asks the server instead of the journal.
  # The value is the SITE, not the `public`/`tailnet` root under it, so the gate
  # compares against `.#delphi-site.outPath` byte for byte and every vhost can be
  # probed with the same expectation.
  # It belongs in each `location`: a location that sets its own `add_header` (the
  # cache policy does) does not inherit the server's.
  siteHeader = ''add_header X-Site-Path "${delphiSite}" always;'';

  # One cache policy for compiled static trees, shared with frieren's vhosts
  # (modules/config/nginx-static-cache.nix) so the two hosts cannot disagree
  # about how long a store path may be cached.
  staticCache = import ../../modules/config/nginx-static-cache.nix;

  # The gate that makes this name inert on the public internet even though the
  # tailnet vhost listens on the same 0.0.0.0:80: the client's 100.64/10
  # address on tailscale0 is the allow-list.
  tailnetOnly = ''
    allow 127.0.0.1;
    allow ::1;
    allow 100.64.0.0/10;
    deny all;
  '';

  # Stub services in the sandbox microVM, generated from the guest declaration
  # (hosts/microvms/guests.nix) so the address and the port pair are not typed
  # a second time here. `withGate` adds the tailnet allow-list, which locations
  # do not inherit from the server block.
  microvmGuest = config.microvmGuests.sandbox;
  microvmProxyLocations = withGate: let
    proxies = lib.listToAttrs (map (svc: {
        name = "/microvm/${svc.name}/";
        value =
          {
            # Trailing slash on both sides: /microvm/<name>/x -> upstream /x.
            proxyPass = "http://${microvmGuest.address}:${toString svc.port}/";
          }
          // lib.optionalAttrs withGate {extraConfig = tailnetOnly;};
      })
      microvmGuest.services);
  in
    proxies
    // lib.optionalAttrs (microvmGuest.services != []) {
      # Bare /microvm is the namespace, not a page: send it to the first stub.
      "= /microvm".extraConfig =
        (lib.optionalString withGate tailnetOnly)
        + ''return 301 /microvm/${(lib.head microvmGuest.services).name}/;'';
    };

  # Stirling holds whatever a document tool holds, so it is tailnet-only on both
  # vhosts — unlike the stubs, which are public by design. The tailnet name
  # proxies it behind the allow-list; the public name redirects there instead of
  # answering 403 from a gate a public client can never satisfy.
  #
  # Stirling knows its own prefix (SERVER_SERVLET_CONTEXT_PATH), so the path is
  # passed through unchanged instead of being stripped like a stub's.
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

  # The deck (hosts/microvms/slideshow.md) is a terminal app — `slides` over ssh
  # into the guest — so its web surface is an address card, not the show. This
  # gives /slideshow a real page before anything renders, and names both ways in
  # from the same declaration that created the account and the forward.
  # `slideshow.bountystash.com` can point at this path later.
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

  # The public ssh door to the deck. The edge carries 22 and nothing else new: a
  # rule for 2222 is the tenancy's to add, and it is not ours to make from inside
  # (instance principals are unauthorised in this compartment). So the public
  # path reuses 22 — a host account whose whole login is a hop into the guest,
  # where the deck's own forced command lives. The client holds a fleet key that
  # the host already accepts; the guest credential never leaves this machine.
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

  # Same treatment as /microvm/: locations inherit nothing from the server
  # block, so the tailnet gate is repeated in each one.
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
    ./hardware-configuration.nix
    ./infra-stack.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/firewall-baseline.nix
    ../../modules/profiles/hermes.nix
    ../../modules/profiles/operator-tools.nix
    ../../modules/profiles/sops-user-identity.nix
    ../../modules/net/dns/tailnet-address.nix
    ../../modules/services/dsh-web.nix
    ../../modules/services/fleet-monitors.nix
    ../../modules/services/service-portal.nix
    ../../modules/services/systemone-decision.nix
  ];

  # 10.99.0.53 on lo + the /32 advertised below form one half of the failover
  # group; frieren runs the same module and advertises the same route.
  # (Setting only `.address` does nothing — the bind is behind `enable`.)
  # No `advertiseRoutes` here: delphi is a resolver and exit node, not a subnet
  # router for a LAN it does not have.
  profiles.tailnetDnsAddress = {
    enable = true;
    address = dnsServiceAddress;
    exitNode = true;
  };

  # The two public surfaces are compiled from these registry fields, so an empty
  # one would ship a vhost with no `server_name` and a console whose cards point
  # at `.cloudforest-kardashev.ts.net`. Fail at eval instead.
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
      assertion = hostMeta.network.tailscale_ip != "";
      message = "inventory.toml [hosts.delphi.network]: `tailscale_ip` is required for the console and the monitor card.";
    }
  ];

  # --- The gate toolchain -----------------------------------------------------
  # This box runs `task checks:*` (it is where delphi's own gates are cheapest to
  # run), so the tools those tasks call from PATH belong in the closure rather
  # than in an ad-hoc `nix shell`: `toon` for `checks:toon`, `python3` for
  # `ops:tailnet:policy` and the site preview helpers. Neither is an AI/dev stack
  # — `globalModulesContainers` keeps that off here on purpose.
  # `browser` stays off: `checks:kg:canvas` already skips its click step when
  # `agent-browser` is absent, and ~700 MB for one optional half is a deliberate
  # trade rather than a default.
  profiles.operatorTools = {
    enable = true;
    browser = false;
  };

  # --- User-plane sops identity ----------------------------------------------
  # base-node.nix gives the NixOS plane the host key (root can read it). Home
  # Manager activation runs as devji and needs a user-readable identity file,
  # and this host has no `~/.ssh/id_ed25519` — logins are CA certificates. The
  # activation derives it from the host key, which yields exactly the `&delphi`
  # recipient already in .sops.yaml: no extra key, no rekey, nothing to back up.
  # Out of scope for frieren/fern, which use the TPM identity path.
  profiles.sopsUserIdentity.enable = true;

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
      # A resolver must never resolve THROUGH the address it serves: that is an
      # outage loop (the VRRP analogue is why net/dns/failover.nix probes
      # 127.0.0.1 and not the floating IP). crab-hole's own upstreams are DoT.
      "--accept-dns=false"
      # `--advertise-exit-node` and the `/32` route are emitted by
      # net/dns/tailnet-address.nix (`exitNode = true`), not here.
    ];
  };

  # The lo bind itself lives in net/dns/tailnet-address.nix (shared with
  # frieren, which advertises the same /32 as the passive member).

  # --- Tailnet resolver: crab-hole -------------------------------------------
  # Chosen over the pihole-ftl + unbound stack in net/dns/failover.nix:
  # that module is built around a LAN interface and keepalived VRRP, neither of
  # which exists on a cloud host. crab-hole is one Rust binary, keeps the same
  # StevenBlack + Disconnect lists frieren blocks, and speaks plain DNS on 53.
  #
  # It listens on 0.0.0.0 rather than a hardcoded tailnet IP: the IP is assigned
  # by Tailscale at login and would otherwise have to be baked in. The firewall
  # (not the bind address) is what limits it to the tailnet.
  #
  # LIMIT, measured 2026-10-20: crab-hole is a forwarding ad-blocker, not an
  # authoritative server — its config has blocklist/downstream/upstream/api and
  # no static-record or zone support (LuckyTurtleDev/crab-hole). It therefore
  # answers the internet but NOT the fleet's `*.frieren.lan` wildcard, so while
  # the shared `10.99.0.53/32` route sits on this node every fleet name returns
  # NODATA. `task ops:tailnet:dns` fails on exactly this, and
  # docs/dns-failover.md lists the three fixes (split DNS for the zone is the
  # cheap one; a dnsmasq zone front-end is the equivalent-resolver one).
  services.crab-hole = {
    enable = true;
    # openFirewall would open 53 globally; the scoped interface rule below is
    # the only intended path in.
    openFirewall = false;
    settings = {
      # UDP only, and that is a crab-hole limitation, not a choice: v0.1.12
      # takes `udp|tls|https|quic` for a downstream protocol and has no plain
      # `tcp` variant (the build-time validate-config rejects it). Consequence:
      # no DNS-over-TCP on 53, so a truncated answer cannot be retried over TCP
      # and very large TXT chains will fail. Everything else resolves normally.
      downstream = [
        {
          listen = "0.0.0.0";
          port = 53;
          protocol = "udp";
        }
      ];
      # DoT upstreams, IPv4 only: OCI free-tier instances have no IPv6 uplink,
      # and a resolver that prefers IPv6 root/upstream servers SERVFAILs every
      # lookup (the 2026-10-14 frieren outage, same failure class).
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
      ];
      # Same two lists frieren's pihole-ftl uses, so a failover answer is the
      # answer the client would have got from the primary.
      blocklist = {
        include_subdomains = true;
        lists = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
          "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
        ];
      };
      # Loopback only; there is no crab-hole web UI to expose.
      api = {
        listen = "127.0.0.1";
        port = 8081;
        show_doc = false;
      };
    };
  };

  # DNS and the monitor dashboard arrive over the tailnet only. 53 and 8181 are
  # deliberately absent from the global allowedTCPPorts/allowedUDPPorts: a port
  # open to the internet is exactly what this host's whole posture is about.
  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [
      53
      8181
    ];
  };

  # --- Fleet monitors, from OUTSIDE the LAN ---------------------------------
  # frieren's own gatus cannot see a home-WAN outage: it probes loopback. This
  # instance is the other vantage point — everything on delphi probes 127.0.0.1,
  # and the frieren checks go over the tailnet, so "delphi can reach frieren" is
  # a fact about the internet path and frieren's tailnet ingress, not about the
  # LAN switch.
  #
  # `modules/services/fleet-monitors.nix` owns the mechanism (gatus plus the
  # monitor definitions as Nix state); this block is only the endpoint list.
  # Alerting stays off: the SimpleX bridge points at 127.0.0.1:5225, and this
  # host runs no SimpleX daemon.
  services.fleetMonitors = {
    enable = true;
    # Bound to all interfaces because the tailnet address is assigned at login
    # and must not be baked in; the tailscale0 firewall rule above is the only
    # way in. Reached at http://100.123.145.53:8181/ from a tailnet client.
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
      # No DNS endpoint on purpose. crab-hole v0.1.12 has no TCP listener on 53
      # (its downstream protocols are udp|tls|https|quic), so `tcp://…:53` is
      # refused and reports a permanent red — a monitor that can never go green
      # is worse than none. A real assertion needs a `dns://` endpoint with a
      # query name, which `services.fleetMonitors` does not model yet; until it
      # does, the resolver is proven by `dig @10.99.0.53 example.com`.
      # Tailnet IP, not MagicDNS: delphi runs `--accept-dns=false` (a resolver
      # must not resolve through the address it serves), so names do not resolve
      # here. The address is stable per node key.
      {
        name = "frieren portal (tailnet)";
        url = "http://100.97.61.65/";
        group = "frieren";
        conditions = ["[STATUS] < 400"];
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
    ];
  };

  # crab-hole owns port 53, so resolved must not squat on it: the wildcard bind
  # in `downstream` collides with the 127.0.0.53 stub and the unit fails with
  # EADDRINUSE. Point the host's own resolution at the local resolver instead.
  services.resolved.settings.Resolve = {
    DNSStubListener = "no";
    LLMNR = false;
  };
  networking.networkmanager.dns = lib.mkForce "none";
  networking.nameservers = [
    "127.0.0.1"
    "::1"
  ];

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
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # One definition of `virtualHosts`, because a module may not set the same
    # attribute path twice: the TLS vhost is merged in with `//` rather than
    # declared as a second `services.nginx.virtualHosts = …`.
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
          locations."/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ =404";
            extraConfig = staticCache.html + siteHeader;
          };
          # Content-hashed assets are immutable, so they get the one-year policy
          # (modules/config/nginx-static-cache.nix) rather than the HTML revalidate.
          locations."~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
            root = "${publicPage}";
            extraConfig = staticCache.hashed;
          };
          # Plain-text liveness probe for gatus / curl / a browser tab.
          locations."= /healthz".extraConfig = ''
            default_type text/plain;
            return 200 "ok";
          '';
          # Closed-loop fleet sentinel observation ledger & health
          locations."/sentinel/" = {
            alias = "/var/lib/fleet-sentinel/www/";
            extraConfig =
              ''
                autoindex off;
                add_header Cache-Control "no-store";
              ''
              + siteHeader;
          };
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
          locations."/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ =404";
            extraConfig = staticCache.html + siteHeader;
          };
          locations."~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
            root = "${tailnetPage}";
            extraConfig = staticCache.hashed;
          };
        };

        # The MagicDNS name at the root, tailnet-only by SOURCE ADDRESS.
        #
        # 443 is owned by the public ACME vhost and tailscaled cannot take it
        # (measured 2026-10-21: "bind: address already in use"), so the console's
        # TLS entry point remains the :8446 mount. This vhost makes
        # `http://<tailnet name>/` work too: WireGuard already encrypts the mesh,
        # and the allow-list — the client's 100.64/10 address on tailscale0 — is
        # what makes the name inert on the public internet even though the
        # listener is the same :80.
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
              "= /healthz".extraConfig = ''
                ${tailnetOnly}
                default_type text/plain;
                return 200 "ok";
              '';
              "/sentinel/" = {
                alias = "/var/lib/fleet-sentinel/www/";
                extraConfig =
                  ''
                    ${tailnetOnly}
                    autoindex off;
                    add_header Cache-Control "no-store";
                  ''
                  + siteHeader;
              };
            }
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
          # No explicit `listen`: `enableACME`/`forceSSL` generate BOTH halves,
          # the :443 server and the :80 redirect that carries the ACME
          # challenge location. Declaring `listen 443 ssl` by hand left the
          # generated :80 block without a listen directive, so it landed in a
          # different listen group from the IP-addressed default vhost and no
          # request ever reached the challenge location — HTTP-01 answered 404
          # while the token sat in /var/lib/acme/acme-challenge.
          enableACME = true;
          forceSSL = true;
          root = "${publicPage}";
          locations =
            {
              "/" = {
                index = "index.html";
                tryFiles = "$uri $uri/ =404";
                extraConfig = staticCache.html + siteHeader;
              };
              # Same eight explicit hex classes as frieren's vhost: a `{8}` brace
              # quantifier is emitted SPLIT across lines by the config generator and
              # nginx rejects the whole server for it.
              "~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
                root = "${publicPage}";
                extraConfig = staticCache.hashed;
              };
              "= /healthz".extraConfig = ''
                default_type text/plain;
                return 200 "ok";
              '';
              "/sentinel/" = {
                alias = "/var/lib/fleet-sentinel/www/";
                extraConfig =
                  ''
                    autoindex off;
                    add_header Cache-Control "no-store";
                  ''
                  + siteHeader;
              };
            }
            // microvmProxyLocations false
            // stirlingPublicRedirect
            // lib.optionalAttrs slidesEnabled (slideshowLocations false);
          # Deliberately no harness location. The worker is tailnet-only (see
          # `tailscale-serve-dsh` below); publishing it here would put a
          # token-only gate in front of a user that holds the fleet SSH CA key.
        };
      };
  };

  # --- DeepSeek Harness, hosted HERE (NATIVE LANE), TAILNET ONLY --------------
  # Architectural Decision: Pinned to the NATIVE host lane. Delphi runs on an
  # OCI A1 ARM64 instance without KVM virtualization (EL2 unavailable), meaning
  # the sandbox microVM runs under interpreted QEMU TCG. Running an active agent
  # coding harness (bash executions, model orchestration, git workspaces) inside
  # TCG incurs severe interpreted CPU penalties and stalls the 2 OCPU budget.
  # Native host execution runs at bare-metal Ampere Altra speed with systemd
  # cgroup guards (CPUWeight=200, MemoryHigh=1200M) and direct SOPS key access.
  # The phantom guest volume reservation in hosts/microvms was retired.
  #
  # A client needs only a browser at `dshUrl`. The unit binds loopback and
  # `tailscale-serve-dsh` below is the only way in. `tailscale serve` preserves
  # the client's Host header (measured: `Host: delphi.<tailnet>.ts.net:8443`
  # reached the upstream verbatim), so that authority is both the /api fence
  # entry (`trustedHosts`) and the key the session cookie is minted for.
  services.dshWeb = {
    enable = true;
    user = user.name;
    port = dshPort;
    path = dshPath;
    publicUrl = dshUrl;
    trustedHosts = ["${tailnetHost}:${toString servePort}"];
    environmentFile = config.sops.templates."dsh-web.env".path;
  };

  # --- System One decision engine (Julia-1 / Laya) ----------------------------
  # The engine is stdlib Python (no torch, no model weights at runtime): its
  # profiles describe the architectures, and `query`/`triage-*` answer locally in
  # milliseconds. That is why it belongs on an aarch64 2-core VM as much as on
  # eisen: fleet decisions stay available when the home hosts are busy or asleep.
  # exp-120 carries the missing piece (a serve mode for other agents).
  services.systemoneDecision = {
    enable = true;
    defaultModel = "julia-1";
    # The envelope other agents call; mounted on the tailnet below. 8091 on
    # loopback because 8090 is eisen's Laya, and one port per proxy mount.
    serve = {
      enable = true;
      port = 8091;
    };
  };

  # --- Stirling PDF: the JVM lives in the sandbox guest, not on the host ------
  # Native copy retired 2026-10-24. Heavy, stateless apps belong in the guest
  # (hosts/microvms/guests.nix, `stirling = true`), which gives them a state
  # volume and a restart that is a decision rather than a boot side effect.
  # Running both meant two JVMs on one 2-core box: the guest's, plus this one,
  # for a service that receives no traffic. The guest is the survivor and is
  # served at /microvm/stirling/ (tailnet only).
  #
  # Kept disabled rather than deleted for posterity: this is the shape that ran
  # natively 2026-10-21..24, and the reference for a host with no microvm layer.
  # --- Native Services (Retiring QEMU TCG MicroVM bottleneck) ----------------
  # Native Stirling PDF (ARM64 native execution, sub-second responses, ~450 MB RAM)
  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = "7351";
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
    };
  };

  # External Fleet & WAN Status Monitor (Uptime Kuma on Tailnet)
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
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
    tailnetHost = tailnetHost;
    # No `profiles.serviceExposure` here: this host's exposure is the tailnet,
    # and the mounts below are the whole of it.
    includeExposure = false;
    mounts = {
      dsh = {
        port = servePort;
        upstream = "http://127.0.0.1:${toString dshPort}";
        title = "DeepSeek Harness";
        description = "Agent loop, bash, model calls and workspaces, in the browser.";
        requires = ["dsh-web.service"];
      };
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
      kuma = {
        port = 8448;
        upstream = "http://127.0.0.1:3001";
        title = "Uptime Kuma";
        description = "External fleet and home WAN status monitor.";
        requires = ["uptime-kuma.service"];
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

  # A model credential, not an account one: the harness's signed-in grant is
  # for the browser surface, while a turn resolves to the `deepseek-official`
  # route and dies with MISSING_CREDENTIAL without this key. Rendered 0400 for
  # the unit's user; never in the store, never on a command line.
  # The key lives in the TRACKED fleet file, not `modules/secrets/apikeys.yaml`:
  # that directory is outside the flake (delphi builds from `github:…` with no
  # submodules), so a `sopsFile` pointing there is a path that does not exist in
  # the store. The value was copied in from apikeys.yaml.
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

  # --- Unattended updates ----------------------------------------------------
  # Same shape as frieren, staggered by 30 min so the two never pull and build
  # at once (delphi has 2 cores; a simultaneous fetch on the home link would
  # just move the delay). `allowReboot` stages with `nixos-rebuild boot` and only
  # reboots when the kernel changed; `persistent` catches up after downtime.
  #
  # The `github:` ref is the pushed main branch — which is why nothing here is
  # built from a local tree: a dirty checkout is invisible to this job.
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

  # --- Hermes agent ----------------------------------------------------------
  # profiles.hermes installs the CLI, seeds ~/.hermes, renders the credential
  # file from sops and (with gateway.enable) declares the gateway unit.
  #
  # telegramSecret must exist in modules/secrets.yaml BEFORE the first switch:
  # sops-install-secrets fails activation for a missing key, which would abort
  # the install. Add it with `task infra:secrets:edit:secrets` first.
  profiles.hermes = {
    enable = true;
    gateway.enable = true;
    telegramSecret = "delphi-telegram";
    # delphi has no SimpleX identity; the daemon would just idle and retry.
    simplex.daemon = false;
  };

  # globalModulesContainers (noDE) switches the AI CLI stack OFF for container
  # hosts, and that stays off here: hermes is the exception, not a reason to
  # install Chromium/qmd/crush. The gateway units follow `enable` (set by
  # profiles.hermes); seeding the persona is this host's own declaration.
  home-manager.users.${user.name} = {
    programs.hermes-user = {
      persona = true;
    };
    # Delphi uses HTTPS with GitHub CLI token credentials rather than host SSH keys.
    programs.gh.settings.git_protocol = lib.mkForce "https";
  };

  # User lingering: without it the per-user systemd manager only exists while
  # devji has a session, so hermes-gateway (a --user unit) would stop at logout
  # and never start at boot. On frieren this was set by hand (`loginctl
  # enable-linger`); declaring it here is what makes a headless agent host
  # actually run its agent. scoped to this host deliberately — the fleet has no
  # blanket linger policy, and desktop hosts do not need one.
  users.users.${user.name}.linger = true;

  # --- The deck's public door, on the one port the edge already carries -------
  # Port 2222 reaches the guest directly from the tailnet, but OCI's ingress rules
  # admit only 22/80/443, so the public name gets a hop instead: this account has
  # no shell of its own — every login runs `slidesHopCommand`, which is an ssh
  # into the guest's `slides` account and therefore into the same forced command.
  # A client still needs a fleet key (the host's own authorized list); nothing
  # about the guest's credential is handed out.
  users.users.slides = lib.mkIf slidesHopEnabled {
    isNormalUser = true;
    description = "Terminal deck over ssh (forced command hops into the sandbox microVM)";
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
    # The hop keypair is group-readable by design; this account is its only member.
    extraGroups = [microvmGuest.sshHopGroup];
  };

  # A fleet client authenticates with a certificate whose principal is the user
  # name (`modules/ssh-ca.nix` signs `-n devji`), so it never matches a `slides`
  # login on its own: `AuthorizedPrincipalsFile none` means "the login name,
  # exactly". Listing the fleet principal for this one account accepts exactly
  # the certificates the CA already issues — no wildcard, which sshd does not
  # support here — and the account still has no shell.
  #
  # A real file under /var/lib, not `environment.etc`: an /etc entry is a symlink
  # into /nix/store, and sshd's StrictModes rejects that path (the store is
  # group-writable), which silently leaves the principal list empty.
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
  # profiles/server-hardening.nix is deliberately NOT imported: it bind-mounts
  # /var/log and /var/cache to /srv/private (a NAS path) and ships an
  # /etc/pihole tmpfiles entry owned by a `pihole` user that a crab-hole host
  # has no reason to create — a failing tmpfiles unit on a fresh boot. The two
  # settings worth keeping are declared directly.
  services.journald.settings.Journal = {
    SystemMaxUse = "300M";
    RuntimeMaxUse = "200M";
    MaxRetentionSec = "1week";
  };
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
    llm-agents.freebuff
    freebuff-headless
    # Autonomous Cloud Workspace Seeder: sets up ~/Documents/nixconfig and ~/vaults/personal
    # directly from upstream GitHub via GitHub CLI / HTTPS, avoiding missing SSH key blocks.
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

          # Ensure git rewrites SSH URLs to HTTPS and uses gh credential helper without failing on read-only ~/.config/git/config
          git config --file "$HOME/.gitconfig" url."https://github.com/".insteadOf "git@github.com:"
          git config --file "$HOME/.gitconfig" credential."https://github.com".helper "!gh auth git-credential"
          git config --file "$HOME/.gitconfig" credential."https://gist.github.com".helper "!gh auth git-credential"

          if [ ! -d "$HOME/Documents/nixconfig/.git" ]; then
            echo "--> Cloning nixconfig to ~/Documents/nixconfig (with recursive submodules)..."
            if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
              gh repo clone https://github.com/shaoyanji/nixconfig "$HOME/Documents/nixconfig" -- --recurse-submodules
            else
              git clone --recurse-submodules https://github.com/shaoyanji/nixconfig.git "$HOME/Documents/nixconfig"
            fi
          else
            echo "--> ~/Documents/nixconfig already exists. Pulling latest..."
            git -C "$HOME/Documents/nixconfig" config url."https://github.com/".insteadOf "git@github.com:"
            git -C "$HOME/Documents/nixconfig" pull --recurse-submodules || true
            git -C "$HOME/Documents/nixconfig" submodule sync --recursive || true
            git -C "$HOME/Documents/nixconfig" submodule update --init --recursive || true
          fi

          if [ ! -d "$HOME/vaults/personal/.git" ]; then
            mkdir -p "$HOME/vaults/personal"
            echo "--> Initialized ~/vaults/personal."
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

  # 24/7 Remote Operator Gateway: Antigravity remote-control daemon (antigravity.google.com)
  systemd.user.services.antigravity-cli-daemon = {
    description = "antigravity remote-control daemon";
    after = ["network.target"];
    unitConfig = {
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "simple";
      Environment = [
        ''"SSH_CLIENT=127.0.0.1 1 1"''
        ''"SSH_CONNECTION=127.0.0.1 1 127.0.0.1 22"''
        "HOME=${user.home}"
        "USER=${user.name}"
        "PATH=${user.home}/.nix-profile/bin:/etc/profiles/per-user/${user.name}/bin:/run/current-system/sw/bin"
        "SHELL=/run/current-system/sw/bin/bash"
      ];
      ExecStart = "${pkgs.antigravity-cli}/bin/agy remote-control serve";
      Restart = "on-failure";
      RestartSec = "10s";
      RestartPreventExitStatus = 3;
      TimeoutStopSec = "30s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = ["default.target"];
  };

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
