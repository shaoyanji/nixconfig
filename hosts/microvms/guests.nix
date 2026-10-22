# `microvm.vms.<name>` for a host that runs guests. One guest, no additions:
# a guest is a way to have a root shell that cannot reach the host, not a place
# to install things. Rationale: AGENTS.nix `microvm-guests`.
{
  inputs,
  hypervisor ? "cloud-hypervisor",
  tapId ? "microvm3",
  address ? "192.168.83.11",
}: {
  imports = [inputs.microvm.nixosModules.host];

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
          inherit hypervisor tapId;
          mac = "02:00:00:00:83:11";
          # RAM is not closure: 512 MiB was my guess and it thrashed the boot.
          mem = 1024;
        })
      ];
    };
  };
}
