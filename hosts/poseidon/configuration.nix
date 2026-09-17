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
  networking.hostName = "poseidon";

  environment = {
    systemPackages = with pkgs;
      [
        btrfs-progs
      ]
      ++ lib.optionals obsConfig.enable [
        (pkgs.wrapOBS {inherit (obsConfig) plugins;})
      ];
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

  programs.dank-material-shell.greeter = {
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
