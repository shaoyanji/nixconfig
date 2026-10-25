{
  pkgs,
  config,
  ...
}: let
  # LAN wildcard TLS: private CA (modules/config/tls/frieren-lan-ca.pem,
  # trusted fleet-wide via security.pki) signs *.frieren.lan; the leaf key is
  # sops-rendered at /run/secrets/tls-frieren-wildcard-key. Bitwarden clients
  # refuse plain HTTP, so vault (and HA) must be served over TLS.
  # Direct path (NO toString): the store snapshot must keep its string
  # context so the pem lands in the system closure — with toString the
  # referenced file can be absent at activation time and nginx fails with
  # "cannot load certificate".
  tlsCertificate = ../../modules/config/tls/frieren-lan-wildcard.pem;
  tlsCertificateKey = "/run/secrets/tls-frieren-wildcard-key";

  # ONE instance of the fleet site. It reads the knowledge graph and every note
  # at eval time, so importing it per location (it used to be imported twice in
  # this file) evaluated the same 1.9 k-line module twice for identical output.
  fleetSite = import ../../lib/aki-site.nix {
    inherit pkgs;
    inventory = config.fleet.inventory;
    host = config.networking.hostName;
  };

  # The cache policy for compiled static trees, shared with the UDS bridge
  # (modules/config/nginx-static-cache.nix) so the two servers cannot disagree.
  staticCache = import ../../modules/config/nginx-static-cache.nix;

  # LAN addresses come from the compiled registry: a host that moves must not
  # need its proxy edited, and the registry is what the docs site already reads.
  lanIp = name: config.fleet.inventory.hosts.${name}.network.lan_ip;

  # The page is COMPILED from the service registry in `config`, not written
  # here: a hand-kept list outlives the services it names (this file still
  # advertised `pdf.frieren.lan` after Stirling moved to delphi). The
  # registry lives at the bottom of this file; the asserts in
  # `modules/services/service-portal.nix` fail the build when a card has no
  # owner.
  landingPage = config.services.servicePortal.pages.lan;
