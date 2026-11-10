# fern — HP 15 laptop (Ryzen 3 3250U) niri desktop.
{
  self,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # dwl, forked out of the userland rather than disabled inside it
    # [[flake/policies.nix#desktop-fork-not-disable]]. The Ryoku pilot ran
    # 2026-10-31 → 2026-11-09 and ended here: with the DisplayLink manager daemon
    # in the session it was intolerable on this 15 W APU.
    self.modules."profiles.dwl-desktop"
    self.modules."profiles.laptop"
    self.modules."profiles.base-node"
  ];

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

  # Declarative Fleet DNS: Pi-hole on frieren (192.168.3.25 LAN / 100.97.61.65 Tailscale)
  # Scoped specifically to ~lan and ~frieren.lan routing domains.
  # NetworkManager accepts DHCP DNS on all connections (Wi-Fi, ethernet) so public Wi-Fi /
  # captive portals work normally without getting trapped on unroutable private nameservers.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "192.168.3.25 100.97.61.65";
      FallbackDNS = "1.1.1.1 8.8.8.8";
      Domains = ["~lan" "~frieren.lan"];
    };
  };

  # --- Desktop: dwl (profiles.dwlDesktop) ---
  # The profile owns the session end to end: no display manager, getty autologins
  # tty1, and that login shell execs `programs.dwl`'s wrapper. The chain still
  # carries the DMS feature, so niri and the DMS greeter are forced off here —
  # installed but unused is the half-fork the policy exists to stop.
  profiles.dwlDesktop.enable = true;
  programs.niri.enable = lib.mkForce false;
  programs.dms-greeter.enable = lib.mkForce false;

  # `desktop` is the role's niri/DMS home layer and is the one feature the fork
  # drops; shell, dev, ai, browser and media still come from roles.home.
  fleet.hmUserFeatures = lib.mkForce [
    "systemd-policy"
    "shell"
    "dev"
    "ai"
    "browser"
    "media"
  ];

  # Phone integration without a shell-specific layer: KDE Connect and the
  # adb/scrcpy tools below are standalone. The ryoku `phone.json` this host used
  # to write is gone with the pilot — it existed only for Ryoku's QML side.
  programs.kdeconnect.enable = true;
  services.avahi.enable = lib.mkDefault true;

  # Antigravity CLI (agy) crashes on fern due to Ryzen 3 3250U broken RDRAND
  # ("RDRAND is not reliable on this platform; disabling"), which causes BoringSSL's
  # CRNGT self-test to abort. Exclude local agy from the closure; agy-remote is still
  # available to offload agent sessions to frieren.lan.
  home-manager.users.${user.name}.programs.antigravity-cli.enable = false;

  # Vega 3 iGPU — Mesa/radeonsi; amdgpu drives it (modesetting by DRI3
  # under Wayland). Redistributable firmware covers the APU + laptop
  # WiFi/BT (HP 15 units ship Realtek/MediaTek/Intel cards).
  services.xserver.videoDrivers = ["amdgpu"];
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;

  # The dock's RJ45 is a CDC-NCM port the profile leaves unmanaged, and it is the
  # faster link here (6.2 MB/s against Wi-Fi 2.6). Why:
  # .agents/deploy/dock-ethernet.md.
  profiles.dell-dock = {
    enable = true;
    manageUsbEthernet = true;
    usbEthernetInterface = "enp4s0f3u1u1i5";
    usbEthernetAddress = "192.168.3.249/24";
    # The router, so the cable carries a default route as well as the LAN
    # prefix. Without it a dock-only session — Wi-Fi down, or its activation
    # failed after an NM restart — has no route off the segment at all
    # (measured 2026-11-01: `ip route get 1.1.1.1` answered "Network is
    # unreachable" while the dock was up and Wi-Fi was not).
    usbEthernetGateway = "192.168.3.1";
    # Below Wi-Fi's 600, so the cable is the preferred default while plugged in
    # and Wi-Fi takes it back on unplug.
    usbEthernetRouteMetric = 100;
  };

  # Two interfaces on 192.168.3.0/24 (see above): without this each NIC answers
  # ARP for the other's address, and the flux tears down live SSH sessions.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
  };

  # schedutil, not powersave: the APU otherwise stays at its 1400 MHz floor on AC.
  # Why: .agents/deploy/hosts/fern.md §"CPU governor".
  powerManagement.cpuFreqGovernor = "schedutil";
  systemd.services.cpufreq.after = ["power-profiles-daemon.service"];

  # --- Logind: prevent fatal ACPI suspend freeze on lid close ---
  # Ryzen 3 3250U (Picasso APU) has a known kernel display engine hang on ACPI
  # suspend resume. When docked or on external power, keep the system alive and
  # lock/blank the screen instead of sleeping.
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "lock";
  };

  # Disable ACPI sleep/suspend states that hang the Picasso APU
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowSuspendThenHibernate = "no";
    AllowHybridSleep = "no";
  };

  # Picasso/Raven APU stability: avoid IOMMU page faults on USB/GPU wake
  boot.kernelParams = ["iommu=pt"];

  # --- Btrfs auto-scrub (monthly) ---
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/"];
  };

  # --- TPM 2.0 subsystem ---
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
  users.users.devji.extraGroups = ["tss"];

  environment.systemPackages = with pkgs; [
    btop # system monitor
    age-plugin-tpm
    tpm2-tools
    # Ryoku phone integration's package half (see the phone block above).
    scrcpy
    android-tools
    avahi
    qt6.qttools
  ];

  system.stateVersion = "26.05";
}
