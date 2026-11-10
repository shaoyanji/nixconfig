{
  self,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
  obsConfig = {
    enable = false;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
    ];
  };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    self.modules."profiles.steam"
    # Ryoku is the high-end desktop tier (2026-11-02). It replaces
    # base-desktop-environment: Ryoku owns the compositor build, the session
    # packages, the portals and the SDDM theme, so importing both would put two
    # shells in one session and let this profile's mkForce'd portal config win
    # over Ryoku's.
    self.modules."profiles.ryoku-desktop"
    self.modules."profiles.laptop"
  ];

  ssh.ca.enableClient = true;

  boot = {
    kernelPackages = lib.mkForce pkgs.linuxPackages;
    kernelModules = [];
  };

  environment = {
    systemPackages = with pkgs;
      [
        btrfs-progs
        age-plugin-tpm # unseals the TPM-sealed sops identity
        tpm2-tools
      ]
      ++ lib.optionals obsConfig.enable [
        (pkgs.wrapOBS {inherit (obsConfig) plugins;})
      ];
  };

  # --- Tailscale: keep the native LAN path ---
  # desktop-client.nix sets `--accept-routes=true`, so frieren's advertised
  # 192.168.3.0/24 subnet route lands in table 52 (ip rule 5270) and every
  # direct LAN destination is sent over the tailnet instead. Measured
  # 2026-10-23: `ip route show table 52` carried `192.168.3.0/24 dev tailscale0`
  # and frieren -> poseidon LAN SSH timed out on port 22 while tailnet SSH
  # worked; a policy rule preferring table main for the prefix fixed it
  # instantly. eisen (Steam Link) and fern (LAN SSH) carry the same override.
  services.tailscale.extraSetFlags = lib.mkForce [
    "--accept-dns=true"
    "--accept-routes=false"
  ];

  # --- Dell D6000 Universal Dock (DisplayLink / EVDI) ---
  # Display and USB only: the dock's CDC-NCM port stays unmanaged. The cable
  # lands behind a cascaded mesh node (192.168.5.0/24) while this host's Wi-Fi
  # sits on the parent (192.168.3.0/24), so DHCP on both would put two subnets on
  # one machine — the node then reads the parent address as an uplink and loses
  # its own bridging. One uplink per host; Wi-Fi already owns this subnet.
  profiles.dell-dock = {
    enable = true;
    # Re-enabled: the cable terminates on the parent 192.168.3.0/24, so this does
    # not put two subnets on one host. Why: .agents/deploy/dock-ethernet.md.
    manageUsbEthernet = true;
    usbEthernetInterface = "enp6s0f3u1u1i5";
    # Static, because this router's DHCP keys on hostname: both links raced for
    # one lease and traded .2/.3/.4 on every restart (2026-10-23). Wi-Fi is
    # pinned to .2 by hand for the same reason -- its PSK keeps that profile out
    # of Nix. Re-apply on a fresh install:
    #   nmcli connection modify "Obi LAN Kenobi" ipv4.method manual \
    #     ipv4.addresses 192.168.3.2/24 ipv4.gateway 192.168.3.1 \
    #     ipv4.dns 192.168.3.25 ipv4.route-metric 300
    usbEthernetAddress = "192.168.3.3/24";
    usbEthernetGateway = "192.168.3.1";
  };

  # Pack is at 48 % of design capacity after sitting Full on AC.
  # No software ceiling on this model: BAT1 exposes no
  # charge_control_end_threshold, dell-wmi-sysman refuses to load. The ceiling
  # that holds is the BIOS one (F2 -> Power Management -> Custom 50/80, set
  # 2026-10-23); this profile is the probe and reports once per boot when the
  # hardware offers nothing (`journalctl -u battery-charge-limit`).
  profiles.batteryChargeLimit = {
    enable = true;
    endThreshold = 80;
    startThreshold = 75;
  };

  # --- TPM 2.0 (AMD firmware TPM) ---
  # /dev/tpmrm0 is root:tss 0660 and age-plugin-tpm --generate runs as the user.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
  users.users.${user.name}.extraGroups = ["tss"];

  # --- TPM unlock for both LUKS volumes ---
  # The passphrase keyslot stays enrolled as the recovery door, and the host
  # SSH key stays a sops recipient; the chip is convenience, not the only path.
  # PCR 7 is systemd's own default and survives kernel/NixOS updates — binding
  # PCR 0/4/9 would demand a re-enrol on every update of a rolling system.
  boot.initrd = {
    systemd = {
      enable = true;
      tpm2.enable = true;
    };
    kernelModules = ["tpm_crb" "tpm_tis"];
    luks.devices = {
      "luks-a03ed119-37a7-4609-aca5-679ba0eccddf".crypttabExtraOpts = ["tpm2-device=auto"];
      "luks-d8c4ffdb-dd14-4836-9e1b-6c400362987d".crypttabExtraOpts = ["tpm2-device=auto"];
    };
  };

  services.udev.packages = [];

  # --- Desktop: Ryoku (high-end tier) ---
  # No SDDM setting here: with no other greeter enabled, Ryoku turns SDDM on
  # (mkDefault) and owns its theme, and `defaultCompositor = "niri"` in the
  # profile picks the `ryoku-niri` session.
  #
  # Login stays automatic, as it was under the DMS greeter this replaces — the
  # Ryoku greeter is what you get after a logout.
  services.displayManager.autoLogin = {
    enable = true;
    user = user.name;
  };

  networking.firewall = {
    enable = true;
    # Sunshine ports — re-enable when sunshine is active
    # allowedTCPPorts = [ 47984 47989 47990 48010 ];
    # allowedUDPPortRanges = [
    #   { from = 47998; to = 48000; }
    #   { from = 8000; to = 8010; }
    # ];
  };

  system.stateVersion = "25.11";
  nixpkgs.config.nvidia.acceptLicense = true;
}
