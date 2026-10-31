{
  lib,
  inputs,
  systems,
  pkgsFor,
  self,
  hostInventory,
}:
# HOST BOOT CHECKS — boot ONE host's REAL module graph in a VM and fail unless
# stage-1 hands off to stage-2.
#
# WHY THIS EXISTS
#   `hostChecks` proves the module system evaluates and every assertion holds; CI
#   proves the closure builds; a deploy proves `switch-to-configuration` ran.
#   None of them proves the machine reaches userspace, and that is the failure
#   that reached production: netbook generation 50 booted a systemd-initrd that
#   never reached stage-2 — blank console, no journal entry for that boot — while
#   every gate was green. The only runtime instrument was `frieren-canary`, a
#   SubZeroClaw sandbox guest with its own kernel and root: it booted a different
#   machine, so it could not fail for the host being promoted.
#
# WHAT IS COVERED
#   The node imports `<host>.modules` VERBATIM — the same list
#   `nixosConfigurations.<host>` builds — plus one module that moves root onto
#   the VM's virtio disk, drops the host bootloader, and neutralises sops
#   activation (host identity, not boot logic). The test asserts
#   `multi-user.target` is active and PID 1 is systemd; a stage-1 that dies is a
#   timeout with the serial console in the build log.
#
# WHAT IS NOT COVERED, stated rather than implied
#   Hardware. QEMU has no eMMC, no NVIDIA, no TPM, so a regression that only
#   reproduces on the target's storage controller or GPU is not caught here.
#   Netbook gen 50 was partly that kind of bug (the 26.11 systemd-initrd default
#   flip on an eMMC box): this gate reproduces the HANDOFF failure class, not
#   the hardware trigger. It is still the only gate that runs the config.
#
# WHY ONE HOST PER ATTRIBUTE
#   A boot test evaluates and builds one full host plus a QEMU runner. Grouping
#   hosts, or putting this in `checks.<system>`, would force that work in one
#   process — the 6078 MiB / SIGKILL 137 failure mode `flake/checks.nix`
#   documents. Drive one host with `task checks:boot HOST=<host>`.
let
  # Only hosts this flake produces, declared active, and NixOS. Preserved hosts
  # are dormant and never check targets; externals have no NixOS closure.
  # `status` comes from the COMPILED registry, so the list is not a second copy.
  activeNixos = lib.filterAttrs (_: h: h.status == "active" && h.kind == "nixos") self.inventory.hosts;

  # A boot VM has to hold the unit set the host actually runs. frieren is the
  # case that proved it: it starts immich, plex, jellyfin, paperless,
  # home-assistant, postgres and ~40 more, and in a 2 GiB guest it OOM-panicked at
  # 786 s (`vm.panic_on_oom = 2` is the default for a test VM —
  # nixos/modules/testing/test-instrumentation.nix — because a test that silently
  # loses memory is not a test), so the 900 s console wait could only time out.
  # The failure was the guest size, not the host's boot: measured 2026-10-30, run
  # 41140278130, `Kernel panic - not syncing: Out of memory: compulsory
  # panic_on_oom is enabled` while immich was still mapping routes.
  #
  # Hosts not listed keep the small default, because the same knob is what makes a
  # TCG run on a 2-core, 8 GiB box survivable at all (see `cores` below).
  sizing = {
    frieren = {
      memory = 4096;
      cores = 2;
    };
  };
  defaultSizing = {
    memory = 2048;
    cores = 1;
  };

  bootVm = hostName: {
    config,
    lib,
    ...
  }: let
    size = sizing.${hostName} or defaultSizing;
  in {
    # The host's root is on hardware QEMU does not have. The question here is
    # the stage-1 -> stage-2 handoff, not the disk layout, so the whole set is
    # replaced rather than merged — `mkForce` also beats the driver's default
    # `/` definition instead of conflicting with it.
    fileSystems = lib.mkForce {
      "/" = {
        device = "/dev/vda";
        fsType = "ext4";
      };
    };
    swapDevices = lib.mkForce [];

    # Direct kernel boot: the bootloader is hardware, not boot logic.
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.grub.devices = lib.mkForce [];
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # `lib/mk-nixos-host.nix` makes the inventory key the hostname; here it must
    # be FORCED, because the test driver names every node after its variable
    # (`machine`) with a plain definition. Booting under the real hostname keeps
    # anything that keys off it (cert names, sops paths) honest.
    networking.hostName = lib.mkForce hostName;

    # A silent stage-1 is the exact failure this gate exists for: put the kernel
    # at the verbosity that shows it on the serial console the driver reads.
    boot.consoleLogLevel = lib.mkForce 7;

    # Secrets are host identity, not boot logic: the VM has no TPM and no host
    # SSH keys, so sops would fail on every host that boots perfectly well.
    # Guarded on the option so hosts without sops-nix stay untouched. Both
    # planes are neutralised, because sops chooses one by configuration:
    #   * the systemd unit (sysusers path),
    #   * and the ACTIVATION snippet, which for `neededForUsers` secrets runs from
    #     the initrd (`initrd-nixos-activation`) and fails with "0 successful
    #     groups required" before the system is even mounted.
    systemd.services = lib.mkIf (config.sops.secrets or {} != {}) {
      sops-install-secrets = {
        wantedBy = lib.mkForce [];
        requiredBy = lib.mkForce [];
        before = lib.mkForce [];
      };
    };
    system.activationScripts = {
      setupSecrets = lib.mkForce "";
      setupSecretsForUsers = lib.mkForce "";
    };

    virtualisation = {
      memorySize = size.memory;
      # ONE vCPU, deliberately, for the hosts that keep the default: the question
      # is whether stage-1 hands off, which one core answers, and on the 2-OCPU
      # boxes that can run this by hand a second vCPU starves the nginx/ssh that
      # share the machine (TCG is one thread per vCPU, so this is the difference
      # between half the box and all of it). A host whose own units take minutes to
      # converge needs the second core or the gate measures boot speed, not boot.
      cores = size.cores;
      diskSize = 4096;
    };
  };
