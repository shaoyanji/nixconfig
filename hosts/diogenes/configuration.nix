{
  self,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    ./hardware-configuration.nix
    self.modules."profiles.base-desktop-environment"
    self.modules."profiles.laptop"
    self.modules."profiles.sops-user-identity"
  ];

  networking.hostName = "diogenes";

  # User-plane sops identity derived from host key (/etc/ssh/ssh_host_ed25519_key)
  profiles.sopsUserIdentity.enable = true;

  # Low-memory desktop optimizations: 100% zram and aggressive swappiness
  zramSwap = {
    enable = true;
    memoryPercent = lib.mkForce 100;
    algorithm = "zstd";
    priority = 100;
  };
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
  services.fstrim.enable = true;

  boot.supportedFilesystems = ["btrfs" "nfs"];
  ssh.ca.enableClient = true;

  # Mount NAS storage from frieren
  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = ["nfsvers=4" "soft" "rw" "intr" "noauto" "x-systemd.automount"];
  };

  # Network diagnostics
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [22 2049];

  # Hardware video acceleration for Intel HD Graphics 4600 (Haswell Gen 7.5).
  # Uses legacy i965 intel-vaapi-driver (intel-media-driver iHD only supports Gen 8+ / Broadwell+).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  # Host-specific diagnostic tools
  environment.systemPackages = with pkgs; [
    libva-utils
    dmidecode
    pciutils
  ];

  # Dock & Display power management:
  # When lid is closed (e.g. docked), do not suspend — keep driving monitors
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Tailscale: disable accepting subnet routes on Diogenes to preserve native LAN routing
  # A toast when an agent turn lands in the fleet log. Delphi serves the log; the
  # toast is a session-bus call, so it happens on the device with the session.
  services.xsNotify.enable = true;

  services.tailscale.extraSetFlags = lib.mkForce [
    "--accept-dns=true"
    "--accept-routes=false"
  ];

  # Declarative Fleet DNS: Pi-hole on frieren (192.168.3.25 LAN / 100.97.61.65 Tailscale)
  networking.nameservers = ["192.168.3.25" "100.97.61.65"];
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "192.168.3.25 100.97.61.65";
      FallbackDNS = "1.1.1.1 8.8.8.8";
      Domains = ["~lan" "~frieren.lan"];
    };
  };

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };

  system.stateVersion = "24.05";
}