in {
  imports = [../../modules/services/service-portal.nix];

  # --- Service portal: the page, from the registry ----------------------------
  # One entry per card. Keys under `exposed` services (immich, paperless, …) are
  # the `profiles.serviceExposure` keys, so the address and badge come from the
  # same place the firewall and vhost do; the rest name a vhost this file
  # serves. A key that matches neither is a card nothing serves, and
  # `modules/services/service-portal.nix` asserts that at eval.
  services.servicePortal = {
    enable = true;
    title = "frieren";
    subtitle = "24/7 primary fleet NAS & core services · 192.168.3.25 / 100.97.61.65";
    groups = [
      "Storage, Media & Documents"
      "Operations & Fleet Infrastructure"
    ];
    entries = {
      # --- exposure rows (address derived from profiles.serviceExposure) ------
      immich = {
        title = "Immich";
        description = "Personal photo & video cloud with facial recognition and semantic AI search.";
        group = "Storage, Media & Documents";
      };
      paperless = {
        title = "Paperless-ngx";
        description = "Document archive, automated OCR indexing, full-text search, and tagging.";
        group = "Storage, Media & Documents";
      };
      jellyfin = {
        title = "Jellyfin";
        description = "Media streaming server for movies, television, audiobooks, and music.";
        group = "Storage, Media & Documents";
      };
      ariang = {
        title = "AriaNg";
        description = "Web frontend for the aria2 network RPC download daemon.";
        group = "Storage, Media & Documents";
      };
      kiwix = {
        title = "Kiwix";
        description = "Offline Wikipedia & ArchWiki reader with full-text search.";
        group = "Storage, Media & Documents";
      };
      home-assistant = {
        title = "Home Assistant";
        description = "Home automation hub, Zigbee/ESPHome control, and server battery telemetry.";
        group = "Operations & Fleet Infrastructure";
        scheme = "https";
      };
      uptime-kuma = {
        title = "Uptime Kuma";
        description = "Fleet service monitoring, uptime dashboards, and ping health metrics.";
        group = "Operations & Fleet Infrastructure";
      };
      scrutiny = {
        title = "Scrutiny";
        description = "Hard drive S.M.A.R.T. monitoring and drive health analysis dashboard.";
        group = "Operations & Fleet Infrastructure";
      };
      harmonia = {
        title = "Harmonia";
        description = "Local LAN Nix binary cache, serving signed packages at wire speed.";
        group = "Operations & Fleet Infrastructure";
      };

      # --- vhosts this file serves, outside the exposure registry -------------
      audiobookshelf = {
        title = "Audiobookshelf";
        description = "Self-hosted audiobook & podcast streamer with playback sync and mobile apps.";
        group = "Storage, Media & Documents";
        vhost = "audiobooks.frieren.lan";
      };
      transmission = {
        title = "Transmission";
        description = "Leech-only BitTorrent client for ISOs, datasets and open-access papers.";
        group = "Storage, Media & Documents";
        vhost = "torrent.frieren.lan";
      };
      paste = {
        title = "Paste Bin";
        description = "LAN paste bin — upload over SSH with `pb`, 30-day expiry.";
        group = "Storage, Media & Documents";
        vhost = "frieren.lan";
        href = "http://paste.frieren.lan";
      };
      vaultwarden = {
        title = "Vaultwarden";
        description = "Bitwarden-compatible vault for passwords and 2FA TOTP codes.";
        group = "Operations & Fleet Infrastructure";
        vhost = "vault.frieren.lan";
        href = "https://vault.frieren.lan";
      };
      fleet = {
        title = "Fleet Control Plane";
        description = "Aki hypermedia docs, host inventory & Nix closure explorer.";
        group = "Operations & Fleet Infrastructure";
        vhost = "fleet.frieren.lan";
      };
      monitors = {
        title = "Fleet Monitors";
        description = "Config-declared health checks (gatus) — service, cache and DNS liveness.";
        group = "Operations & Fleet Infrastructure";
        vhost = "monitors.frieren.lan";
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "50000M"; # Support multi-gigabyte video uploads to Immich/Paperless

    appendHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

    virtualHosts = {
      # Default portal / landing page
      "frieren.lan" = {
        default = true;
        serverAliases = [
          "nas.frieren.lan"
          "nas.lan"
          "frieren"
          "192.168.3.25"
          "frieren.local"
        ];
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
            extraParameters = ["default_server"];
          }
        ];
        locations."/" = {
          root = landingPage;
        };
        # Regex expression enclosed in quotes so nginxfmt does not mistake '{8}' for an nginx block
        locations."~ \"^/([a-z0-9]{8}(\\.[a-zA-Z0-9]+)?)$\"" = {
          root = "/var/lib/paste";
          extraConfig = ''
            default_type text/plain;
          '';
        };
        # fleet-sentinel (modules/services/fleet-sentinel.nix). Served from
        # the default vhost so gatus can probe 127.0.0.1:80 without a
        # Host-header trick or a second listener; the human vhost below maps
        # the same directory at sentinel.frieren.lan.
        locations."/sentinel/" = {
          alias = "/var/lib/fleet-sentinel/www/";
          extraConfig = ''
            autoindex off;
            add_header Cache-Control "no-store";
          '';
        };
        locations."/paste/" = {
          alias = "/var/lib/paste/";
          extraConfig = ''
            autoindex off;
            default_type text/plain;
          '';
        };
        locations."/p/" = {
          alias = "/var/lib/paste/";
          extraConfig = ''
            autoindex off;
            default_type text/plain;
          '';
        };
        # EXP-102: Canary MicroVM Reverse Proxy Dogfood (Model B)
        # Exposes dummy API from frieren-canary (192.168.83.10:8080) through hypervisor Nginx
        locations."/canary/" = {
          proxyPass = "http://${lanIp "frieren-canary"}:8080/";
          extraConfig = ''
            proxy_connect_timeout 2s;
            proxy_read_timeout 5s;
          '';
        };

        # SubZeroClaw-in-microVM: expose Eisen's decision router to the
        # bridged subnet (Model B). The canary (192.168.83.10) talks only to
        # the host (192.168.83.1); frieren proxies /eisen/ to Eisen's nginx
        # /router/ (which strips to /v1/... on the router). The Host is
        # forced to eisen.lan so Eisen's nginx matches its eisen.lan vhost
        # (the canary's original Host, 192.168.83.1, would miss it).
        # Isolation: the runner (SubZeroClaw, in the microVM) is on a
        # different host from the model (Eisen); they connect only via this
        # endpoint. The microVM has no direct LAN access to Eisen.
        locations."/eisen/" = {
          proxyPass = "http://${lanIp "eisen"}/router/";
          extraConfig = ''
            proxy_set_header Host "eisen.lan";
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
            client_max_body_size 0;
          '';
        };
      };

      "vault.frieren.lan" = {
        # addSSL is what makes the module emit ssl_certificate/ssl_certificate_key
        # for the ssl listen entry — a bare `listen … ssl` does not.
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
          proxyWebsockets = true;
        };
        locations."/notifications/hub" = {
          proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.WEBSOCKET_PORT}";
          proxyWebsockets = true;
        };
        locations."/notifications/hub/negotiate" = {
          proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
        };
      };

      # Home Assistant over TLS (web UI, companion apps and webhooks all want
      # a secure context). The backend binds 0.0.0.0:8123; this vhost is the
      # name-routed front end (raw :8123 stays open on the LAN as well).
      "ha.frieren.lan" = {
        # See the vault vhost: addSSL is required for the ssl_certificate
        # directive; the service-exposure registry additionally contributes the
        # plain-HTTP :80 listener for this same vhost.
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.ha-stack.port}";
          proxyWebsockets = true;
        };
      };

      "fleet.frieren.lan" = {
        serverAliases = [
          "control.frieren.lan"
          "explorer.frieren.lan"
        ];
        # `addSSL` is what makes the module EMIT ssl_certificate/_key. A manual
        # `listen ... ssl = true` alone declared the listener without the pair,
        # and nginx refused to start: `no "ssl_certificate" is defined for the
        # "listen ... ssl" directive`. Same requirement as the vault and ha
        # vhosts above.
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          # The compiled registry and this host's own name are passed in: the site
          # renders the same evaluated data the host enforces, and its status
          # badge is read from the registry instead of being typed into markup.
          root = fleetSite;
          extraConfig = staticCache.html;
        };
        # Content-hashed immutable static assets (Gap B).
        #
        # The eight hex digits are spelled out instead of `{8}`: a brace
        # quantifier in a location key came out of the config generator SPLIT
        # across lines (`location ~* \.[a-f0-9] { / 8 / }`), which nginx rejects
        # with `unexpected "}"` and the whole site 502s. Verified on generation
        # 100 (2026-10-19): with `{8}` the switch restarts nginx into a crash
        # loop; the equivalent class below generates one valid line. The match
        # is identical — exactly eight hex characters before the extension.
        locations."~* \\.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\.(?:css|js)$" = {
          root = fleetSite;
          extraConfig = staticCache.hashed;
        };
        # Live mainframe telemetry (Gap A)
        locations."= /data/live.json" = {
          alias = "/run/uds-docs/live.json";
          extraConfig = ''
            default_type application/json;
            add_header Cache-Control "no-cache, no-store, must-revalidate" always;
          '';
        };
      };

      # Monitors UI (gatus, HC-6). Written out here rather than through
      # `profiles.serviceExposure`: the backend binds loopback, and a registry
      # entry would also open its port on the LAN interface — a hole with only a
      # loopback listener behind it is the REDUNDANT class `checks:ports` flags.
      "monitors.frieren.lan" = {
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.fleetMonitors.port}";
          proxyWebsockets = true;
        };
      };

      # Fleet sentinel dashboard (static, reads status.json client-side).
      "sentinel.frieren.lan" = {
        serverAliases = ["sentinel"];
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          root = "/var/lib/fleet-sentinel/www";
          extraConfig = ''
            add_header Cache-Control "no-store";
          '';
        };
      };

      # Transmission web UI (leech-only torrent client). RPC binds loopback
      # only (hosts/frieren/transmission.nix); this vhost is the sole path in,
      # so no raw :9091 LAN hole is opened. Same rationale as
      # monitors.frieren.lan above: not a profiles.serviceExposure entry.
      "torrent.frieren.lan" = {
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.transmission.settings.rpc-port}";
          proxyWebsockets = true;
        };
      };

      # EXP-102: Canary MicroVM Dedicated Virtual Host (Model B Dogfood)
      "canary.frieren.lan" = {
        serverAliases = [
          "canary"
        ];
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = "http://${lanIp "frieren-canary"}:8080/";
          extraConfig = ''
            proxy_connect_timeout 2s;
            proxy_read_timeout 5s;
          '';
        };
      };

      # Audiobookshelf web UI & streaming API
      "audiobooks.frieren.lan" = {
        serverAliases = [
          "audiobookshelf.frieren.lan"
          "books.frieren.lan"
          "audiobooks"
        ];
        addSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        sslCertificate = tlsCertificate;
        sslCertificateKey = tlsCertificateKey;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.audiobookshelf.port}";
          proxyWebsockets = true;
          extraConfig = ''
            client_max_body_size 500M;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