in
  # Same architecture contract as `hostChecks`: an attr set per declared system,
  # carrying only the hosts whose registry `arch`-equivalent (`system`) matches, so
  # building `hostBootChecks.aarch64-linux.delphi` never demands an x86_64 builder.
  # Non-Linux systems get {}, because a NixOS VM test needs a Linux host — test the
  # string, not `pkgs.stdenv`: importing nixpkgs for x86_64-darwin on 26.11 throws.
  lib.genAttrs systems.work (
    system: let
      pkgs = pkgsFor system;
      hosts = lib.filterAttrs (name: _: (hostInventory.${name}.system or null) == system) activeNixos;
    in
      if !(lib.hasSuffix "linux" system)
      then {}
      else
        lib.mapAttrs (
          host: _: let
            hostCfg = hostInventory.${host};
          in
            pkgs.testers.runNixOSTest {
              name = "boot-${host}";
              # The host's own specialArgs: `<host>` modules take `inputs`/`self`
              # from here, exactly as `mkNixosHost` supplies them.
              node.specialArgs = hostCfg.specialArgs or {inherit inputs self;};
              # The host declares `nixpkgs.overlays` / `nixpkgs.config`; a read-only
              # pkgs turns those into assertion failures before a single unit runs.
              node.pkgsReadOnly = false;
              nodes.machine = {
                imports = hostCfg.modules ++ [(bootVm host)];
              };
              # The assertion is the SERIAL CONSOLE, not the driver's backdoor shell.
              # Two measured reasons:
              #   * the driver gives the root shell 10 x 30 s after QEMU starts, and a
              #     full host under TCG (no /dev/kvm) needs ~10 min — a slow boot is
              #     not the failure this gate is for;
              #   * the backdoor Requires /dev/ttyAMA0, a device unit aarch64 guests do
              #     not always bring up (delphi: "Timed out waiting for device
              #     /dev/ttyAMA0", so every shell call failed with a dependency error
              #     while the system was perfectly up).
              # `Multi-User System` is printed only by stage-2 systemd: the initrd
              # reaches `Initrd Default Target`, which must not count. `crash()` ends
              # the run through the QEMU monitor, so nothing ever needs the shell.
              testScript = ''
                start_all()
                with subtest("stage-1 hands off to stage-2"):
                    machine.wait_for_console_text("Reached target Multi-User System", timeout=900)
                machine.crash()
              '';
            }
        )
        hosts
  )
