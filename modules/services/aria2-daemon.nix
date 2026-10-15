# aria2-daemon — network RPC download service with AriaNg web UI.
#
# Delegates the daemon lifecycle to the native nixpkgs `services.aria2`
# module and adds the nginx vhost for AriaNg + RPC reverse proxy.
#
# The RPC secret is loaded via systemd LoadCredential at runtime — never
# stored in the Nix store or command line.
#
# AriaNg is pulled as a pre-built release zip via fetchzip instead of
# building from source via npm (which is fragile and breaks frequently).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.aria2-daemon;

  # Pre-built AriaNg static files — avoids npm build failures from nixpkgs.
  ariang = (import ../../lib/fetches-extra.nix {inherit pkgs;}).fetch "ariang";

  # Bootstrap config rendered into the served site at runtime: pre-seeds the
  # AriaNg RPC connection (host/port from the browser's location, secret
  # base64-encoded as AriaNg's getCurrentRpcSecret expects). The placeholder
  # is replaced by ariang-site.service from the sops-rendered secret file.
  # Storage facts read from the bundled minified source: AriaNg persists its
  # settings via angular-local-storage (setPrefix("AriaNg")) under the key
  # "Options", i.e. localStorage "AriaNg.Options", with the RPC fields held
  # DIRECTLY on that object (rpcAlias/rpcHost/rpcPort/secret base64) plus an
  # extendRpcServers array — there is no "AriaNgSettings"/rpcList key.
  ariangConfigTemplate = pkgs.writeText "ariang-config.js" ''
    // Managed: rendered by ariang-site.service — edits are overwritten.
    // Pre-seeds the AriaNg RPC connection to this vhost's /jsonrpc proxy.
    (function () {
      var KEY = 'AriaNg.Options', raw = localStorage.getItem(KEY), s = null;
      try { s = JSON.parse(raw || '{}'); } catch (e) { s = null; }
      // angular-local-storage may double-encode; unwrap a string result.
      if (typeof s === 'string') { try { s = JSON.parse(s); } catch (e) { s = null; } }
      if (!s || typeof s !== 'object') { s = {}; }
      s.rpcAlias = s.rpcAlias || 'frieren aria2';
      s.rpcHost = location.hostname;
      s.rpcPort = String(location.port || '80');
      s.rpcInterface = 'jsonrpc';
      s.protocol = 'http';
      s.httpMethod = 'POST';
      s.secret = '__ARIA2_RPC_SECRET_B64__';
      if (!Array.isArray(s.extendRpcServers)) s.extendRpcServers = [];
      localStorage.setItem(KEY, JSON.stringify(s));
    })();
  '';
