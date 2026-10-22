# `microvm.vms.<name>` for a host that runs guests; shapes and reasons in
# AGENTS.nix `microvm-guests`. hypervisor is an argument: CH needs /dev/kvm.
{
  inputs,
  hypervisor ? "cloud-hypervisor",
  # TCG hosts name a CPU; without it microvm.nix passes -enable-kvm and the
  # runner fails on a host with no nested virtualisation.
  cpu ? null,
  # Tap ids must not collide with other guests on the same bridge (frieren's
  # canary holds microvm1).
  tapIds ? ["microvm3" "microvm4"],
  addresses ? ["192.168.83.11" "192.168.83.12"],
  stateRoot ? "/var/lib/microvms",
}: {pkgs, ...}: let
  sandbox = builtins.elemAt tapIds 0;
  slides = builtins.elemAt tapIds 1;
  sandboxIp = builtins.elemAt addresses 0;
  slidesIp = builtins.elemAt addresses 1;
in {
  # The host side of microvm.nix: the `microvm@<name>` systemd units, and the
  # runner that starts the guest from the shared store.
  imports = [inputs.microvm.nixosModules.host];

  # `ssh sandbox` from the host that runs it, in the guest's only account, with
  # the host's own key. The bridge subnet is host-local, so these names never
  # mean anything on another machine.
  programs.ssh.extraConfig = ''
    Host sandbox slides
      User devji
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
      ConnectTimeout 3

    Host sandbox
      HostName ${sandboxIp}

    Host slides
      HostName ${slidesIp}
  '';

  # Shares are host paths. They must be writable by the RUNNER user (`microvm`,
  # group kvm) — `microvm-set-booted@` creates a `booted` symlink there and fails
  # with EACCES if root owns the directory. devji is in kvm, so 0770 is shared.
  systemd.tmpfiles.rules = [
    "d ${stateRoot} 0755 microvm kvm -"
    "d ${stateRoot}/sandbox 0755 microvm kvm -"
    "d ${stateRoot}/sandbox/workspace 0770 microvm kvm -"
    "d ${stateRoot}/sandbox/ssh-host-keys 0770 microvm kvm -"
    "d ${stateRoot}/slides 0755 microvm kvm -"
    "d ${stateRoot}/slides/workspace 0770 microvm kvm -"
    "d ${stateRoot}/slides/workspace/slides 0770 microvm kvm -"
    "d ${stateRoot}/slides/ssh-host-keys 0770 microvm kvm -"
  ];

  microvm.vms = {
    sandbox = {
      # Nothing autostarts: a guest is started when it is wanted, so a host
      # reboot does not resurrect one somebody was probing.
      autostart = false;
      config = {
        imports = [
          inputs.microvm.nixosModules.microvm
          (import ./base.nix {
            hostName = "sandbox";
            ipAddress = sandboxIp;
            tapId = sandbox;
            mac = "02:00:00:00:83:11";
            inherit hypervisor cpu;
            workspace = "${stateRoot}/sandbox/workspace";
            sshHostKeys = "${stateRoot}/sandbox/ssh-host-keys";
            persistent = false;
          })
        ];

        environment.systemPackages = with pkgs; [
          git
          ripgrep
          fd
          jq
          python3
          tmux
        ];
      };
    };

    slides = {
      autostart = false;
      config = {
        imports = [
          inputs.microvm.nixosModules.microvm
          (import ./base.nix {
            hostName = "slides";
            ipAddress = slidesIp;
            tapId = slides;
            mac = "02:00:00:00:83:12";
            inherit hypervisor cpu;
            workspace = "${stateRoot}/slides/workspace";
            sshHostKeys = "${stateRoot}/slides/ssh-host-keys";
            persistent = true;
            vcpu = 2;
            mem = 1024;
          })
        ];

        # The service this guest exists for: whatever is put in
        # /var/lib/microvms/slides/workspace/slides on the host is served from
        # inside the guest, and nothing else on the host is reachable from here.
        services.nginx = {
          enable = true;
          virtualHosts.slides = {
            default = true;
            root = "${stateRoot}/slides/workspace/slides";
            locations."/".extraConfig = "autoindex on;";
          };
        };
      };
    };
  };
}
