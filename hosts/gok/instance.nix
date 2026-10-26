# The gok appliance, declared. `scripts/task/gok.sh` renders this module into the
# instance's config.json and then fills the credential slots from sops; nothing
# here is a secret, and no credential belongs in this file.
{
  ...
}: {
  services.gokrazy.instances.gok = {
    # DHCP name and the address `gok update` resolves.
    hostname = "gok.cloudforest-kardashev.ts.net";

    packages = [
      "github.com/gokrazy/fbstatus"
      "github.com/gokrazy/hello"
      "github.com/gokrazy/serial-busybox"
      "github.com/gokrazy/breakglass"
      "tailscale.com/cmd/tailscaled"
      "tailscale.com/cmd/tailscale"
      "github.com/gokrazy/mkfs"
      "github.com/gokrazy/wifi"
      "github.com/prometheus/node_exporter"
      # The spare appliance is the fleet's DNS failover: it is small, always on,
      # and independent of both frieren (the primary) and delphi. blocky is a
      # forwarding resolver WITH a local zone, which is the part crab-hole lacks:
      # without `customDNS` a failover answers the internet and NXDOMAINs every
      # *.frieren.lan name, which degrades an outage instead of covering it.
      "github.com/0xERR0R/blocky"
    ];

    # A Pi 3B: arm64 userspace, no serial header plugged in.
    environment = ["GOOS=linux" "GOARCH=arm64"];
    serialConsole = "disabled";

    packageConfig = {
      # randomd writes /etc/machine-id at first boot. A fixed value here keeps
      # the appliance's identity stable across reflashes, which is what makes
      # its tailscale node and metrics series the same node.
      "github.com/gokrazy/gokrazy/cmd/randomd".extraFileContents."/etc/machine-id" =
        "3e8de745bc7c4cf89cd363e11d9a7718\n";

      # node_exporter, reachable on the LAN/tailnet as :9100.
      "github.com/prometheus/node_exporter".commandLineFlags = ["--web.listen-address=:9100"];

      # blocky listens on 53 and nothing else. The HTTP/API port is off on
      # purpose: this device is a resolver, and gokrazy has no firewall to put
      # in front of a web endpoint.
      #
      # `-c` is not optional: blocky defaults to `./config.yml` and gokrazy
      # starts every program with CWD `/`, so without the flag it looks for
      # `/config.yml`, finds nothing, and exits 1 — which the supervisor turn
      # into a one-per-second restart loop under the extras list. (Measured on
      # the appliance, 2026-10-26: attempt 108 and climbing, no listener.)
      "github.com/0xERR0R/blocky".commandLineFlags = ["-c" "/etc/blocky/config.yml"];
      "github.com/0xERR0R/blocky".extraFileContents."/etc/blocky/config.yml" = ''
        ports:
          dns: 53
          http: 0

        # A resolver cannot use the resolver it is replacing to find its own
        # upstreams. Measured on the appliance right after the first boot with
        # blocky enabled (2026-10-26 22:39, build 22:29): every query failed with
        # `lookup one.one.one.one on [fd7a:115c:a1e0::53]:53: server misbehaving`,
        # because the DoH upstreams are hostnames and the system resolver hands
        # those lookups to MagicDNS -> frieren, which is the primary this device
        # is the failover for. bootstrapDns is the flag that breaks the loop: IP
        # literals, so no lookup is required to start.
        bootstrapDns:
          - upstream: 1.1.1.1
          - upstream: 9.9.9.9

        # IPv4 only, the same reason crab-hole on delphi is IPv4 only: the LAN
        # uplink has no usable IPv6 path, and a resolver that prefers AAAA
        # SERVFAILs every name. The log above shows it reaching for `fd7a::53`
        # first.
        connectIPVersion: v4
        # Public DoT only. Forwarding to frieren would make the failover inherit
        # the outage it exists to cover.
        upstreams:
          groups:
            default:
              - https://one.one.one.one/dns-query
              - https://dns.quad9.net/dns-query

        # The zone frieren owns, answered here: every name in it points at
        # frieren's own services, so it does not depend on her resolver being up.
        customDNS:
          customTTL: 1h
          mapping:
            frieren.lan: 192.168.3.25
            "*.frieren.lan": 192.168.3.25

        # The same two lists the primary blocks, so a client that falls back gets
        # the answer it would have got from frieren.
        blocking:
          # The appliance's only uplink is wifi and its lists come off GitHub,
          # so a boot where association is late must not keep the resolver down:
          # `fast` starts serving immediately and loads the lists in the
          # background, enabling filtering when they land. `blocking` (the
          # default) holds DNS until the download finishes.
          loading:
            strategy: fast
            # Measured 2026-10-26 22:44: wifi is not associated in the first
            # seconds after a reboot, so the one load attempt at boot died with
            # `network is unreachable` and the group stayed empty — four hours of
            # silent no-blocking at the default refreshPeriod. Five attempts 5 s
            # apart covers association; 15 m recovers a boot that missed it.
            refreshPeriod: 15m
            downloads:
              attempts: 5
              cooldown: 5s
          denylists:
            ads:
              - https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts
              - https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
          clientGroupsBlock:
            default:
              - ads
          blockType: zeroIp

        caching:
          minTime: 5m
          maxTime: 30m

        # No query log: this root filesystem is read-only and a log on a device
        # whose job is to answer under a second is a cost with no reader.
        queryLog:
          type: none
        log:
          level: info
      '';
    };

    breakglass.enable = true;

    # `gok update` password: sops only. The rendered config carries "".
    httpPasswordSecret = "gokrazy.gok.http_password";

    # Tailnet name is `gok` even though the DHCP name is the FQDN above.
    tailscale = {
      enable = true;
      hostname = "gok";
      # Set this key in sops for unattended auth; without it the appliance shows
      # a login URL in its own UI and keeps the session in /perm.
      authKeySecret = "gokrazy.gok.tailscale_auth_key";
    };

    # Both the SSID and the PSK live in sops: the network name is not published
    # in this repo either. Comment these two lines out for the wired default.
    wifi = {
      ssidSecret = "gokrazy.gok.wifi_ssid";
      pskSecret = "gokrazy.gok.wifi_psk";
    };
  };
}