in {
  options.services.aria2-daemon = {
    enable = lib.mkEnableOption "aria2 RPC download daemon";

    user = lib.mkOption {
      type = lib.types.str;
      default = "aria2";
      description = "System user for aria2 daemon";
    };

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/downloads";
      description = "Where downloads are saved";
    };

    sessionFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/aria2/aria2.session";
      description = "Session file for resuming downloads";
    };

    rpcHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "RPC listen host (expose via nginx)";
    };

    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 6800;
      description = "RPC listen port";
    };

    rpcSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the RPC secret (loaded via systemd LoadCredential)";
    };

    btListenPort = lib.mkOption {
      type = lib.types.port;
      default = 51413;
      description = "BitTorrent DHT/listen port";
    };

    nginx.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose AriaNg + RPC proxy via nginx";
    };

    nginx.rpcSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the RPC secret readable by the nginx user (typically a second
        sops render of the same key with owner nginx). When set, /jsonrpc is
        handled by an njs handler that injects the token server-side, so the
        AriaNg UI needs no per-browser secret entry. When null, /jsonrpc is
        proxied raw and callers must send the token themselves.
      '';
    };

    nginx.listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for AriaNg web UI";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rpcSecretFile != null;
        message = "services.aria2-daemon requires rpcSecretFile to be set (the native services.aria2 module mandates a secret file)";
      }
    ];

    # Delegate daemon lifecycle to the native nixpkgs module.
    services.aria2 = {
      enable = true;
      inherit (cfg) rpcSecretFile;
      openPorts = false; # We manage firewall separately via networking.firewall.
      settings = {
        dir = cfg.downloadDir;
        "save-session" = cfg.sessionFile;
        "rpc-listen-port" = cfg.rpcPort;
        "listen-port" = [
          {
            from = cfg.btListenPort;
            to = cfg.btListenPort;
          }
        ];

        # Feature flags matching the original custom service.
        "enable-dht" = true;
        "enable-dht6" = true;
        "enable-peer-exchange" = true;
        "dht-listen-port" = cfg.btListenPort;

        # Peer/client impersonation.
        "peer-id-prefix" = "-TR2770-";
        "peer-agent" = "Transmission/2.77";
        "user-agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0";

        # Download/performance tuning.
        continue = true;
        "max-concurrent-downloads" = 10;
        "max-connection-per-server" = 16;
        "min-split-size" = "10M";
        split = 5;
        "disk-cache" = "32M";
        "file-allocation" = "falloc";
        "save-session-interval" = 60;

        # Seeding behavior.
        "seed-ratio" = 0;
        "bt-hash-check-seed" = true;
        "bt-seed-unverified" = true;
        "max-upload-limit" = "50K";

        # RPC binding — localhost only, nginx reverse-proxies.
        "rpc-listen-all" = false;
        "rpc-allow-origin-all" = true;

        disable-ipv6 = true;
      };
    };

    # Ensure downloads are world-readable so NFS/SMB clients can access them.
    # The native services.aria2 module already sets UMask=0022; we use mkDefault
    # to avoid a conflict while still explicitly documenting the intent.
    systemd.services.aria2.serviceConfig.UMask = lib.mkDefault "022";

    # Runtime-rendered AriaNg site. The static build cannot know the RPC secret
    # (it must never enter the Nix store), and AriaNg reads its RPC settings
    # from browser localStorage — a fresh browser sees an unconfigured UI
    # ("not hooked to anything"). This oneshot copies the static build to
    # /var/lib/ariang-site, injects a <script src="config.js"> loader, and
    # renders config.js from the sops-rendered RPC secret (base64-encoded, the
    # form AriaNg's getCurrentRpcSecret decodes). The secret is therefore
    # readable by any client that can reach the LAN vhost — the same
    # trusted-LAN tradeoff as the anonymous MQTT listener and the unsigned
    # harmonia narinfo.
    systemd.services.ariang-site = lib.mkIf cfg.nginx.enable {
      description = "Render the AriaNg site with the aria2 RPC bootstrap config";
      before = ["nginx.service"];
      # Re-render when the static build or the bootstrap template changes;
      # a oneshot otherwise never re-runs across switches (the state dir
      # keeps serving the stale copy).
      restartTriggers = [ariang ariangConfigTemplate];
      path = with pkgs; [coreutils gnused];
      serviceConfig = {
        Type = "oneshot";
        # Stay "active (exited)" after rendering: switch-to-configuration only
        # restarts units that are active, so without this a changed unit file
        # would never re-render the site across switches.
        RemainAfterExit = true;
        StateDirectory = "ariang-site";
        LoadCredential = "rpcsecret:${cfg.rpcSecretFile}";
      };
      script = ''
        set -euo pipefail
        site="$STATE_DIRECTORY"
        rm -rf "$site.tmp"
        cp -rT ${ariang} "$site.tmp"
        chmod -R u+w "$site.tmp"
        sed -i 's#</head>#<script src="config.js"></script></head>#' "$site.tmp/index.html"
        secret_b64="$(base64 -w0 "$CREDENTIALS_DIRECTORY/rpcsecret")"
        sed "s#__ARIA2_RPC_SECRET_B64__#$secret_b64#" ${ariangConfigTemplate} > "$site.tmp/config.js"
        rm -rf "$site"
        mv "$site.tmp" "$site"
      '';
    };

    systemd.services.nginx = lib.mkIf cfg.nginx.enable {
      requires = ["ariang-site.service"];
      after = ["ariang-site.service"];
    };

    # Nginx vhost: serves AriaNg static UI and reverse-proxies /jsonrpc.
    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts.aria = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.nginx.listenPort;
          }
        ];
        serverName = "_";
        root = "/var/lib/ariang-site";
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
        locations."= /config.js" = {
          priority = 50;
          extraConfig = ''
            add_header Cache-Control "no-store";
          '';
        };
        locations."/jsonrpc" = {
          proxyPass = "http://${cfg.rpcHost}:${builtins.toString cfg.rpcPort}/jsonrpc";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;
          '';
        };
      };
    };
  };
}
