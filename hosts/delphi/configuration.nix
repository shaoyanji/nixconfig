# delphi — Oracle Cloud Infrastructure (OCI) Ampere A1 ARM64 headless server.
{
  self,
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
  # Home: docs/delphi-install.md §"Phase 4d — the 10.99.0.53 failover pair"; docs/dns-failover.md.
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
  # Home: docs/delphi-install.md §"Phase 4c — HTTPS (done 2026-10-20)".
  publicDomain = let
    d = hostMeta.network.domain;
  in
    if d == ""
    then null
    else d;

  # DeepSeek Harness, tailnet only: tailscaled terminates TLS and forwards to the
  # loopback app, so the harness is unreachable from the internet. 8443 because
  # nginx owns 0.0.0.0:443. Runbook: .agents/deploy/hosts/delphi.md §"DeepSeek
  # Harness (tailnet only)".
  tailnetHost = "${hostMeta.network.tailscale_hostname}.${hostMeta.network.tailnet_domain}";
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

  # The public name hands a command-line client the terminal edition of the
  # dossier (`terminalDoc` in lib/delphi-site.nix) instead of the HTML, which a
  # program can neither read usefully nor colour.
  #
  # A POSITIVE match on known clients, not "anything that is not Mozilla":
  # invert the test and a crawler, a link unfurler or a monitoring probe also
  # gets plain text, and those are most of the audience the HTML page exists for.
  # A client not listed here gets the HTML, which is the safe default; curl and
  # nushell are the two that made this worth doing, and the rest are the same
  # kind of client met later.
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

  # The utility-layer recon report (hosts/delphi/reports/), published from the
  # store so a regeneration is a rebuild rather than a file dropped on the box.
  # `no-store` on purpose: the URL is stable and the content moves with the
  # generation, so a cached copy would be a stale report about fast-moving models.
  reconReport = pkgs.writeTextDir "index.html" (builtins.readFile ./reports/utility-layer-recon.html);
  reconLocation = {
    alias = "${reconReport}/";
    extraConfig = ''
      autoindex off;
      add_header Cache-Control "no-store";
    '';
  };
  # `/recon` without the slash matches no location prefix, so it fell through to
  # the site root's `try_files` and answered 404. A named exact match redirects
  # instead of relying on alias-implied 301 behaviour, which `alias` does not do.
  reconRedirect = ''return 301 /recon/;'';

  # The gate that makes this name inert on the public internet even though the
  # tailnet vhost listens on the same 0.0.0.0:80: the client's 100.64/10
  # address on tailscale0 is the allow-list.
  tailnetOnly = ''
    allow 127.0.0.1;
    allow ::1;
    allow 100.64.0.0/10;
    deny all;
  '';

  # The location fragments more than one vhost repeats, defined once. Each takes
  # the tailnet gate as a parameter because a `location` inherits nothing from
  # its server block, and the same path answering on one name but not another is
  # how the dossier and the console start disagreeing.
  # The trailing newline keeps the gated fragment's shape when it is
  # concatenated in front of an indented string, so the generated config is
  # byte-identical to the hand-written form this replaced.
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
  # Content-hashed assets are immutable, so they get the one-year policy
  # (modules/config/nginx-static-cache.nix) rather than the HTML revalidate.
  # Eight explicit hex classes: a `{8}` brace quantifier is emitted SPLIT across
  # lines by the config generator and nginx rejects the whole server for it.
  hashedAssets = root: {
    "~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
      inherit root;
      extraConfig = staticCache.hashed;
    };
  };

  # The two machine surfaces, for a TUI, a probe or an agent that wants the
  # structure instead of scraping HTML: the compiled dossier (`site` in
  # lib/delphi-site.nix) and the portal's card list. TAILNET ONLY, and that is a
  # rule rather than caution — the dossier JSON carries `identity.tailnetIp` and
  # `identity.tailnetUrl`, which the public page is built never to print, so the
  # machine surface sits behind the same gate as the console, not beside the
  # dossier.
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
    self.modules."services.fleet-monitors"
    self.modules."services.mataroa-console"
    self.modules."services.media-relay"
    self.modules."services.offload-bridge"
    self.modules."services.paperless-watchdog"
    self.modules."services.service-portal"
    self.modules."services.systemone-decision"
    self.modules."services.turns-dashboard"
  ];

  # --- YouTube relay: fetch where the peering is good, serve over the tailnet ---
  # Why, and what is still unproven (the home-side figure was measured while the
  # uplink was saturated): `docs/media-relay.md`.
  services.media-relay.enable = true;

  # --- the job pipeline as a page ---
  # Reads the mail hub's own tables through four read-only routes; it stores
  # nothing and is not a writer. The single-writer cutover is the appflow turn
  # (`appflow-single-writer`), and this page is its consumer.
  services.appflowBoard.enable = true;

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
      assertion = hostMeta.network.tailnet_domain != "";
      message = "inventory.toml [hosts.delphi.network]: `tailnet_domain` is required — the MagicDNS name is `tailscale_hostname` + `tailnet_domain`.";
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

  # No `profiles.cachePush` here, deliberately. A post-build-hook fires for every
  # locally built output and runs as nix-daemon, so on this 2-vCPU guest a switch
  # that builds anything turns into a NAR re-compress + upload per derivation,
  # with the copies outliving the rebuild that started them. What delphi needs is
  # the other direction: SUBSTITUTION from cachix, so an artifact CI already
  # built for github is fetched instead of compiled here. That is a read, and it
  # costs this host nothing — `config.fleet.inventory.cache.delphi` already lists
  # shaoyanji.cachix.org in the WAN tier, so `nix.settings.substituters` carries
  # it with no token and no hook.

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
      #
      # Third is envs.net (157.180.15.214, Hetzner DE): the only upstream here
      # that publishes that it keeps no query log, and a host this fleet already
      # trusts with mail. Measured 2026-11-05 from this box — 21 ms RTT, DNSSEC
      # validating (dnssec-failed.org SERVFAILs), no filtering (doubleclick.net
      # resolves to its real addresses), so it blocks nothing the blocklist
      # below does not and needs no exemption. Ordered last on purpose: the
      # anycast primaries answer in ~1 ms and cache misses are the only traffic
      # that reaches any of these, so it is a privacy and diversity fallback,
      # not a primary. A fourth would start costing failover time, not buying it.
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

  # --- The tailnet firewall surface, from ONE registry ----------------------
  # Every port this host opens on the mesh, declared once and scoped to
  # `tailscale0`, each value read from the option that owns it so a moved service
  # cannot leave a stale row behind. Two rows were pruned 2026-11-09: 53/tcp
  # (crab-hole has no TCP downstream) and 3012/tcp (vaultwarden 1.30 serves
  # websockets on ROCKET_PORT; `./vaultwarden.nix` carries the measurement).
  # Instrument: `task checks:ports HOST=delphi IFACE=tailscale0`.
  profiles.serviceExposure = {
    enable = true;
    interfaces = ["tailscale0"];
    services = {
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
      # The three services that moved off the NAS. frieren's nginx is their only
      # client, over the tailnet — never the LAN, which this host does not have.
      paperless = {
        port = config.services.paperless.port;
        lan = false;
        tailnet = true;
      };
      vaultwarden = {
        port = config.services.vaultwarden.config.ROCKET_PORT;
        lan = false;
        tailnet = true;
      };
      anki-sync = {
        port = config.services.anki-sync-server.port;
        lan = false;
        tailnet = true;
      };
    };
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
      # The NAS's own services, probed across the tailnet since frieren's gatus
      # was retired on 2026-11-04. Each port is one frieren's
      # `profiles.serviceExposure` registry already opens on tailscale0, so a
      # probe cannot outlive the hole it needs; audiobookshelf has no exposed
      # port, only its vhost, and is probed by name.
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
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # `map` is an http-level directive, so it cannot live inside a vhost. The
    # variable is read by the public vhost's root location, which is why the
    # match list above is host-level and not location-level.
    commonHttpConfig = ''
      map $http_user_agent $delphi_terminal {
        default 0;
        "${terminalUa}" 1;
      }
    '';

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
            // dataLocation false;
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
                # `rewrite … last` re-matches to the exact location below, so a
                # client that will not follow a 302 (`curl` without `-L`) still
                # gets the document in one request. Anchored to the root: an
                # unanchored pattern served the terminal page in place of every
                # 404 and every real subpath a CLI client asked for (measured
                # 2026-11-08 on `/data/delphi.json`).
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

  # --- Stirling PDF: native here, the guest's copy is off ---------------------
  # The history is the reason the shape looks odd. It ran natively from
  # 2026-10-21, moved into the sandbox guest on 2026-10-24 with `stirling = true`
  # (a state volume and a restart that is a decision, not a boot side effect),
  # and came back the same week: OCI A1 has no KVM, so that guest runs under
  # interpreted TCG, and a JVM there cost more CPU than the 2-OCPU box has.
  # `flake/host-inventory.nix` now passes `stirling = false`, and this native
  # copy is what answers — the portal's 8445 mount proxies it.
  #
  # So `stirlingProxyLocations` / `stirlingPublicRedirect` below are empty on
  # this host: they are the guest path, kept for the host that flips the flag
  # back, not a second live surface. The live one is the mount.
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

  # External Fleet & WAN Status Monitor (Uptime Kuma on Tailnet)
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
    };
  };

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
      # 8093 belongs to the agent-turns shim: miniflux bound it first and then
      # lost every start to EADDRINUSE once the shim held it (2026-11-06). 8098
      # is the next free loopback port in this block.
      LISTEN_ADDR = "127.0.0.1:8098";
      # 8453/8454 are zettel-graph and mataroa; the mounts are a sequential
      # namespace, so the reading pair continues at 8455.
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
      # NOT 8094: media-relay's vhost owns 127.0.0.1:8094 on this host, and an
      # umami on the loopback of the same port made nginx fail at bind — every
      # vhost on delphi was down for as long as this unit was up (measured
      # 2026-11-07: `bind() to 0.0.0.0:8094 failed (98)`, nginx start-limit-hit).
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
  sops.secrets."radicale/password" = {
    sopsFile = ../../modules/secrets.yaml;
    mode = "0400";
    # The unit's ExecStartPre runs as this user (`User=` applies to it too), so
    # root-owned 0400 would make the htpasswd render fail every start.
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
  # The unit runs with a read-only /, so the htpasswd render needs a directory
  # it owns: `/var/lib/radicale` is root-owned and the module's StateDirectory
  # claims only the collections below it (measured 2026-11-06: the preStart died
  # with `Read-only file system`, then `Permission denied`, on every start).
  systemd.services.radicale.serviceConfig = {
    RuntimeDirectory = "radicale";
    RuntimeDirectoryMode = "0700";
  };
  systemd.services.radicale.preStart = lib.mkBefore ''
    umask 077
    ${lib.getExe' pkgs.apacheHttpd "htpasswd"} -nbB ${user.name} \
      "$(cat ${config.sops.secrets."radicale/password".path})" > /run/radicale/users
  '';

  # --- ntfy: the fleet's alerts, on a phone ----------------------------------
  # Gatus and fleet-sentinel could only toast on a desktop. Topics are guessed
  # easily, so the mount stays on the tailnet and `base-url` is the tailnet
  # origin: the phone subscribes there, not to ntfy.sh.
  # There is no `services.ntfy-sh` in this nixpkgs pin, so the unit is declared
  # here. Flags rather than a config file: the whole configuration is four
  # values, and a YAML file generated into the store would say nothing more.
  systemd.services.ntfy = {
    description = "ntfy push notification server";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    # A push server has to come back on its own; it is not a job that retires.
    unitConfig."X-Fleet-Role" = "daemon";
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${lib.getExe pkgs.ntfy-sh} serve"
        "--listen-http 127.0.0.1:8096"
        "--base-url https://${tailnetHost}:8458"
        # TLS ends at tailscaled, so the forwarded headers are the only truth
        # about scheme and client address.
        "--behind-proxy"
        "--cache-file /var/lib/ntfy/cache.db"
        "--attachment-cache-dir /var/lib/ntfy/attachments"
      ];
      DynamicUser = true;
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
    # Upstream's own test suites are not this host's regression surface; the
    # binary is. Running them cost the aarch64 CI job its whole 60-minute cap
    # twice (2026-11-06), with the frontend suite still going. Building here
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
  # One revocable token per holder outside this repo's agents: the netbook, muse,
  # and vesper. Each authenticates to the same shim and is revoked on its own, so
  # no single machine carries the fleet credential.
  services.agentTurns.additionalTokens = [
    "agent-turns-token-netbook"
    "agent-turns-token-muse"
    "agent-turns-token-vesper"
    # The dashboard is the one reader that runs as the login user: its prompts
    # are that operator's Hermes turns, so it reads a token of its own rather
    # than the store's (which stays 0400 between two service users).
    {
      name = "agent-turns-token-dashboard";
      owner = user.name;
      group = config.services.agentTurns.user;
      # Both ends read this file: the shim loads every token at start, and the
      # dashboard presents this one. Owner-only would leave the shim unable to
      # boot (measured 2026-11-06: start-limit-hit, exit 1, no log line).
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
        description = "Push notifications for gatus and fleet-sentinel, straight to the phone.";
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
      # 8451 stays reserved for the rival archive benchmark; this is the reading
      # surface over the same database, with its own loopback vhost so `/api` is
      # same-origin for the browser.
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
      # The pipeline, read from the archive: stage counts, a search over company,
      # role and next action, and the record behind a click. Read-only by
      # construction — the vhost proxies four GET routes and nothing else, so the
      # plugin's write endpoints are not reachable through this mount.
      appflow = {
        # The tailnet port is not the vhost's: `tailscale serve` and nginx both
        # bind, and sharing a number puts them on the same socket.
        port = 8463;
        upstream = "http://127.0.0.1:${toString config.services.appflowBoard.port}";
        title = "Job pipeline";
        description = "Applications and their mail, read from the archive database.";
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
  # Plain `github:` again, and the submodule question is why. That fetch is a
  # tarball: it carries only the submodule's gitlink, and the fetcher rejects a
  # `submodules=1` parameter outright (measured: "unknown parameter
  # 'submodules'"). The git fetchers that do support the flag would clone
  # `git@github.com:shaoyanji/secrets` as root, and root here has no git config,
  # no key and no gh login — so the flag cannot be the fix by itself.
  # What actually broke the 2026-10-26 upgrade was the only eval-time reader of
  # that submodule: `profiles.cachePush`'s `sopsFile`. The push is gone, nothing
  # in this host's closure references `modules/secrets/`, and the tarball
  # evaluates. CI keeps `?submodules=1` because it fetches a git tree, not this.
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

          # SSH URLs are rewritten to HTTPS here. The credential helper is NOT set
          # here: home-manager's `programs.gh` already renders an absolute-path
          # helper into ~/.config/git/config, and a second PATH-dependent `!gh`
          # entry in ~/.gitconfig shadowed it — under a thin PATH every git fetch
          # logged `gh: command not found` before the absolute helper still
          # authenticated (delphi, minyx-keeper journal). Unset rather than skip,
          # so a host that already carries the stale pair converges.
          # `git config` rewrites the file even when the value already matches,
          # so the rewrite is written only when it is absent.
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

          # The vault is a repo, not a directory: an earlier version only
          # mkdir'd this path, so a reseeded host came up with an empty vault
          # and every note was "missing" until someone cloned it by hand
          # (delphi 2026-10-26). Clone it when it is absent, and fast-forward it
          # when it is behind — a seed is a sync, not just a first-run clone —
          # while a current vault is left with .git byte-identical.
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
            # Never clone over notes. This happens when the old mkdir-only path
            # (or Obsidian itself, pointed here by nixoshmsymlinks) left files
            # with no .git; the operator decides, the seeder does not delete.
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
