# One declarative exposure registry for a host's scoped firewall.
{
  lib,
  config,
  ...
}: let
  cfg = config.profiles.serviceExposure;

  # A service is reachable on tailscale0 only if it opts in; on every other
  # scoped interface it uses the `lan` flag.
  reachableOn = iface: s:
    if iface == "tailscale0"
    then s.tailnet
    else s.lan;

  portsOf = proto: iface:
    lib.sort (a: b: a < b) (
      lib.mapAttrsToList (_: s: s.port) (
        lib.filterAttrs (_: s: s.enable && s.${proto} && reachableOn iface s) cfg.services
      )
    );
in {
  options.profiles.serviceExposure = {
    enable = lib.mkEnableOption "the declarative service-exposure registry";

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Interfaces whose per-interface firewall lists are derived from
        {option}`services`. Empty means the registry is inert.
      '';
    };

    services = lib.mkOption {
      default = {};
      description = ''
        Services to expose, keyed by a stable name. Each entry contributes its
        {option}`port` to the TCP and/or UDP list of every interface it is
        reachable on.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Include this exposure.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "Port to open.";
          };
          tcp = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Open the port for TCP.";
          };
          udp = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open the port for UDP.";
          };
          lan = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Reachable on the wired/wifi LAN interfaces.";
          };
          # No default, on purpose. `true` here meant every new row silently
          # widened the mesh, and on frieren that was fifteen rows' worth of
          # discovery, SMB and DHCP holes nobody had decided to open. The LAN is
          # the host's own wire; the tailnet is a second network with its own
          # clients, so a row has to say which of them it serves.
          tailnet = lib.mkOption {
            type = lib.types.bool;
            description = ''
              Reachable on tailscale0. Required: a row that omits it fails to
              evaluate, so exposing a service on the mesh is always a written
              decision and never an inherited default.
            '';
          };
          proxy = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "nginx virtualHost key (the server name).";
                };
                listenPort = lib.mkOption {
                  type = lib.types.port;
                  default = 80;
                  description = "Port the vhost listens on.";
                };
                upstream = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Proxy target. Defaults to
                    `"http://127.0.0.1:''${toString port}"` when null.
                  '';
                };
                websockets = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Set `proxyWebsockets` on the `/` location.";
                };
              };
            });
            default = null;
            description = ''
              Optional reverse-proxy vhost. Only uniform vhosts (a single `/`
              location pointing at one upstream) can be expressed here; richer
              ones stay explicit in the host's `reverse-proxy.nix`.
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces = lib.mkIf (cfg.interfaces != []) (
      lib.genAttrs cfg.interfaces (iface: {
        allowedTCPPorts = portsOf "tcp" iface;
        allowedUDPPorts = portsOf "udp" iface;
      })
    );

    # A port on a scoped interface that no row declares is the failure this
    # registry exists to end: it cannot follow the service whose port it copies.
    # Both delphi findings were that shape (a hand-written 3012 with no listener,
    # a 53/tcp nothing bound). Eval sees it, so `checks:host` and CI's
    # `hostChecks` fail it; a row whose service is disabled is still only visible
    # to `checks:ports`, which compares the declaration against live `ss`.
    assertions = let
      merged = iface: proto:
        if proto == "tcp"
        then config.networking.firewall.interfaces.${iface}.allowedTCPPorts
        else config.networking.firewall.interfaces.${iface}.allowedUDPPorts;
      check = iface: proto: let
        extra = lib.subtractLists (portsOf proto iface) (lib.unique (merged iface proto));
      in {
        assertion = extra == [];
        message = ''
          networking.firewall.interfaces.${iface}.allowed${lib.toUpper proto}Ports holds
          ${lib.concatMapStringsSep " " toString extra}, which no `profiles.serviceExposure` row declares.
          Declare the owning service in that registry (the row reads the port from the option
          that owns it) instead of writing the port into the interface list by hand.
        '';
      };
    in
      lib.concatMap (iface: [(check iface "tcp") (check iface "udp")]) cfg.interfaces;

    # Uniform reverse-proxy vhosts, derived from the same declaration that opens
    # the firewall port. Richer vhosts are left to the host.
    services.nginx.virtualHosts = lib.mapAttrs' (_: s:
      lib.nameValuePair s.proxy.name {
        listen = [
          {
            addr = "0.0.0.0";
            port = s.proxy.listenPort;
          }
        ];
        locations."/" = {
          proxyPass =
            if s.proxy.upstream != null
            then s.proxy.upstream
            else "http://127.0.0.1:${toString s.port}";
          proxyWebsockets = s.proxy.websockets;
        };
      }) (lib.filterAttrs (_: s: s.enable && s.proxy != null) cfg.services);
  };
}
