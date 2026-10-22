# Reusable microVM guest: host store over virtiofs, explicit shares only.
# Why the shape is this shape: AGENTS.nix `microvm-guests`.
{
  hostName,
  ipAddress,
  tapId,
  mac,
  gateway ? "192.168.83.1",
  prefix ? 24,
  # Host dirs. `workspace` is mounted rw at the same path, so artifacts cross the
  # boundary without a copy step; `sshHostKeys` keeps the host key stable.
  workspace,
  sshHostKeys,
  # true: /var is an image under /var/lib/microvms/<name>/ and survives.
  # false: /var lives in the tmpfs root — restart is a factory reset.
  persistent ? false,
  varSizeMb ? 8192,
  hypervisor ? "cloud-hypervisor",
  # microvm.nix passes `-enable-kvm` exactly when this is null. A host without
  # /dev/kvm must name a CPU ("max") or its runner dies on the missing module.
  cpu ? null,
  vcpu ? 2,
  mem ? 2048,
  extraShares ? [],
  extraModules ? [],
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  # Constants, not a module: `user.nix` is a plain attrset, so it is imported for
  # its values and never placed in `imports`.
  user = import ../../modules/global/user.nix;
in {
  imports = [../../modules/config/authorized-keys.nix] ++ extraModules;

  networking.hostName = hostName;
  system.stateVersion = "25.11";

  # The guest's only account, with the fleet's one key list. `wheel` without a
  # password prompt because the account already authenticates by key and there is
  # nothing in here to protect from itself.
  users.groups.${user.group} = {};
  users.users.${user.name} = {
    isNormalUser = true;
    inherit (user) home;
    group = user.group;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    hostKeys = [
      {
        path = "${sshHostKeys}/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # The host key is generated once, inside the share, on first boot.
  systemd.services.microvm-host-key = {
    wantedBy = ["sshd.service"];
    before = ["sshd.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 700 ${sshHostKeys}
      [ -f ${sshHostKeys}/ssh_host_ed25519_key ] ||
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -C "${hostName}" -f ${sshHostKeys}/ssh_host_ed25519_key
    '';
  };

  # Static address on the host's microbr bridge; the bridge NATs outward.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "e*";
    addresses = [{Address = "${ipAddress}/${toString prefix}";}];
    routes = [{Gateway = gateway;}];
  };
  networking.nameservers = ["1.1.1.1" "8.8.8.8"];
  # Behind the host's own NAT and firewall: a second firewall here only makes
  # ssh fail in ways that look like a networking bug.
  networking.firewall.enable = false;

  # Fast shutdowns: a guest you restart on purpose should not spend 90 s
  # stopping units it will start again in ten.
  systemd.settings.Manager.DefaultTimeoutStopSec = "5s";

  # microvm.nix issue #170: without this systemd tries to unmount /nix/store on
  # the way down, and `umount` lives in /nix/store, so the guest hangs instead of
  # shutting down.
  systemd.mounts = [
    {
      what = "store";
      where = "/nix/store";
      overrideStrategy = "asDropin";
      unitConfig.DefaultDependencies = false;
    }
  ];

  microvm = {
    inherit hypervisor vcpu mem cpu;
    socket = "control.socket";

    # home-manager activation writes to the store, so it must be writable on top
    # of the shared read-only one. tmpfs: nothing built here survives the guest.
    writableStoreOverlay = "/nix/.rw-store";

    volumes = lib.optional persistent {
      mountPoint = "/var";
      image = "var.img";
      size = varSizeMb;
    };

    shares =
      [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
        {
          proto = "virtiofs";
          tag = "workspace";
          source = workspace;
          mountPoint = workspace;
        }
        {
          proto = "virtiofs";
          tag = "ssh-host-keys";
          source = sshHostKeys;
          mountPoint = sshHostKeys;
        }
      ]
      ++ extraShares;

    interfaces = [
      {
        type = "tap";
        id = tapId;
        inherit mac;
      }
    ];
  };
}
