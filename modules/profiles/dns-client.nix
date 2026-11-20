# Client side of docs/dns-failover.md (exp-104); resolver hosts use net/dns/failover.nix.
{
  config,
  lib,
  ...
}: let
  cfg = config.profiles.dnsClient;
in {
  options.profiles.dnsClient = {
    enable = lib.mkEnableOption ''
      the declared fleet resolver plus a public fallback, so a client with the
      resolver host down still resolves public names
    '';

    resolvers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["192.168.3.50" "100.97.61.65"];
      description = ''
        Fleet resolver addresses, most preferred first: the LAN resolver group's
        VIP (profiles.dnsFailover.resolvers on frieren; the address DHCP hands
        out) then frieren's tailnet address, which keeps answering a client that
        has left the LAN but not the tailnet.
      '';
    };

    fallbacks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["1.1.1.1" "9.9.9.9"];
      description = ''
        Public upstreams systemd-resolved uses when every fleet resolver is
        unreachable — the tier that keeps public names resolving through a
        frieren outage. `.lan` names never reach them: {option}`domains`
        pins the fleet zones to {option}`resolvers`.
      '';
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["~lan" "~frieren.lan"];
      description = ''
        systemd-resolved routing domains sent only to {option}`resolvers`,
        never to the public fallback.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # mkDefault throughout: a host with its own resolved story (a resolver, a
    # roaming override) wins without mkForce.
    networking.nameservers = lib.mkDefault cfg.resolvers;
    services.resolved = {
      enable = lib.mkDefault true;
      settings.Resolve = {
        DNS = lib.mkDefault (lib.concatStringsSep " " cfg.resolvers);
        FallbackDNS = lib.mkDefault (lib.concatStringsSep " " cfg.fallbacks);
        Domains = lib.mkDefault cfg.domains;
      };
    };
  };
}
