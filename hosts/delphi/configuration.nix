# delphi — Oracle Cloud Infrastructure (OCI) Ampere A1 ARM64 headless server.
{
  pkgs,
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

  # Public HTTPS name. null = the box serves plain HTTP on :80 only.
  #
  # Setting this is the ONLY thing needed to bring up TLS, and it belongs here
  # rather than in a manual step: `enableACME` issues and renews a Let's Encrypt
  # cert over HTTP-01 (port 80, now reachable), `forceSSL` adds the :80→:443
  # redirect, and nginx reloads on renewal. The one part nixconfig cannot own is
  # the DNS A record — and a wrong or missing record turns every renewal into a
  # failing unit, so do not set this before the name resolves to the instance's
  # RESERVED public IP (an ephemeral IP changes on stop/start).
  publicDomain = "delphi.bountystash.com";

  # DeepSeek Harness mount. One pair of constants because three places have to
  # agree: the service's advertised root, the proxy's location, and the
  # launcher that opens it. The trailing slash is the prefix strip
  # (`proxy_pass http://…/`), not decoration.
  dshPort = 3080;
  dshPath = "/deepseek/";
  dshUrl = "https://${publicDomain}${dshPath}";

  # Static landing page. The point is proof of life (and the webserver
  # criterion), not a product: no CMS, no PHP, no runtime.
  healthPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>delphi</title>
        <style>
          body { background:#1e1e2e; color:#cdd6f4; font:16px/1.6 ui-monospace, monospace;
                 max-width:44rem; margin:12vh auto; padding:0 1.5rem; }
          h1 { color:#89b4fa; font-size:1.6rem; margin-bottom:.2rem; }
          .sub { color:#a6adc8; margin-top:0; }
          li { margin:.35rem 0; }
          code { color:#a6e3a1; }
        </style>
      </head>
      <body>
        <h1>delphi</h1>
        <p class="sub">OCI Ampere A1 &middot; aarch64-linux &middot; NixOS</p>
        <ul>
          <li><code>/healthz</code> — plain-text liveness probe</li>
          <li>tailnet DNS service address — <code>10.99.0.53</code> (crab-hole)</li>
          <li>mesh — Tailscale, exit node + <code>10.99.0.53/32</code> route</li>
        </ul>
      </body>
    </html>
  '';
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/firewall-baseline.nix
    ../../modules/profiles/hermes.nix
    ../../modules/profiles/sops-user-identity.nix
    ../../modules/profiles/tailnet-dns-address.nix
    ../../modules/services/dsh-web.nix
    ../../modules/services/fleet-monitors.nix
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
      # outage loop (the VRRP analogue is why profiles/dns-failover.nix probes
      # 127.0.0.1 and not the floating IP). crab-hole's own upstreams are DoT.
      "--accept-dns=false"
      # `--advertise-exit-node` and the `/32` route are emitted by
      # profiles/tailnet-dns-address.nix (`exitNode = true`), not here.
    ];
  };

  # The lo bind itself lives in profiles/tailnet-dns-address.nix (shared with
  # frieren, which advertises the same /32 as the passive member).

  # --- Tailnet resolver: crab-hole -------------------------------------------
  # Chosen over the pihole-ftl + unbound stack in profiles/dns-failover.nix:
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
  # `tailscale serve` is NOT an option for a second (tailnet) entry point:
  # nginx binds 0.0.0.0:443, so tailscaled cannot take the tailnet address on
  # 443 (measured 2026-10-21: "bind: address already in use"). A ts.net name
  # would need its own `tailscale cert` plus a vhost on this listener.
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
          root = "${healthPage}";
          locations."/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ =404";
          };
          # Plain-text liveness probe for gatus / curl / a browser tab.
          locations."= /healthz".extraConfig = ''
            default_type text/plain;
            return 200 "ok";
          '';
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
          root = "${healthPage}";
          locations."/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ =404";
          };
          locations."= /healthz".extraConfig = ''
            default_type text/plain;
            return 200 "ok";
          '';
          # DeepSeek Harness (services.dshWeb). `proxy_pass` with a trailing
          # slash strips `dshPath`; `Host $host` is load-bearing — dsh's /api
          # fence accepts only loopback, its own bind address, or an explicitly
          # trusted authority, and the session cookie it mints is keyed to that
          # same authority. `proxyWebsockets` is NOT on by default in this
          # nixpkgs (checked: false), and the whole UI rides one upgraded
          # socket, so it is set explicitly; the read timeout then covers an idle
          # harness socket, which nginx would otherwise cut at 60 s.
          locations."= ${lib.removeSuffix "/" dshPath}" = {
            return = "301 ${dshPath}";
          };
          locations."${dshPath}" = {
            proxyPass = "http://127.0.0.1:${toString dshPort}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_buffering off;
              proxy_read_timeout 1h;
            '';
          };
        };
      };
  };

  # --- DeepSeek Harness, hosted HERE -----------------------------------------
  # The harness (agent loop, bash, model calls, workspaces) runs on this host;
  # a client only needs a browser at `dshUrl`. The unit binds loopback and the
  # vhost above publishes it under `dshPath`, passing the client's Host through
  # — that authority is both the /api fence entry (`trustedHosts`) and the key
  # the session cookie is minted for.
  services.dshWeb = {
    enable = true;
    user = user.name;
    port = dshPort;
    path = dshPath;
    publicUrl = dshUrl;
    trustedHosts = [publicDomain];
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
  # install Chromium/qmd/crush. programs.hermes-user is gated on its own
  # `enable` + `hosts` list, so only the host list has to be extended.
  home-manager.users.${user.name}.programs.hermes-user = {
    # The persona activation is opt-in per host; frieren is the default.
    hosts = ["frieren" "delphi"];
  };

  # User lingering: without it the per-user systemd manager only exists while
  # devji has a session, so hermes-gateway (a --user unit) would stop at logout
  # and never start at boot. On frieren this was set by hand (`loginctl
  # enable-linger`); declaring it here is what makes a headless agent host
  # actually run its agent. scoped to this host deliberately — the fleet has no
  # blanket linger policy, and desktop hosts do not need one.
  users.users.${user.name}.linger = true;

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
  ];

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
  };

  system.stateVersion = "25.05";
}
