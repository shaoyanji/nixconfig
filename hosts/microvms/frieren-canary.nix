# frieren-canary: a sandbox an agent boots to run a runbook against a real
# systemd/ssh machine, then throws away. ./base.nix supplies the skeleton; this
# file is a login, a tool set and an ephemeral /var.
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    (import ./base.nix {
      hostName = "frieren-canary";
      ipAddress = "192.168.83.10";
      tapId = "microvm1";
      mac = "02:00:00:00:00:01";
      hypervisor = "cloud-hypervisor";
      # Persistent identity for the guest's sshd, shared over virtiofs. The runner
      # creates it on first boot (scripts/task/run-canary.sh); base.nix then turns
      # key generation off, which is minutes of emulated CPU saved under TCG.
      sshHostKeys = "/var/lib/microvms/frieren-canary/ssh-host-keys";
      vcpu = 2;
      mem = 2048;
    })
  ];

  microvm.vsock.cid = 10;
  microvm.volumes = [
    {
      mountPoint = "/var";
      image = "var.img";
      size = 2048;
    }
  ];

  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  # base.nix authorises root for every guest; this one is a shell a runbook runs
  # in, so devji also gets a login and passwordless sudo inside the throwaway VM.
  users.users.devji = {
    isNormalUser = true;
    home = "${user.home}";
    extraGroups = ["wheel"];
    # The fleet list plus the workstation key this guest's ssh alias uses. That key
    # is deliberately not in modules/config/authorized-keys.nix (fleet hosts trust
    # the SSH CA instead), so a guest that has no CA has to name it — otherwise
    # `ssh frieren-canary` is "Permission denied (publickey)" on a healthy guest.
    openssh.authorizedKeys.keys =
      config.ssh.authorizedKeys.keys
      ++ ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnNR7isgO8VDY76XzwyH3mOg1/DQo8dZgqQOfziw0DQ devji@nixos"];
  };
  security.sudo.wheelNeedsPassword = false;
  # The fleet default is key-only root. Keep that here rather than inheriting
  # base.nix's password-less `PermitRootLogin = yes`: devji is the login.
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # What a runbook reaches for — a compiler, a shell, a query tool — and nothing a
  # service would. The guest is ephemeral, so every package here is closure paid
  # for on each start.
  environment.systemPackages = with pkgs; [
    gcc
    gnumake
    git
    curl
    jq
    sqlite
    procps
    htop
    python3
    file
    binutils
  ];

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # The contract this guest promises to the host bridge and to the test. An
  # assertion is the only place that can catch an address change the test did not
  # follow.
  assertions = [
    {
      assertion = config.networking.firewall.enable == false;
      message = "frieren-canary: the guest sits behind the host's NAT; a guest firewall only breaks ssh in ways that look like a network bug.";
    }
    {
      assertion = config.microvm.shares != [];
      message = "frieren-canary: the guest needs the virtiofs store share; without it nothing in /nix/store is readable.";
    }
    # The guest is a leaf: the `or {}` is load-bearing, because this config does
    # not import `microvm.nixosModules.host`, so the option is absent until someone
    # makes the guest a hypervisor too — which is the drift this names.
    {
      assertion = (config.microvm.vms or {}) == {};
      message = "frieren-canary: this guest is a leaf sandbox; nesting another microVM inside it is not a runbook test.";
    }
  ];
}
