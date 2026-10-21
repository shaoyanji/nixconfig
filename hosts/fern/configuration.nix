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
    ../../modules/profiles/base-desktop-environment.nix
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
