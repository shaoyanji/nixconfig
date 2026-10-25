# Fleet monitors as code (HC-6).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fleetMonitors;

  alertBridge =
    pkgs.writers.writePython3Bin "fleet-alert-bridge" {
      libraries = [pkgs.python3Packages.websockets];
      flakeIgnore = ["E501" "E302" "E305" "E203" "W503"];
    } ''
      import asyncio
      import http.server
      import json
      import sys
      import uuid
      import websockets

      async def send_to_simplex(msg):
          corr_id = str(uuid.uuid4())[:8]
          req = {"corrId": corr_id, "cmd": "#Fleet " + msg}
          async with websockets.connect("ws://127.0.0.1:5225") as ws:
              await ws.send(json.dumps(req))
              await asyncio.wait_for(ws.recv(), timeout=5.0)

      class AlertHandler(http.server.BaseHTTPRequestHandler):
          def do_POST(self):
              content_length = int(self.headers.get("Content-Length", 0))
              body = self.rfile.read(content_length).decode("utf-8")
              try:
                  data = json.loads(body)
                  ep = data.get("endpoint", "Unknown Service")
                  grp = data.get("group", "fleet")
                  desc = data.get("description", "Failure")
                  msg = "🚨 [Fleet Alert] %s (%s): %s" % (ep, grp, desc)
                  asyncio.run(send_to_simplex(msg))
              except Exception as e:
                  sys.stderr.write("Alert bridge error: %s\n" % str(e))
              self.send_response(200)
              self.end_headers()
              self.wfile.write(b"OK\n")

          def log_message(self, format, *args):
              pass

      server = http.server.HTTPServer(("127.0.0.1", ${toString cfg.alerting.port}), AlertHandler)
      server.serve_forever()
    '';

  # gatus requires at least one condition per endpoint. If none are specified,
  # supply type-appropriate defaults based on the URL scheme.
  defaultConditions = url:
    if lib.hasPrefix "tcp://" url
    then ["[CONNECTED] == true"]
    else if lib.hasPrefix "icmp://" url
    then ["[CONNECTED] == true"]
    else ["[STATUS] < 400"];

  toEndpoint = e:
    {
      inherit (e) name url;
      interval =
        if e.interval != null
        then e.interval
        else cfg.interval;
      conditions =
        if e.conditions != null
        then e.conditions
        else defaultConditions e.url;
      alerts =
        if e.alerts != null
        then e.alerts
        else [
          {
            type = "custom";
            failure-threshold = 3;
            description = "Health check failed (3 consecutive failures)";
            send-on-resolved = true;
          }
        ];
    }
    // lib.optionalAttrs (e.group != null) {inherit (e) group;}
    // lib.optionalAttrs (e.headers != null) {inherit (e) headers;};
in {
  options.services.fleetMonitors = {
    enable = lib.mkEnableOption "config-declared fleet monitors (gatus backend)";

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the monitor UI binds. Loopback by default — reach it through nginx.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8181;
      description = ''
        Port for the monitor UI. Deliberately not `8080`: Pi-hole's web UI already
        owns that on frieren.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open {option}`port` on the firewall. Leave false and proxy it: the backend
        binds loopback, so an opened hole would be unusable (REDUNDANT).
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "60s";
      description = "Default probe interval for endpoints that do not set their own.";
    };

    alerting = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Gatus alerting dispatch (custom webhook bridge to SimpleX).";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5226;
        description = "Loopback port for the local fleet monitoring alert bridge.";
      };
    };

    endpoints = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name of the monitor.";
          };
          url = lib.mkOption {
            type = lib.types.str;
            description = ''
              Target. The URL scheme selects the probe type: `http(s)://` a request,
              `tcp://host:port` a connect, `dns://`, `icmp://host`.
            '';
          };
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Include this monitor.";
          };
          group = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Group heading in the UI.";
          };
          interval = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override {option}`interval` for this monitor.";
          };
          conditions = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = ''
              gatus conditions (e.g. `["[STATUS] < 400"]`). null lets gatus apply the
              default for the endpoint type.
            '';
          };
          alerts = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.attrs);
            default = null;
            description = "Optional custom alerts for this endpoint.";
          };
          headers = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "Optional HTTP request headers for the probe.";
          };
        };
      });
      default = [];
      description = ''
        The monitors. Living here is the point of the module: the definition is
        reviewable, diffable state rather than rows in an application database.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.gatus = {
      enable = true;
      inherit (cfg) openFirewall;
      settings = {
        web = {
          inherit (cfg) address port;
        };
        alerting = lib.mkIf cfg.alerting.enable {
          custom = {
            url = "http://127.0.0.1:" + toString cfg.alerting.port + "/alert";
            method = "POST";
            body = "{\"endpoint\": \"[ENDPOINT_NAME]\", \"group\": \"[ENDPOINT_GROUP]\", \"description\": \"[ALERT_DESCRIPTION]\"}";
          };
        };
        endpoints = map toEndpoint (lib.filter (e: e.enabled) cfg.endpoints);
      };
    };

    systemd.user.services.fleet-alert-bridge = lib.mkIf cfg.alerting.enable {
      description = "Gatus to SimpleX Fleet Alert Bridge";
      after = ["network.target"];
      wantedBy = ["default.target"];
      serviceConfig = {
        ExecStart = "${alertBridge}/bin/fleet-alert-bridge";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
