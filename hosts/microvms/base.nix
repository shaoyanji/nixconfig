# A microVM guest with one job: boot, and let root in over ssh.
# Anything else is closure you pay for on every start.
{
  hostName,
  ipAddress,
  tapId,
  mac,
  gateway ? "192.168.83.1",
  prefix ? 24,
  hypervisor ? "cloud-hypervisor",
  # microvm.nix passes `-enable-kvm` exactly when this is null. A host with no
  # /dev/kvm names a CPU ("max") so the runner uses TCG instead of dying on the
  # missing KVM module.
  cpu ? null,
  # Host directory holding ssh_host_ed25519_key. null = generate an ephemeral
  # key on every boot (slow under TCG, and the guest's identity changes).
  sshHostKeys ? null,
  vcpu ? 2,
  mem ? 2048,
}: {
  config,
  lib,
  ...
}: {
  # The fleet's one key list — the same file every host uses, so no second copy.
  imports = [../../modules/config/authorized-keys.nix];

  networking.hostName = hostName;
  system.stateVersion = "25.11";

  # Root, by key only. No normal user, no sudo, no home-manager: this guest is a
  # shell you throw away, not a workstation.
  services.openssh = {
    enable = true;
    # A shared key keeps the guest identity stable across restarts, and skips
    # sshd-keygen entirely: `generateHostKeys = false` disables the RSA/ed25519
    # generation that costs minutes of emulated CPU under TCG.
    hostKeys = lib.mkIf (sshHostKeys != null) [
      {
        path = "/etc/ssh/host-keys/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    generateHostKeys = sshHostKeys == null;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;

  # One static address on the host bridge; the host NATs it outward.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "e*";
    addresses = [{Address = "${ipAddress}/${toString prefix}";}];
    routes = [{Gateway = gateway;}];
  };
  # Behind the host's NAT: a second firewall here only breaks ssh in ways that
  # look like a networking bug.
  networking.firewall.enable = false;

  # A guest you restart on purpose should not spend a minute stopping units it is
  # about to start again.
  systemd.settings.Manager.DefaultTimeoutStopSec = "5s";

  # microvm.nix #170: without this, shutdown unmounts /nix/store with `umount`
  # that lives in /nix/store, and the guest hangs instead of stopping.
  systemd.mounts = [
    {
      what = "store";
      where = "/nix/store";
      overrideStrategy = "asDropin";
      unitConfig.DefaultDependencies = false;
    }
  ];

  microvm = {
    inherit hypervisor cpu vcpu mem;
    socket = "control.socket";
    # Without a writable layer over the shared store, activation has nowhere to
    # write and the boot sits on "GID Wrappers" for minutes. It is a tmpfs, not
    # closure, so a guest that installs nothing still gets one.
    writableStoreOverlay = "/nix/.rw-store";
    # The store comes from the host over virtiofs: no image build, nothing
    # copied at boot. The read-only half is the only share this guest needs,
    # plus the host key directory when the caller supplies one.
    shares =
      [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
      ]
      ++ lib.optional (sshHostKeys != null) {
        proto = "virtiofs";
        tag = "ssh-keys";
        source = sshHostKeys;
        mountPoint = "/etc/ssh/host-keys";
      };
    interfaces = [
      {
        type = "tap";
        id = tapId;
        inherit mac;
      }
    ];
  };
}
