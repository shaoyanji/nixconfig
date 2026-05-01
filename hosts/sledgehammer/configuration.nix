# Sledgehammer — NixOS USB stick for fleet provisioning.
# Boots headless with everything needed to set up a new machine:
# SOPS decrypt, SSH, git, age key tools, nixos-install.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    (import ./disko.nix {device = "/dev/sdb";})
    ../../modules/profiles/base-node.nix
  ];

  networking.hostName = "sledgehammer";

  boot.loader = {
    efi.canTouchEfiVariables = lib.mkForce false; # Required when using efiInstallAsRemovable
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true; # ESP lands on removable media
    };
    systemd-boot.enable = lib.mkForce false; # Using GRUB instead for removable media
  };

  # Headless: no desktop, no graphical anything.
  # Keep it light — tty-only with network tools.
  environment.systemPackages = with pkgs; [
    # Secrets management
    sops
    age
    ssh-to-age
    yq

    # Git + auth
    git
    openssh
    gnupg

    # Networking
    curl
    wget
    inetutils
    iproute2

    # Nix tooling
    nixpkgs-fmt
    nix-output-monitor
    nvd # nix diff viewer

    # Diagnostics
    htop
    lm_sensors
    pciutils
    usbutils
    file
    jq
  ];

  # SSH on boot — no password auth, keys only.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # SOPS — decrypt with host SSH key (pre-loaded on USB).
  sops = {
    defaultSopsFile = ../../modules/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  };

  system.stateVersion = "25.05";
}
