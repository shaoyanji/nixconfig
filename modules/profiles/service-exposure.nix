# One declarative exposure registry for a host's scoped firewall.
#
# A service declares once what it exposes (`port`, protocol, reachability) and
# this module derives `networking.firewall.interfaces.<iface>` from it. It
# exists because frieren's exposure was duplicated across four hand-synced
# lists — see `hosts/frieren/firewall-scope.nix`, whose own header warns
# "Keep in sync with the global contributions". Enforcement stays in
# `firewall-scope.nix` (which clears the interface-blind global lists with
# `lib.mkForce`); this module only fills the per-interface lists.
#
# It deliberately does NOT read back the global `allowedTCPPorts` option: a
# scoped host `mkForce`s that option, and `lib.optionals`/`.definitions` only
# keep the winning definition, so contributors cannot be recovered from it.
# Services therefore migrate onto this registry explicitly.
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
          tailnet = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Reachable on tailscale0.";
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
