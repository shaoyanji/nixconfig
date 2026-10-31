# fern — HP 15 laptop (Ryzen 3 3250U) niri desktop.
{
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Ryoku pilot (2026-10-31): replaces base-desktop-environment, which would
    # enable niri and expect the DMS greeter under greetd.
    ../../modules/profiles/ryoku-desktop.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/base-node.nix
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

  # --- Desktop: Ryoku (niri provider), pilot 2026-10-31 ---
  # No DMS greeter and no greetd: with no other display manager enabled,
  # Ryoku's module turns on SDDM (Wayland) and owns its theme, so login happens
  # at Ryoku's own greeter and `defaultCompositor = "niri"` picks the session.
  # Autologin is gone on purpose; it hid the greeter the pilot needs to test.

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

  # Dell D6000 Universal Dock (DisplayLink / EVDI)
  profiles.dell-dock.enable = true;

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
  ];

  system.stateVersion = "26.05";
}
