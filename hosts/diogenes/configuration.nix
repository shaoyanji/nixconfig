{
  self,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    self.modules."profiles.base-desktop-environment"
    self.modules."profiles.laptop"
    self.modules."profiles.haswell-graphics"
    self.modules."profiles.sops-user-identity"
    self.modules."profiles.dns-client"
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
  # Mount NAS storage from frieren
  profiles.nasClient.extraOptions = ["nfsvers=4" "soft" "rw" "intr" "noauto" "x-systemd.automount"];

  # Network diagnostics
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [22 2049];

  # Host-specific diagnostic tools
  environment.systemPackages = with pkgs; [
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
  # The xs-notify toaster was rewritten to a Telegram lane on delphi
  # (ea0e6766): this host's toast flag went with it.

  fleet.tailscale.acceptRoutes = false;

  profiles.dnsClient.enable = true;

  system.stateVersion = "24.05";
}
