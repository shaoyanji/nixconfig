# fern — HP 15 laptop (Ryzen 3 3250U) niri desktop.
#
# Hardware:
#   CPU:  AMD Ryzen 3 3250U (Picasso/Zen+, 2c/4t, 15 W)
#   GPU:  AMD Radeon Vega 3 iGPU (Mesa/radeonsi via amdgpu)
#   RAM:  8 GB DDR4
#   Disk: single SSD (disko: ESP + 8G swap + btrfs /root,/nix)
#
# Role:  Lightweight desktop mirroring scratch (NO Steam — deliberately
#        not imported): niri compositor with the DankMaterialShell
#        greeter, autoLogin straight into niri
#        as devji (globalModulesNixos chain → role:heim userland).
#        modules/profiles/laptop.nix adds auto-cpufreq (powersave on
#        battery, performance on AC) + libinput for the touchpad.
#        Also the fleet's second resolver (HC-3): the pihole-FTL +
#        unbound stack in the secondary role.
#
# Storage: persistent btrfs (no impermanence), monthly scrub below.
#
# NOTE: this host's LAN address is DHCP. Never write fern's 192.168.3.x
# address into this file (or any other) — it changes on lease renewal. A
# stable handle is its tailnet name (`fern`) / tailnet address, or a DHCP
# reservation made on the router.
{
  config,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/base-node.nix
    # Second always-on resolver (HC-3) — the reusable mechanism lives here.
    ../../modules/profiles/dns-failover.nix
  ];

  networking.hostName = "fern";

  # --- Tailscale: keep the native LAN path ---
  # desktop-client.nix sets `--accept-routes=true`, which makes frieren's
  # advertised 192.168.3.0/24 subnet route land in table 52 (`ip rule 5270`)
  # and hijack EVERY direct LAN connection with the tailnet path. On fern that
  # is not cosmetic: frieren -> fern LAN SSH times out, and fern's own LAN
  # traffic is silently forced through frieren's tailnet SNAT (so the peer
  # address on a "LAN" ssh becomes 100.100.253.25). eisen hit the identical
  # bug on Steam Link and documents the same override (hosts/eisen).
  # Tailscale's "skips routes for directly-attached subnets" did not hold here.
  services.tailscale.extraSetFlags = lib.mkForce [
    "--accept-dns=true"
    "--accept-routes=false"
  ];

  # --- Secondary resolver role (HC-3) --------------------------------------
  # zone/zoneAddress default to frieren.lan / 192.168.3.25, which is exactly
  # what a secondary must answer: the same wildcard record as the primary, so a
  # client that falls back to fern gets identical answers.
  #
  # `resolvers` is advisory (the module never pushes it) and lists the group
  # clients should be configured with, primary first. fern's own address is
  # deliberately NOT listed: it is DHCP, so it is the router's DHCP reservation
  # (or a tailnet name) that makes fern addressable, not a literal here.
  profiles.dnsFailover = {
    enable = true;
    role = "secondary";
    lanInterface = "wlo1";
    resolvers = ["192.168.3.25"];
    # The LAN is the authoritative side (dnsmasq `address=/frieren.lan/...` +
    # the 192.168.3.0/24 answers); everything off-LAN reaches this resolver
    # ONLY through the tailnet — frieren advertises 192.168.3.0/24 as a subnet
    # route (`--advertise-routes`, hosts/frieren/dns.nix), so a remote client
    # accepting that route queries 192.168.3.x over tailscale0 and lands here.
    #
    # `interface=tailscale0` is REQUIRED, not decorative: any dnsmasq
    # `interface=` line switches FTL to interface-restricted listening, and the
    # profile only adds the LAN interface. Without this line the resolver
    # answers the LAN but is silent on the tailnet subroute — the exact failure
    # the profile's own comment calls out for the primary.
    extraDnsmasqLines = ["interface=tailscale0"];
  };

  # Host policy on top of the profile's resolver core: what to block and how
  # long to keep logs. `settings` (dns/database/dnsmasq_lines) is owned by
  # profiles.dnsFailover and must not be redefined here.
  services.pihole-ftl = {
    queryLogDeleter = {
      enable = true;
      age = 7;
      interval = "daily";
    };
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts";
        description = "StevenBlack fake news, gambling, and porn blocklist";
      }
      {
        url = "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt";
        description = "Disconnect tracking blocklist";
      }
    ];
  };

  # Pi-hole admin UI, bound to loopback like the primary's (access is a
  # port-forward, not a LAN hole).
  services.pihole-web = {
    enable = true;
    ports = ["127.0.0.1:8080"];
  };

  # Disable the systemd-resolved stub listener so pihole-FTL can bind port 53
  # exclusively. LLMNR off for the same reason as frieren: Avahi covers
  # multicast discovery and the fleet resolves names through Pi-hole.
  services.resolved.settings.Resolve = {
    DNSStubListener = "no";
    LLMNR = false;
    Domains = ["~frieren.lan"];
  };

  # Point the host resolver at FTL instead of the router:
  # /etc/resolv.conf -> FTL (127.0.0.1:53) -> unbound (127.0.0.1#5335).
  # NetworkManager would otherwise inject the router (192.168.3.1) from DHCP
  # as resolved's per-link upstream and leak it into /etc/resolv.conf.
  networking.networkmanager.dns = lib.mkForce "none";
  networking.nameservers = [
    "127.0.0.1"
    "::1"
  ];

  # pihole-ftl references the tailscale0 interface, so it must wait for
  # tailscaled.
  systemd.services.pihole-ftl = {
    after = ["tailscaled.service"];
  };
  systemd.services.pihole-ftl-setup = {
    after = [
      "tailscaled.service"
      "pihole-ftl.service"
    ];
    wants = ["pihole-ftl.service"];
  };

  # Work around upstream nixpkgs pihole-ftl queryLogDeleter systemd %s and
  # quote escaping quirks (same fix as the primary).
  systemd.services.pihole-ftl-log-deleter = {
    serviceConfig.ExecStart = lib.mkForce (
      pkgs.writeShellScript "pihole-ftl-log-delete" ''
        echo "Deleting query logs older than 7 days"
        exec ${config.services.pihole-ftl.package}/bin/pihole-FTL sqlite3 "${config.services.pihole-ftl.settings.files.database}" \
          "DELETE FROM query_storage WHERE timestamp <= CAST(strftime('%s', date('now', '-7 day')) AS INT); SELECT changes() FROM query_storage LIMIT 1;"
      ''
    );
  };

  # Port 53 on wlo1 comes from profiles.dnsFailover; tailscale0 is opened
  # explicitly — the profile only opens the LAN interface.
  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };

  # --- Desktop (scratch-style): niri compositor + DMS greeter, no Steam ---
  # base-desktop-environment already enables autoLogin as devji; pin the
  # session to niri so autologin has an unambiguous target. The DMS
  # greeter module runs the resolved session; if it exits, greetd falls
  # back to the greeter login screen.
  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "niri";
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
  };

  # This unit's Ryzen 3 3250U reports unreliable RDRAND (the kernel logs
  # "RDRAND is not reliable on this platform; disabling"), so the
  # prebuilt Antigravity CLI aborts in BoringSSL's CRNGT self-test on
  # every invocation. OPENSSL_ia32cap=0 forces BoringSSL's portable
  # (no-asm) crypto paths, which sidesteps the broken RDRAND; wrap the
  # binary with it. Keep doInstallCheck=false since `agy --version`
  # still aborts in the build sandbox where the wrapper env may race
  # the self-test.
  nixpkgs.overlays = [
    # pihole-ftl 6.7.1 fails to compile at the current nixpkgs rev (-Werror on
    # an unused variable) and has no binary substitute; the primary carries the
    # same overlay. See the overlay header before dropping it.
    (import ../../overlays/pihole-ftl-werror.nix)
    (final: prev: {
      antigravity-cli = prev.antigravity-cli.overrideAttrs (old: {
        doInstallCheck = false;
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [final.makeWrapper];
        postInstall =
          (old.postInstall or "")
          + ''
            wrapProgram "$out/bin/agy" --set OPENSSL_ia32cap "0:~0"
          '';
      });
    })
  ];

  # Vega 3 iGPU — Mesa/radeonsi; amdgpu drives it (modesetting by DRI3
  # under Wayland). Redistributable firmware covers the APU + laptop
  # WiFi/BT (HP 15 units ship Realtek/MediaTek/Intel cards).
  services.xserver.videoDrivers = ["amdgpu"];
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;

  # --- Btrfs auto-scrub (monthly) ---
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/"];
  };

  environment.systemPackages = with pkgs; [
    btop # system monitor
  ];

  system.stateVersion = "26.05";
}
