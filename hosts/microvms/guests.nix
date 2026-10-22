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
}: {lib, ...}: {
  imports = [inputs.microvm.nixosModules.host];

  # microvm.nix bounds a start at 150 s, which assumes KVM. A TCG boot takes
  # minutes, so without this the unit is killed mid-boot and reports a timeout
  # while the guest is still healthy.
  systemd.services."microvm@sandbox".serviceConfig.TimeoutStartSec = lib.mkIf (cpu != null) "900";

  # `ssh sandbox` from the host that runs it, as root: the bridge subnet is
  # host-local, so this name means nothing on another machine.
  programs.ssh.extraConfig = ''
    Host sandbox
      HostName ${address}
      User root
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
      ConnectTimeout 3
  '';

  microvm.vms.sandbox = {
    autostart = false;
    config = {
      imports = [
        inputs.microvm.nixosModules.microvm
        (import ./base.nix {
          hostName = "sandbox";
          ipAddress = address;
          inherit hypervisor cpu tapId;
          mac = "02:00:00:00:83:11";
          # RAM is not closure: 512 MiB was my guess and it thrashed the boot.
          mem = 1024;
        })
      ];
    };
  };
}
