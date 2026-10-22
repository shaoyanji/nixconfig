# `microvm.vms.<name>` for a host that runs guests. One guest, no additions:
# a guest is a way to have a root shell that cannot reach the host, not a place
# to install things. Rationale: AGENTS.nix `microvm-guests`.
{
  inputs,
  hypervisor ? "cloud-hypervisor",
  # A KVM-less host (delphi: OCI A1 does not expose EL2) names a CPU ("max") so
  # the runner uses TCG. cloud-hypervisor has no TCG backend, so such a host
  # must also select hypervisor = "qemu".
  cpu ? null,
  tapId ? "microvm3",
  address ? "192.168.83.11",
  stateRoot ? "/var/lib/microvms",
}: {
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = "${stateRoot}/sandbox/ssh-host-keys";
in {
  imports = [inputs.microvm.nixosModules.host];

  # microvm.nix bounds a start at 150 s, which assumes KVM. A TCG boot takes
  # minutes, so without this the unit is killed mid-boot and reports a timeout
  # while the guest is still healthy.
  systemd.services."microvm@sandbox".serviceConfig.TimeoutStartSec = lib.mkIf (cpu != null) "900";

  # The runner user must own the state dir: microvm-set-booted@ writes `current`
  # there, and the keygen unit below writes the key as the same user.
  systemd.tmpfiles.rules = [
    "d ${stateRoot} 0755 microvm kvm -"
    "d ${stateRoot}/sandbox 0755 microvm kvm -"
    "d ${sshHostKeys} 0700 microvm kvm -"
  ];

  # One key per guest, generated once and served to the guest over virtiofs.
  # Without this every boot runs sshd-keygen under TCG, which took minutes and
  # gave the guest a new identity each time.
  systemd.services.microvm-sandbox-ssh-host-keys = {
    description = "Persistent SSH host key for the sandbox microVM";
    before = ["microvm@sandbox.service"];
    requiredBy = ["microvm@sandbox.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "microvm";
      Group = "kvm";
      UMask = "0077";
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 ${sshHostKeys}
      key=${sshHostKeys}/ssh_host_ed25519_key
      [ -s "$key" ] || ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "sandbox" -f "$key"
    '';
  };

  # `ssh sandbox` from the host that runs it, as root: the bridge subnet is
  # host-local, so this name means nothing on another machine.
  programs.ssh.extraConfig = ''
    Host sandbox
      HostName ${address}
      User root
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
      # 3 s was tight enough to fail the banner exchange on a TCG guest whose
      # vCPUs are busy finishing boot; 30 s still fails fast on a dead guest.
      ConnectTimeout 30
      # OpenSSH 10 puts sntrup761x25519 first; that KEX takes about a minute
      # in a TCG guest, so the handshake times out before the banner. Curve25519
      # is instant and still the modern choice.
      KexAlgorithms curve25519-sha256
  '';

  microvm.vms.sandbox = {
    autostart = false;
    config = {
      imports = [
        inputs.microvm.nixosModules.microvm
        (import ./base.nix {
          hostName = "sandbox";
          ipAddress = address;
          inherit hypervisor cpu tapId sshHostKeys;
          mac = "02:00:00:00:83:11";
          # RAM is not closure: 512 MiB was my guess and it thrashed the boot.
          mem = 1024;
        })
      ];
    };
  };
}
