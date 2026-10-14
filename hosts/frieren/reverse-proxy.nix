{pkgs, ...}: let
  landingPage = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>frieren // Fleet Control & Storage Portal</title>
      <style>
        :root {
          --bg: #0d1117;
          --card: #161b22;
          --border: #30363d;
          --text: #c9d1d9;
          --accent: #58a6ff;
          --accent-hover: #79c0ff;
        }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
          background-color: var(--bg);
          color: var(--text);
          margin: 0;
          padding: 2.5rem 1.5rem;
          display: flex;
          flex-direction: column;
          align-items: center;
        }
        h1 { margin-bottom: 0.25rem; font-size: 2rem; color: #fff; }
        p.subtitle { color: #8b949e; margin-top: 0; margin-bottom: 2rem; font-size: 1rem; }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
          gap: 1.25rem;
          max-width: 1000px;
          width: 100%;
        }
        .section-title {
          grid-column: 1 / -1;
          font-size: 1.15rem;
          font-weight: 600;
          color: #8b949e;
          border-bottom: 1px solid var(--border);
          padding-bottom: 0.5rem;
          margin-top: 1rem;
        }
        .card {
          background: var(--card);
          border: 1px solid var(--border);
          border-radius: 8px;
          padding: 1.25rem;
          text-decoration: none;
          color: inherit;
          transition: transform 0.15s ease, border-color 0.15s ease;
          display: flex;
          flex-direction: column;
        }
        .card:hover {
          transform: translateY(-2px);
          border-color: var(--accent);
        }
        .card-header {
          display: flex;
          align-items: center;
          gap: 0.75rem;
          margin-bottom: 0.5rem;
        }
        .card-title {
          font-size: 1.1rem;
          font-weight: 600;
          color: var(--accent);
        }
        .card:hover .card-title { color: var(--accent-hover); }
        .card-desc {
          font-size: 0.875rem;
          color: #8b949e;
          line-height: 1.4;
        }
        .badge {
          display: inline-block;
          font-size: 0.7rem;
          padding: 2px 6px;
          border-radius: 4px;
          background: #21262d;
          color: #58a6ff;
          margin-top: auto;
          padding-top: 0.5rem;
        }
      </style>
    </head>
    <body>
      <h1>frieren</h1>
      <p class="subtitle">24/7 Primary Fleet NAS & Core Services (192.168.3.25 / 100.97.61.65)</p>

      <div class="grid">
        <div class="section-title">Storage, Media & Documents</div>

        <a class="card" href="http://photos.frieren.lan">
          <div class="card-header"><span class="card-title">Immich</span></div>
          <div class="card-desc">Personal photo & video cloud with facial recognition and semantic AI search.</div>
          <div class="badge">photos.frieren.lan :2283</div>
        </a>

        <a class="card" href="http://docs.frieren.lan">
          <div class="card-header"><span class="card-title">Paperless-ngx</span></div>
          <div class="card-desc">Document archive, automated OCR indexing, full-text search, and tagging.</div>
          <div class="badge">docs.frieren.lan :28981</div>
        </a>

        <a class="card" href="http://media.frieren.lan">
          <div class="card-header"><span class="card-title">Jellyfin</span></div>
          <div class="card-desc">Media streaming server for movies, television, audiobooks, and music.</div>
          <div class="badge">media.frieren.lan :8096</div>
        </a>

        <a class="card" href="http://pdf.frieren.lan">
          <div class="card-header"><span class="card-title">Stirling PDF</span></div>
          <div class="card-desc">Local PDF editing, merging, splitting, OCR, and conversion suite.</div>
          <div class="badge">pdf.frieren.lan :7351</div>
        </a>

        <a class="card" href="http://aria.frieren.lan">
          <div class="card-header"><span class="card-title">AriaNg</span></div>
          <div class="card-desc">Web frontend for aria2 network RPC download daemon.</div>
          <div class="badge">aria.frieren.lan :6801</div>
        </a>

        <a class="card" href="http://torrent.frieren.lan">
          <div class="card-header"><span class="card-title">Transmission</span></div>
          <div class="card-desc">Leech-only BitTorrent client for ISOs, datasets and open-access papers.</div>
          <div class="badge">torrent.frieren.lan :9091</div>
        </a>

        <a class="card" href="http://wiki.frieren.lan">
          <div class="card-header"><span class="card-title">Kiwix</span></div>
          <div class="card-desc">Offline Wikipedia & ArchWiki reader with full-text search.</div>
          <div class="badge">wiki.frieren.lan :80</div>
        </a>

        <a class="card" href="http://paste.frieren.lan">
          <div class="card-header"><span class="card-title">Paste Bin</span></div>
          <div class="card-desc">LAN paste bin — upload via SSH (`pb` in ~/.local/bin), 30-day expiry.</div>
          <div class="badge">paste.frieren.lan :80</div>
        </a>

        <div class="section-title">Operations & Fleet Infrastructure</div>

        <a class="card" href="http://ha.frieren.lan">
          <div class="card-header"><span class="card-title">Home Assistant</span></div>
          <div class="card-desc">Home automation hub, Zigbee/ESPHome control, and server battery telemetry.</div>
          <div class="badge">ha.frieren.lan :8123</div>
        </a>

        <a class="card" href="http://status.frieren.lan">
          <div class="card-header"><span class="card-title">Uptime Kuma</span></div>
          <div class="card-desc">Fleet service monitoring, uptime dashboards, and ping health metrics.</div>
          <div class="badge">status.frieren.lan :3001</div>
        </a>

        <a class="card" href="http://smart.frieren.lan">
          <div class="card-header"><span class="card-title">Scrutiny</span></div>
          <div class="card-desc">Hard drive S.M.A.R.T. monitoring and drive health analysis dashboard.</div>
          <div class="badge">smart.frieren.lan :8124</div>
        </a>

        <a class="card" href="http://monitors.frieren.lan">
          <div class="card-header"><span class="card-title">Fleet Monitors</span></div>
          <div class="card-desc">Config-declared health checks (gatus) — service, cache and DNS liveness.</div>
          <div class="badge">monitors.frieren.lan :8181</div>
        </a>

        <a class="card" href="http://vault.frieren.lan">
          <div class="card-header"><span class="card-title">Vaultwarden</span></div>
          <div class="card-desc">Bitwarden-compatible vault for passwords and 2FA TOTP authentication codes.</div>
          <div class="badge">vault.frieren.lan :8222</div>
        </a>

        <a class="card" href="http://fleet.frieren.lan">
          <div class="card-header"><span class="card-title">Fleet Control Plane</span></div>
          <div class="card-desc">Aki hypermedia static documentation, host inventory & Nix closure explorer.</div>
          <div class="badge">fleet.frieren.lan :80</div>
        </a>

        <a class="card" href="http://cache.frieren.lan">
          <div class="card-header"><span class="card-title">Harmonia</span></div>
          <div class="card-desc">Local LAN Nix binary cache serving signed packages at wire speed.</div>
          <div class="badge">cache.frieren.lan :5000</div>
        </a>
      </div>
    </body>
    </html>
  '';
in {
  services.nginx = {
    enable = true;
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
          proxyPass = "http://192.168.83.10:8080/";
          extraConfig = ''
            proxy_connect_timeout 2s;
            proxy_read_timeout 5s;
          '';
        };
      };

      "vault.frieren.lan" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8222";
          proxyWebsockets = true;
        };
        locations."/notifications/hub" = {
          proxyPass = "http://127.0.0.1:3012";
          proxyWebsockets = true;
        };
        locations."/notifications/hub/negotiate" = {
          proxyPass = "http://127.0.0.1:8222";
        };
      };

      "fleet.frieren.lan" = {
        serverAliases = [
          "control.frieren.lan"
          "explorer.frieren.lan"
        ];
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          root = import ../../lib/aki-site.nix {inherit pkgs;};
        };
      };

      # Monitors UI (gatus, HC-6). Written out here rather than through
      # `profiles.serviceExposure`: the backend binds loopback, and a registry
      # entry would also open its port on the LAN interface — a hole with only a
      # loopback listener behind it is the REDUNDANT class `checks:ports` flags.
      "monitors.frieren.lan" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8181";
          proxyWebsockets = true;
        };
      };

      # Transmission web UI (leech-only torrent client). RPC binds loopback
      # only (hosts/frieren/transmission.nix); this vhost is the sole path in,
      # so no raw :9091 LAN hole is opened. Same rationale as
      # monitors.frieren.lan above: not a profiles.serviceExposure entry.
      "torrent.frieren.lan" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:9091";
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
          proxyPass = "http://192.168.83.10:8080/";
          extraConfig = ''
            proxy_connect_timeout 2s;
            proxy_read_timeout 5s;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [80];
}
