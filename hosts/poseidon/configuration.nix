{
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
    ../../modules/profiles/steam.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
    # microVM DISABLED (2026-08): testvm no longer runs on poseidon.
    # Re-enable by uncommenting the microvm host module + microvm-host.nix
    # profile import below and the microvm.vms block further down.
    # inputs.microvm.nixosModules.host
    # (import ../../modules/profiles/microvm-host.nix {
    #   inherit pkgs;
    #   natExternalInterface = "wlp4s0";
    # })
  ];

  ssh.ca.enableClient = true;
  # --- microVM testvm DISABLED (2026-08): no longer runs on poseidon. ---
  # Commented out for easy re-enable. The microbr bridge/NAT wiring is also
  # commented out above (microvm.nixosModules.host + microvm-host.nix import).
  # microvm.vms = {
  #   testvm = {
  #     config = {
  #       imports = [
  #         inputs.microvm.nixosModules.microvm
  #         (import ../microvms/testvm.nix {
  #           workspaceSource = "${user.home}/workspace";
  #           agentsSource = "${user.home}/.agents";
  #           configureNetworkd = true;
  #           useDevNixDefaults = true;
  #           authorizedKeys = config.ssh.authorizedKeys.keys;
  #         })
  #       ];
  #       microvm.hypervisor = "cloud-hypervisor";
  #       microvm.vsock.cid = 10;
  #
  #       environment.systemPackages = with pkgs; [
  #         curl
  #         git
  #         jq
  #         yq-go
  #         go
  #         skills
  #         worktrunk
  #       ];
  #     };
  #   };
  # };
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
    # The dock's RJ45 is a CDC-NCM function and the profile leaves it strictly
    # unmanaged by default, which is what "disabled" looks like from the GUI:
    # carrier up, no address, `nmcli device connect` refuses it. Re-enabled
    # 2026-10-23 because the cable terminates on the parent 192.168.3.0/24 (its
    # lease is .3, alongside Wi-Fi's .2) and not behind a cascaded mesh node, so
    # this does not put two subnets on one host -- the trap commit 87e967cc
    # reverted for. The profile pins the interface and keeps route-metric 600,
    # so Wi-Fi stays the primary uplink and the dock is the fallback.
    manageUsbEthernet = true;
    usbEthernetInterface = "enp6s0f3u1u1i5";
  };

  # --- Battery longevity: pack at 48 % of design capacity (measured 2026-10-23) ---
  # Dell G15 5515, `BAT1`: charge_full 2.36 Ah against 4.91 Ah design, sitting
  # Full at 100 % SoC on AC -- the state that ages a cell fastest. Sustained
  # partial charge also guards against the swelling that comes with it.
  #
  # This model has NO software ceiling: BAT1 exposes no
  # charge_control_end_threshold, `dell-wmi-sysman` refuses to load (No such
  # device), and there is no /dev/smi for smbios-battery-ctl. The ceiling that
  # actually holds is the BIOS one, which the EC keeps across OSes and updates:
  # F2 -> Power Management -> Battery Charge Configuration -> Custom (start 50,
  # stop 80) or Primarily AC Use. Set it there once; this profile is the probe,
  # not the enforcement -- it writes the ceiling on hardware that exposes one and
  # reports once per boot when it does not (`journalctl -u battery-charge-limit`).
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

  # users.groups.libvirtd.members = [ "devji" ];
  # virtualisation.libvirtd.enable = true;
  # virtualisation.spiceUSBRedirection.enable = true;
  # users.users.devji.extraGroups = [ "adbusers" "kvm" "libvirtd" ];
  services.udev.packages = [];

  # services.avahi.publish.enable = true;
  # services.avahi.publish.userServices = true;

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
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
